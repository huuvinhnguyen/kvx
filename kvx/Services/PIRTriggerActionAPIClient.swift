import Foundation

struct PIRTriggerActionAPIClient: PIRTriggerActionRepository {
    var tokenProvider: any AccessTokenProvider = UserDefaultsAccessTokenProvider()
    var session: URLSession = .shared
    var baseURL = URL(string: "https://khuonvien.vn")!

    func configuration(chipID: String) async throws -> PIRTriggerConfiguration {
        let data = try await request(chipID: chipID, method: "GET")
        do { return try JSONDecoder().decode(PIRTriggerConfigurationDTO.self, from: data).domain() }
        catch let failure as PIRTriggerActionFailure { throw failure }
        catch { throw PIRTriggerActionFailure.invalidResponse }
    }

    func targets(chipID: String) async throws -> [PIRTriggerTarget] {
        let data = try await request(chipID: chipID, suffix: ["targets"], method: "GET")
        do {
            let response = try JSONDecoder().decode(PIRTriggerTargetsDTO.self, from: data)
            guard response.status == "success" else { throw PIRTriggerActionFailure.invalidResponse }
            return try response.targets.map { try $0.domain() }
        } catch let failure as PIRTriggerActionFailure { throw failure }
        catch { throw PIRTriggerActionFailure.invalidResponse }
    }

    func create(chipID: String, draft: PIRTriggerActionDraft) async throws {
        let data = try await request(chipID: chipID, method: "POST", body: try mutationBody(draft), success: [201], mutation: true)
        try validateActionReceipt(data, expectedID: nil, draft: draft)
    }

    func update(chipID: String, actionID: Int, draft: PIRTriggerActionDraft) async throws {
        guard actionID > 0 else { throw PIRTriggerActionFailure.rejected(code: "invalid_action", message: "Hành động không hợp lệ.") }
        let data = try await request(chipID: chipID, suffix: [String(actionID)], method: "PUT", body: try mutationBody(draft), mutation: true)
        try validateActionReceipt(data, expectedID: actionID, draft: draft)
    }

    func delete(chipID: String, actionID: Int) async throws {
        let data = try await request(chipID: chipID, suffix: [String(actionID)], method: "DELETE", mutation: true)
        do {
            let receipt = try JSONDecoder().decode(PIRTriggerDeleteReceiptDTO.self, from: data)
            guard receipt.status == "success", receipt.action_id == actionID else { throw PIRTriggerActionFailure.uncertainMutation }
        } catch let failure as PIRTriggerActionFailure { throw failure }
        catch { throw PIRTriggerActionFailure.uncertainMutation }
    }

    func reorder(chipID: String, actionIDs: [Int]) async throws {
        guard !actionIDs.isEmpty, Set(actionIDs).count == actionIDs.count, actionIDs.allSatisfy({ $0 > 0 }) else {
            throw PIRTriggerActionFailure.rejected(code: "invalid_order", message: "Thứ tự hành động không hợp lệ.")
        }
        let body = try JSONEncoder().encode(PIRTriggerOrderRequestDTO(action_ids: actionIDs))
        let data = try await request(chipID: chipID, suffix: ["order"], method: "PUT", body: body, mutation: true)
        do {
            let receipt = try JSONDecoder().decode(PIRTriggerOrderReceiptDTO.self, from: data)
            let actions = try receipt.actions.map { try $0.domain() }
            let received = actions.compactMap(\.id)
            guard receipt.status == "success", received == actionIDs else { throw PIRTriggerActionFailure.uncertainMutation }
        } catch let failure as PIRTriggerActionFailure { throw failure }
        catch { throw PIRTriggerActionFailure.uncertainMutation }
    }

    func migrateLegacy(chipID: String) async throws {
        let data = try await request(chipID: chipID, suffix: ["migrate_legacy"], method: "POST", mutation: true)
        do {
            let receipt = try JSONDecoder().decode(PIRTriggerMigrationReceiptDTO.self, from: data)
            let action = try receipt.action.domain()
            guard receipt.status == "success", receipt.mode == "actions", action.origin == .persisted, action.id != nil else {
                throw PIRTriggerActionFailure.uncertainMutation
            }
        } catch let failure as PIRTriggerActionFailure { throw failure }
        catch { throw PIRTriggerActionFailure.uncertainMutation }
    }

    private func mutationBody(_ draft: PIRTriggerActionDraft) throws -> Data {
        guard draft.targetID > 0, draft.relayIndex >= 0, draft.durationMilliseconds > 0 else {
            throw PIRTriggerActionFailure.rejected(code: "invalid_action", message: "Cấu hình hành động không hợp lệ.")
        }
        return try JSONEncoder().encode(PIRTriggerMutationRequestDTO(
            target_device_id: draft.targetID,
            action_type: "relay_pulse",
            relay_index: draft.relayIndex,
            duration_ms: draft.durationMilliseconds,
            delay_ms: 0,
            enabled: draft.enabled
        ))
    }

    private func validateActionReceipt(_ data: Data, expectedID: Int?, draft: PIRTriggerActionDraft) throws {
        do {
            let receipt = try JSONDecoder().decode(PIRTriggerActionReceiptDTO.self, from: data)
            let action = try receipt.action.domain()
            guard receipt.status == "success", action.origin == .persisted, let id = action.id,
                  expectedID == nil || id == expectedID,
                  action.target?.id == draft.targetID,
                  action.relayIndex == draft.relayIndex,
                  action.durationMilliseconds == draft.durationMilliseconds,
                  action.delayMilliseconds == 0,
                  action.enabled == draft.enabled else { throw PIRTriggerActionFailure.uncertainMutation }
        } catch let failure as PIRTriggerActionFailure { throw failure }
        catch { throw PIRTriggerActionFailure.uncertainMutation }
    }

    private func request(
        chipID: String,
        suffix: [String] = [],
        method: String,
        body: Data? = nil,
        success: Set<Int> = [200],
        mutation: Bool = false
    ) async throws -> Data {
        guard !chipID.isEmpty else { throw PIRTriggerActionFailure.unavailable(code: "source_not_found", message: "PIR chưa có mã chip.") }
        guard let token = tokenProvider.accessToken, !token.isEmpty else { throw PIRTriggerActionFailure.authentication }
        guard let url = endpoint(chipID: chipID, suffix: suffix) else { throw PIRTriggerActionFailure.invalidResponse }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw mutation ? PIRTriggerActionFailure.uncertainMutation : PIRTriggerActionFailure.connection }
        guard let http = response as? HTTPURLResponse else {
            throw mutation ? PIRTriggerActionFailure.uncertainMutation : PIRTriggerActionFailure.invalidResponse
        }
        if success.contains(http.statusCode) { return data }
        if http.statusCode == 401 { throw PIRTriggerActionFailure.authentication }
        guard let error = try? JSONDecoder().decode(PIRTriggerErrorDTO.self, from: data), error.status == "error" else {
            throw mutation ? PIRTriggerActionFailure.uncertainMutation : PIRTriggerActionFailure.invalidResponse
        }
        if http.statusCode == 503, error.code == "feature_disabled" { throw PIRTriggerActionFailure.featureDisabled(message: error.message) }
        if http.statusCode == 404 { throw PIRTriggerActionFailure.unavailable(code: error.code, message: error.message) }
        if [409, 422].contains(http.statusCode) { throw PIRTriggerActionFailure.rejected(code: error.code, message: error.message) }
        throw mutation ? PIRTriggerActionFailure.uncertainMutation : PIRTriggerActionFailure.invalidResponse
    }

    private func endpoint(chipID: String, suffix: [String]) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/%?#"))
        let values = ["api", "devices", chipID, "trigger_actions"] + suffix
        let encoded = values.map { $0.addingPercentEncoding(withAllowedCharacters: allowed) }
        guard encoded.allSatisfy({ $0 != nil }) else { return nil }
        let basePath = components.percentEncodedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.percentEncodedPath = "/" + ([basePath] + encoded.compactMap { $0 }).filter { !$0.isEmpty }.joined(separator: "/")
        return components.url
    }
}

struct PIRTriggerConfigurationDTO: Decodable {
    let status: String
    let configuration_mode: String
    let source_device: Source
    let actions: [PIRTriggerActionDTO]
    struct Source: Decodable { let id: Int; let name: String?; let chip_id: String }

    func domain() throws -> PIRTriggerConfiguration {
        guard status == "success", source_device.id > 0, !source_device.chip_id.isEmpty else { throw PIRTriggerActionFailure.invalidResponse }
        let mode: PIRTriggerConfigurationMode = switch configuration_mode {
        case "none", "empty": .empty
        case "actions": .actions
        case "legacy": .legacy
        case "invalid_legacy": .invalidLegacy
        default: throw PIRTriggerActionFailure.invalidResponse
        }
        let mapped = try actions.map { try $0.domain() }
        switch mode {
        case .empty, .invalidLegacy: guard mapped.isEmpty else { throw PIRTriggerActionFailure.invalidResponse }
        case .legacy: guard mapped.count == 1, mapped[0].origin == .legacy, mapped[0].id == nil else { throw PIRTriggerActionFailure.invalidResponse }
        case .actions: guard mapped.allSatisfy({ $0.origin == .persisted && $0.id != nil }) else { throw PIRTriggerActionFailure.invalidResponse }
        }
        return PIRTriggerConfiguration(mode: mode, source: PIRTriggerSource(id: source_device.id, name: source_device.name, chipID: source_device.chip_id), actions: mapped)
    }
}

struct PIRTriggerActionDTO: Decodable {
    let id: Int?
    let origin: String
    let action_type: String
    let target: Target?
    let relay_index: Int
    let duration_ms: Int
    let delay_ms: Int
    let enabled: Bool
    let position: Int
    struct Target: Decodable { let id: Int; let name: String?; let chip_id: String; let device_type: String }

    func domain() throws -> PIRTriggerAction {
        guard let origin = PIRTriggerAction.Origin(rawValue: origin), action_type == "relay_pulse",
              relay_index >= 0, duration_ms > 0, delay_ms >= 0, position >= 0 else { throw PIRTriggerActionFailure.invalidResponse }
        if origin == .persisted { guard let id, id > 0 else { throw PIRTriggerActionFailure.invalidResponse } }
        if origin == .legacy, id != nil { throw PIRTriggerActionFailure.invalidResponse }
        let target = try target.map { value -> PIRTriggerAction.TargetSummary in
            guard value.id > 0, !value.chip_id.isEmpty, let type = PIRTriggerTarget.DeviceType(rawValue: value.device_type) else {
                throw PIRTriggerActionFailure.invalidResponse
            }
            return .init(id: value.id, name: value.name, chipID: value.chip_id, deviceType: type)
        }
        return PIRTriggerAction(id: id, origin: origin, target: target, relayIndex: relay_index, durationMilliseconds: duration_ms, delayMilliseconds: delay_ms, enabled: enabled, position: position)
    }
}

struct PIRTriggerTargetsDTO: Decodable {
    let status: String
    let targets: [Target]
    struct Target: Decodable {
        let id: Int; let chip_id: String; let name: String?; let device_type: String; let relay_indexes: [Int]; let duration_ms: Bounds
        struct Bounds: Decodable { let minimum: Int; let maximum: Int }
        func domain() throws -> PIRTriggerTarget {
            guard id > 0, !chip_id.isEmpty, let type = PIRTriggerTarget.DeviceType(rawValue: device_type),
                  !relay_indexes.isEmpty, relay_indexes.allSatisfy({ $0 >= 0 }), Set(relay_indexes).count == relay_indexes.count,
                  duration_ms.minimum > 0, duration_ms.maximum >= duration_ms.minimum else { throw PIRTriggerActionFailure.invalidResponse }
            return PIRTriggerTarget(id: id, chipID: chip_id, name: name, deviceType: type, relayIndexes: relay_indexes, durationBounds: .init(minimum: duration_ms.minimum, maximum: duration_ms.maximum))
        }
    }
}

private struct PIRTriggerMutationRequestDTO: Encodable {
    let target_device_id: Int; let action_type: String; let relay_index: Int; let duration_ms: Int; let delay_ms: Int; let enabled: Bool
}
private struct PIRTriggerOrderRequestDTO: Encodable { let action_ids: [Int] }
private struct PIRTriggerActionReceiptDTO: Decodable { let status: String; let action: PIRTriggerActionDTO }
private struct PIRTriggerDeleteReceiptDTO: Decodable { let status: String; let action_id: Int }
private struct PIRTriggerOrderReceiptDTO: Decodable { let status: String; let actions: [PIRTriggerActionDTO] }
private struct PIRTriggerMigrationReceiptDTO: Decodable { let status: String; let migrated: Bool; let mode: String; let action: PIRTriggerActionDTO }
private struct PIRTriggerErrorDTO: Decodable { let status: String; let code: String; let message: String }
