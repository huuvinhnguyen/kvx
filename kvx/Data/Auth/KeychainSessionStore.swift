import Foundation
import Security

actor KeychainSessionStore: SessionStore {
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
            let stored = try JSONDecoder().decode(StoredSession.self, from: data)
            defaults.removeObject(forKey: legacyKey)
            return stored
        }
        guard status == errSecItemNotFound else { throw SessionFailure.storage }
        guard let legacy = defaults.string(forKey: legacyKey), !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        try write(.active(legacy))
        return .active(legacy)
    }
    func write(_ value: StoredSession) throws {
        let data = try JSONEncoder().encode(value)
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
}
