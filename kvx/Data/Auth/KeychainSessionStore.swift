import Foundation
import Security

actor KeychainSessionStore: SessionStore {
    private enum LegacyStoredSession: Codable { case active(String), signedOut }
    // UserDefaults is thread-safe; the reference is assigned during actor initialization.
    nonisolated(unsafe) private let defaults: UserDefaults
    private let service: String
    private let legacyKey = "binblog.accessToken"

    init(defaults: UserDefaults = .standard, service: String = "com.kvx.kvx.binblog.khuonvien.vn.session") {
        self.defaults = defaults
        self.service = service
    }
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: "active-session", kSecAttrSynchronizable as String: false]
    }
    func read() throws -> StoredSession? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &item)
        if status == errSecSuccess {
            guard let data = item as? Data else { throw SessionFailure.storage }
            let stored = try Self.decode(data)
            defaults.removeObject(forKey: legacyKey)
            return stored
        }
        guard status == errSecItemNotFound else { throw SessionFailure.storage }
        guard let legacy = defaults.string(forKey: legacyKey), !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        try write(.active(legacy))
        return .active(legacy)
    }
    func write(_ value: StoredSession) throws {
        let data = try Self.encode(value)
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw SessionFailure.storage }
        defaults.removeObject(forKey: legacyKey)
    }
    func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw SessionFailure.storage }
        // Defaults removal is not a durable migration barrier. Recreate the
        // token-free sentinel even after deletion so old defaults cannot import.
        try write(.signedOut)
    }

    private static func decode(_ data: Data) throws -> StoredSession {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let map = object as? [String: Any] else { throw SessionFailure.storage }
        if map["version"] == nil {
            guard let legacy = try? JSONDecoder().decode(LegacyStoredSession.self, from: data) else {
                throw SessionFailure.storage
            }
            switch legacy {
            case .active(let token):
                guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SessionFailure.storage }
                return .active(token)
            case .signedOut: return .signedOut
            }
        }
        guard integer(map["version"]) == 2, let state = map["state"] as? String else {
            throw SessionFailure.storage
        }
        if state == "signedOut" {
            guard Set(map.keys) == Set(["version", "state"]) else { throw SessionFailure.storage }
            return .signedOut
        }
        guard state == "active", let token = map["token"] as? String,
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SessionFailure.storage }
        guard Set(map.keys) == Set(["version", "state", "token", "session_id", "marker"]),
              let sessionID = map["session_id"] as? String, validID(sessionID),
              let rawMarker = map["marker"] else { return .quarantined(token) }
        if rawMarker is NSNull { return .managed(ActiveSessionRecord(token: token, sessionID: sessionID)) }
        guard let markerMap = rawMarker as? [String: Any],
              let marker = marker(from: markerMap) else { return .quarantined(token) }
        return .managed(ActiveSessionRecord(token: token, sessionID: sessionID, marker: marker))
    }

    private static func encode(_ value: StoredSession) throws -> Data {
        switch value {
        case .active(let token):
            guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SessionFailure.storage }
            return try JSONEncoder().encode(LegacyStoredSession.active(token))
        case .signedOut:
            return try JSONSerialization.data(withJSONObject: ["version": 2, "state": "signedOut"], options: [.sortedKeys])
        case .quarantined:
            throw SessionFailure.storage
        case .managed(let record):
            guard !record.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  validID(record.sessionID) else { throw SessionFailure.storage }
            var map: [String: Any] = ["version": 2, "state": "active", "token": record.token,
                                      "session_id": record.sessionID, "marker": NSNull()]
            if let marker = record.marker {
                guard validID(marker.operationID) else { throw SessionFailure.storage }
                var markerMap: [String: Any] = ["version": 1, "operation_id": marker.operationID,
                                                "operation": marker.operation.rawValue]
                switch marker.operation {
                case .unlinkGoogle:
                    markerMap["provider"] = "google"
                    markerMap["reason"] = "await_provider_absence"
                case .rotateRecoveryCodes:
                    markerMap["reason"] = "codes_receipt_at_risk"
                }
                map["marker"] = markerMap
            }
            return try JSONSerialization.data(withJSONObject: map, options: [.sortedKeys])
        }
    }

    private static func marker(from map: [String: Any]) -> ReconciliationMarker? {
        guard integer(map["version"]) == 1,
              let operationID = map["operation_id"] as? String, validID(operationID),
              let operation = map["operation"] as? String,
              let reason = map["reason"] as? String else { return nil }
        switch operation {
        case ReconciliationOperation.unlinkGoogle.rawValue:
            guard Set(map.keys) == Set(["version", "operation_id", "operation", "provider", "reason"]),
                  map["provider"] as? String == "google", reason == "await_provider_absence" else { return nil }
            return ReconciliationMarker(operation: .unlinkGoogle, operationID: operationID)
        case ReconciliationOperation.rotateRecoveryCodes.rawValue:
            guard Set(map.keys) == Set(["version", "operation_id", "operation", "reason"]),
                  reason == "codes_receipt_at_risk" else { return nil }
            return ReconciliationMarker(operation: .rotateRecoveryCodes, operationID: operationID)
        default: return nil
        }
    }

    private static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              !"df".contains(String(cString: number.objCType)),
              number.doubleValue == Double(number.intValue) else { return nil }
        return number.intValue
    }

    private static func validID(_ value: String) -> Bool {
        guard value.count == 36, UUID(uuidString: value)?.uuidString.lowercased() == value else { return false }
        let characters = Array(value)
        return characters[14] == "4" && "89ab".contains(characters[19])
    }
}
