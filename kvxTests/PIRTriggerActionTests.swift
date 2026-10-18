import Foundation
import Testing
@testable import kvx

@MainActor
private final class FakePIRTriggerRepository: PIRTriggerActionRepository {
    var configurationValue = PIRTriggerConfiguration(mode: .empty, source: .init(id: 1, name: "PIR", chipID: "pir/a"), actions: [])
    var targetValues = [PIRTriggerTarget(id: 2, chipID: "buzz2", name: "Buzzer", deviceType: .buzzer, relayIndexes: [0], durationBounds: .init(minimum: 100, maximum: 10_000))]
    var loadError: Error?
    var mutationError: Error?
    var creates = 0
    var updates = 0
    var deletes = 0
    var reorders = 0
    var migrations = 0
    var loads = 0
    var suspendCreate = false
    private var createContinuation: CheckedContinuation<Void, Never>?

    func configuration(chipID: String) async throws -> PIRTriggerConfiguration { loads += 1; if let loadError { throw loadError }; return configurationValue }
    func targets(chipID: String) async throws -> [PIRTriggerTarget] { if let loadError { throw loadError }; return targetValues }
    func create(chipID: String, draft: PIRTriggerActionDraft) async throws {
        creates += 1
        if let mutationError { throw mutationError }
        if suspendCreate { await withCheckedContinuation { createContinuation = $0 } }
    }
    func update(chipID: String, actionID: Int, draft: PIRTriggerActionDraft) async throws { updates += 1; if let mutationError { throw mutationError } }
    func delete(chipID: String, actionID: Int) async throws { deletes += 1; if let mutationError { throw mutationError } }
    func reorder(chipID: String, actionIDs: [Int]) async throws { reorders += 1; if let mutationError { throw mutationError } }
    func migrateLegacy(chipID: String) async throws { migrations += 1; if let mutationError { throw mutationError } }
    func resumeCreate() { suspendCreate = false; createContinuation?.resume(); createContinuation = nil }
}

@MainActor
private final class DeferredPIRTriggerRepository: PIRTriggerActionRepository {
    var configurationContinuations: [CheckedContinuation<PIRTriggerConfiguration, any Error>] = []
    var targetContinuations: [CheckedContinuation<[PIRTriggerTarget], any Error>] = []
    func configuration(chipID: String) async throws -> PIRTriggerConfiguration { try await withCheckedThrowingContinuation { configurationContinuations.append($0) } }
    func targets(chipID: String) async throws -> [PIRTriggerTarget] { try await withCheckedThrowingContinuation { targetContinuations.append($0) } }
    func create(chipID: String, draft: PIRTriggerActionDraft) async throws {}
    func update(chipID: String, actionID: Int, draft: PIRTriggerActionDraft) async throws {}
    func delete(chipID: String, actionID: Int) async throws {}
    func reorder(chipID: String, actionIDs: [Int]) async throws {}
    func migrateLegacy(chipID: String) async throws {}
}


private final class PIRTriggerHTTPStub: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, String))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let result = try Self.handler?(request) ?? (500, "{}")
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: result.0, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(result.1.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

@MainActor
@Suite(.serialized)
struct PIRTriggerActionTests {
    private let draft = PIRTriggerActionDraft(targetID: 2, relayIndex: 0, durationMilliseconds: 1000, enabled: true)
    private let actionJSON = #"{"id":9,"origin":"persisted","action_type":"relay_pulse","target":{"id":2,"name":"Buzzer","chip_id":"buzz2","device_type":"buzzer"},"relay_index":0,"duration_ms":1000,"delay_ms":0,"enabled":true,"position":0}"#

    private func client(handler: @escaping (URLRequest) throws -> (Int, String)) -> PIRTriggerActionAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PIRTriggerHTTPStub.self]
        PIRTriggerHTTPStub.handler = { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-token")
            if request.httpMethod == "PUT" {
                #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            }
            return try handler(request)
        }
        return PIRTriggerActionAPIClient(transport: AuthenticatedTransport(authority: FixedTestSession(token: "fixture-token"), generation: 1, session: URLSession(configuration: configuration)), baseURL: URL(string: "https://example.test")!)
    }

    private func failure(_ operation: () async throws -> Void) async -> PIRTriggerActionFailure? {
        do { try await operation(); return nil }
        catch let value as PIRTriggerActionFailure { return value }
        catch { return .invalidResponse }
    }

    @Test func mapsNoneLegacyTargetMetadataAndNullTargetPrivacy() throws {
        let empty = try JSONDecoder().decode(PIRTriggerConfigurationDTO.self, from: Data(#"{"status":"success","configuration_mode":"none","source_device":{"id":1,"name":null,"chip_id":"pir"},"actions":[]}"#.utf8)).domain()
        #expect(empty.mode == .empty)
        let legacy = try JSONDecoder().decode(PIRTriggerConfigurationDTO.self, from: Data(#"{"status":"success","configuration_mode":"legacy","source_device":{"id":1,"name":"PIR","chip_id":"pir"},"actions":[{"id":null,"origin":"legacy","action_type":"relay_pulse","target":null,"relay_index":0,"duration_ms":1000,"delay_ms":0,"enabled":true,"position":0}]}"#.utf8)).domain()
        #expect(legacy.actions.single?.origin == .legacy)
        #expect(legacy.actions.single?.target == nil)
        let targets = try JSONDecoder().decode(PIRTriggerTargetsDTO.self, from: Data(#"{"status":"success","targets":[{"id":2,"chip_id":"buzz2","name":null,"device_type":"buzzer","relay_indexes":[0,1],"duration_ms":{"minimum":100,"maximum":10000}}]}"#.utf8)).targets.map { try $0.domain() }
        #expect(targets[0].relayIndexes == [0, 1])
        #expect(draft.isValid(using: targets))
    }

    @Test func createUsesEncodedPathZeroDelayAnd201Receipt() async throws {
        let api = client { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString.contains("pir%2Fa/trigger_actions") == true)
            #expect(request.url?.path.contains("/test") == false)
            guard let body = request.fixtureBody,
                  let json = try JSONSerialization.jsonObject(with: body) as? [String: Any] else {
                throw PIRTriggerActionFailure.invalidResponse
            }
            #expect(json["action_type"] as? String == "relay_pulse")
            #expect(json["delay_ms"] as? Int == 0)
            return (201, #"{"status":"success","action":\#(actionJSON)}"#)
        }
        try await api.create(chipID: "pir/a", draft: draft)
    }

    @Test func updateDeleteOrderAndMigrationUseExactContracts() async throws {
        var methods: [String] = []
        let api = client { request in
            methods.append(request.httpMethod ?? "")
            switch (request.httpMethod, request.url?.path) {
            case ("PUT", let path?) where path.hasSuffix("/9"):
                guard let body = request.fixtureBody,
                      let json = try JSONSerialization.jsonObject(with: body) as? [String: Any] else {
                    throw PIRTriggerActionFailure.invalidResponse
                }
                #expect(json["action_type"] as? String == "relay_pulse")
                #expect(json["delay_ms"] as? Int == 0)
                return (200, #"{"status":"success","action":\#(actionJSON)}"#)
            case ("DELETE", let path?) where path.hasSuffix("/9"):
                #expect(request.fixtureBody == nil)
                return (200, #"{"status":"success","action_id":9}"#)
            case ("PUT", let path?) where path.hasSuffix("/order"):
                guard let body = request.fixtureBody,
                      let json = try JSONSerialization.jsonObject(with: body) as? [String: Any] else {
                    throw PIRTriggerActionFailure.invalidResponse
                }
                #expect(json["action_ids"] as? [Int] == [9, 10])
                let second = actionJSON.replacingOccurrences(of: "\"id\":9", with: "\"id\":10").replacingOccurrences(of: "\"position\":0", with: "\"position\":1")
                return (200, #"{"status":"success","actions":[\#(actionJSON),\#(second)]}"#)
            case ("POST", let path?) where path.hasSuffix("/migrate_legacy"):
                #expect(request.fixtureBody == nil)
                return (200, #"{"status":"success","migrated":true,"mode":"actions","action":\#(actionJSON)}"#)
            default: return (500, "{}")
            }
        }
        try await api.update(chipID: "pir", actionID: 9, draft: draft)
        try await api.delete(chipID: "pir", actionID: 9)
        try await api.reorder(chipID: "pir", actionIDs: [9, 10])
        try await api.migrateLegacy(chipID: "pir")
        #expect(methods == ["PUT", "DELETE", "PUT", "POST"])
    }

    @Test func mapsStructuredDefiniteErrors() async {
        let cases: [(Int, String, PIRTriggerActionFailure)] = [
            (401, "session_expired", .authentication),
            (404, "target_not_found", .unavailable(code: "target_not_found", message: "message")),
            (409, "duplicate_action", .rejected(code: "duplicate_action", message: "message")),
            (422, "invalid_duration", .rejected(code: "invalid_duration", message: "message")),
            (503, "feature_disabled", .featureDisabled(message: "message"))
        ]
        for (status, code, expected) in cases {
            let api = client { _ in (status, #"{"status":"error","code":"\#(code)","message":"message"}"#) }
            #expect(await failure { try await api.create(chipID: "pir", draft: draft) } == expected)
        }
    }

    @Test func malformedReceiptsAreUncertainForEveryMutation() async {
        let api = client { request in (request.httpMethod == "POST" && request.url?.path.hasSuffix("trigger_actions") == true ? 201 : 200, #"{"status":"success"}"#) }
        let failures = [
            await failure { try await api.create(chipID: "pir", draft: draft) },
            await failure { try await api.update(chipID: "pir", actionID: 9, draft: draft) },
            await failure { try await api.delete(chipID: "pir", actionID: 9) },
            await failure { try await api.reorder(chipID: "pir", actionIDs: [9, 10]) },
            await failure { try await api.migrateLegacy(chipID: "pir") }
        ]
        #expect(failures.allSatisfy { $0 == .uncertainMutation })
    }

    @Test func duplicateMutationIsGated() async {
        let repository = FakePIRTriggerRepository()
        repository.suspendCreate = true
        let model = PIRTriggerActionsViewModel(chipID: "pir", useCases: .init(repository: repository))
        await model.load()
        let first = Task { await model.create(draft) }
        while repository.creates == 0 { await Task.yield() }
        await model.create(draft)
        #expect(repository.creates == 1)
        repository.resumeCreate()
        await first.value
        #expect(model.phase == .ready)
    }

    @Test func staleLoadCannotReplaceNewerSnapshot() async {
        let repository = DeferredPIRTriggerRepository()
        let model = PIRTriggerActionsViewModel(chipID: "pir", useCases: .init(repository: repository))
        let first = Task { await model.load() }
        while repository.configurationContinuations.count < 1 || repository.targetContinuations.count < 1 { await Task.yield() }
        let second = Task { await model.load() }
        while repository.configurationContinuations.count < 2 || repository.targetContinuations.count < 2 { await Task.yield() }
        let new = PIRTriggerConfiguration(mode: .empty, source: .init(id: 1, name: "new snapshot", chipID: "pir"), actions: [])
        repository.configurationContinuations[1].resume(returning: new)
        repository.targetContinuations[1].resume(returning: [])
        await second.value
        let old = PIRTriggerConfiguration(mode: .empty, source: .init(id: 1, name: "old snapshot", chipID: "pir"), actions: [])
        repository.configurationContinuations[0].resume(returning: old)
        repository.targetContinuations[0].resume(returning: [])
        await first.value
        #expect(model.snapshot?.configuration.source.name == "new snapshot")
    }

    @Test func legacyIsReadOnlyAndMigrationRequiresEligibleTarget() async {
        let repository = FakePIRTriggerRepository()
        let legacy = PIRTriggerAction(id: nil, origin: .legacy, target: .init(id: 2, name: "Buzzer", chipID: "buzz2", deviceType: .buzzer), relayIndex: 0, durationMilliseconds: 1000, delayMilliseconds: 0, enabled: true, position: 0)
        repository.configurationValue = PIRTriggerConfiguration(mode: .legacy, source: .init(id: 1, name: "PIR", chipID: "pir"), actions: [legacy])
        let model = PIRTriggerActionsViewModel(chipID: "pir", useCases: .init(repository: repository))
        await model.load()
        #expect(model.canMigrateLegacy)
        await model.create(draft)
        await model.update(action: legacy, draft: draft)
        await model.delete(legacy)
        #expect((repository.creates, repository.updates, repository.deletes) == (0, 0, 0))
        await model.migrateLegacy()
        #expect(repository.migrations == 1)
        repository.targetValues = []
        await model.load()
        #expect(!model.canMigrateLegacy)
    }

    @Test func failedPostSuccessReconciliationKeepsWritesBlocked() async {
        let repository = FakePIRTriggerRepository()
        let model = PIRTriggerActionsViewModel(chipID: "pir", useCases: .init(repository: repository))
        await model.load()
        repository.loadError = PIRTriggerActionFailure.connection
        await model.create(draft)
        #expect(model.phase == .uncertain)
        #expect(repository.creates == 1)
        await model.create(draft)
        #expect(repository.creates == 1)
        repository.loadError = nil
        await model.load()
        #expect(model.phase == .ready)
    }
}

private extension Array {
    var single: Element? { count == 1 ? self[0] : nil }
}

private extension URLRequest {
    var fixtureBody: Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else { return nil }
            if count == 0 { return data.isEmpty ? nil : data }
            guard data.count + count <= 16 * 1024 else { return nil }
            data.append(contentsOf: buffer.prefix(count))
        }
    }
}
