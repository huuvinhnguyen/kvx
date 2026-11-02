import Foundation
import Testing
@testable import kvx

private final class SwitchFixtureBundleMarker: NSObject {}
private func switchFixture(_ name: String) throws -> Data {
    let bundle = Bundle(for: SwitchFixtureBundleMarker.self)
    let url = try #require(bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/SwitchAPI")
        ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "SwitchAPI")
        ?? bundle.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

@MainActor private final class FakeSwitchRepository: SwitchRepository {
    var posts = 0
    var failRead = false
    var unknown = false
    var pending: CheckedContinuation<Void, Never>?
    var deferCommand = false
    var readPending: CheckedContinuation<SwitchDetail, Error>?
    var deferRead = false
    var relayRequests: [Int] = []
    func detail(deviceID: String) async throws -> SwitchDetail {
        if deferRead { return try await withCheckedThrowingContinuation { readPending = $0 } }
        if failRead { throw SwitchFailure.connection }
        return try SwitchAPIClient.decodeDetail(switchFixture("detail"))
    }
    func reminders(deviceID: String, relay: Int, afterID: String?) async throws -> SwitchReminderPage {
        relayRequests.append(relay)
        return SwitchReminderPage(status: "success", reminders: [], nextAfterId: nil)
    }
    func statistics(deviceID: String, relay: Int) async throws -> SwitchStatistics {
        try SwitchAPIClient.decodeStatistics(switchFixture("statistics"))
    }
    private func command() async throws {
        posts += 1
        if deferCommand { await withCheckedContinuation { pending = $0 } }
        if unknown { throw SwitchFailure.uncertain }
    }
    func state(deviceID: String, relay: Int, value: Int) async throws { try await command() }
    func pulse(deviceID: String, relay: Int, durationMS: Int) async throws { try await command() }
    func refresh(deviceID: String) async throws { try await command() }
}

@MainActor @Suite(.serialized) struct SwitchTests {
    @Test func durationBoundaries() {
        #expect(SwitchDuration.milliseconds("1", minutes: false) == 1000)
        #expect(SwitchDuration.milliseconds("1440", minutes: true) == 86400000)
        for raw in ["", "0", "-1", "1.5", "86401", "999999999999999999999999"] {
            #expect(SwitchDuration.milliseconds(raw, minutes: false) == nil)
        }
    }
    @Test func sharedDetailNullStateAndMalformed() throws {
        let fixture = try switchFixture("detail")
        let detail = try SwitchAPIClient.decodeDetail(fixture)
        #expect(detail.relays[0].switchValue == nil)
        var root = try #require(JSONSerialization.jsonObject(with: fixture) as? [String: Any])
        var d = root["switch"] as! [String: Any]
        var relays = d["relays"] as! [[String: Any]]
        relays[0].removeValue(forKey: "switch_value"); d["relays"] = relays; root["switch"] = d
        let data = try JSONSerialization.data(withJSONObject: root)
        #expect(throws: SwitchFailure.self) { try SwitchAPIClient.decodeDetail(data) }
    }
    @Test func nullLegacyReminderVisibleAndForeignScopeRejected() throws {
        let data = try switchFixture("reminders")
        var root = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var rows = root["reminders"] as! [[String: Any]]
        rows[0]["start_time"] = NSNull(); rows[0]["duration_ms"] = NSNull()
        rows[0]["configuration_valid"] = false; rows[0]["repeat_type"] = "unsupported"
        root["reminders"] = rows
        let invalid = try JSONSerialization.data(withJSONObject: root)
        let page = try SwitchAPIClient.decodeReminders(invalid, deviceID: "1", relay: 0, afterID: nil)
        #expect(page.reminders.count == 1)
        #expect(page.reminders[0].startTime == nil && !page.reminders[0].configurationValid)
        #expect(throws: SwitchFailure.self) { try SwitchAPIClient.decodeReminders(invalid, deviceID: "22", relay: 0, afterID: nil) }
    }
    @Test func statisticsDoNotInferRuntimeAndRejectMissingDays() throws {
        let data = try switchFixture("statistics")
        #expect(try SwitchAPIClient.decodeStatistics(data).totalRecords == 0)
        var root = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        root["days"] = []
        let invalid = try JSONSerialization.data(withJSONObject: root)
        #expect(throws: SwitchFailure.self) { try SwitchAPIClient.decodeStatistics(invalid) }
    }
    @Test func duplicateCommandsAndHonestState() async throws {
        let repo = FakeSwitchRepository()
        let model = SwitchViewModel(deviceID: "1", useCases: SwitchUseCases(repository: repo))
        await model.load(); repo.deferCommand = true
        let task = Task { await model.state(1) }
        while repo.pending == nil { await Task.yield() }
        await model.state(0); await model.refreshDevice()
        #expect(repo.posts == 1)
        #expect(model.detail?.relays[0].switchValue == nil)
        repo.pending?.resume(); await task.value
        #expect(model.readReady && model.notice?.contains("chưa xác nhận") == true)
    }
    @Test func unknownNeedsReadAndPhysicalReconciliation() async {
        let repo = FakeSwitchRepository(); repo.unknown = true
        let model = SwitchViewModel(deviceID: "1", useCases: SwitchUseCases(repository: repo))
        await model.load(); await model.state(1)
        #expect(model.uncertain && !model.canCommand)
        await model.state(1); #expect(repo.posts == 1)
        repo.failRead = true; await model.load(); model.acknowledgePhysicalCheck()
        #expect(model.uncertain && !model.canCommand)
        repo.failRead = false; await model.load()
        #expect(model.uncertain)
        model.acknowledgePhysicalCheck(); #expect(model.canCommand)
    }
    @Test func reopenPreservesPendingAndUnknownCommand() async {
        let repo = FakeSwitchRepository(); repo.unknown = true; repo.deferCommand = true
        let cases = SwitchUseCases(repository: repo)
        let first = SwitchViewModel(deviceID: "1", useCases: cases); await first.load()
        let task = Task { await first.state(1) }
        while repo.pending == nil { await Task.yield() }
        first.deactivate()
        let reopened = SwitchViewModel(deviceID: "1", useCases: cases); await reopened.load()
        #expect(!reopened.canCommand); reopened.acknowledgePhysicalCheck()
        await reopened.state(0); #expect(repo.posts == 1)
        repo.pending?.resume(); await task.value
        #expect(reopened.uncertain); await reopened.load(); #expect(!reopened.canCommand)
        reopened.acknowledgePhysicalCheck(); #expect(reopened.canCommand)
    }
    @Test func deactivatedCompletionIgnored() async throws {
        let repo = FakeSwitchRepository(); repo.deferRead = true
        let model = SwitchViewModel(deviceID: "1", useCases: SwitchUseCases(repository: repo))
        let task = Task { await model.load() }
        while repo.readPending == nil { await Task.yield() }
        model.deactivate()
        repo.readPending?.resume(returning: try SwitchAPIClient.decodeDetail(switchFixture("detail")))
        await task.value
        #expect(model.detail == nil && !model.canCommand)
    }
}

nonisolated private struct SwitchFixtureSession: SessionAuthorizing {
    func snapshot(expectedGeneration: UInt64?) async throws -> SessionSnapshot { SessionSnapshot(token: "synthetic-switch-token", generation: 1) }
    func isCurrent(_ generation: UInt64) async -> Bool { generation == 1 }
    func dispatch(_ generation: UInt64, start: @Sendable () -> Void) async throws { start() }
    func unauthorized(_ generation: UInt64) async -> Bool { true }
    func dispatchPrepared(_ lease: MutationLease, start: @Sendable () -> Void) async throws { throw SessionFailure.storage }
}

nonisolated private final class SwitchHTTPStub: URLProtocol {
    nonisolated(unsafe) static var calls = 0
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.calls += 1
        let path = request.url!.path
        if path.contains("/2/") { client?.urlProtocol(self, didFailWithError: URLError(.timedOut)); return }
        let valid = request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-switch-token"
            && request.value(forHTTPHeaderField: "Accept") == "application/json"
            && request.httpMethod == "POST"
        let code = !valid ? 401 : path.contains("/3/") ? 502 : 200
        let body: String
        if path.contains("/4/") { body = "{}" }
        else if code != 200 { body = "{\"code\":\"command_outcome_unknown\",\"outcome\":\"unknown\"}" }
        else {
            let data: Data
            if let direct = request.httpBody { data = direct }
            else if let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var result = Data(); var buffer = [UInt8](repeating: 0, count: 1024)
                while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; result.append(contentsOf: buffer.prefix(n)) }
                data = result
            } else { data = Data() }
            let fields = (try? JSONSerialization.jsonObject(with: data)) as? [String: Int]
            let validBody = path.hasSuffix("/state") ? fields == ["switch_value": 1]
                : path.hasSuffix("/pulse") ? fields == ["duration_ms": 60000] : path.hasSuffix("/refresh") && data.isEmpty
            body = validBody ? "{\"status\":\"accepted\",\"outcome\":\"publish_returned\",\"acknowledgement\":\"none\",\"request_id\":\"synthetic\",\"event_id\":\"1\"}" : "{}"
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor @Suite(.serialized) struct SwitchTransportTests {
    private func api() -> SwitchAPIClient {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [SwitchHTTPStub.self]
        return SwitchAPIClient(transport: AuthenticatedTransport(authority: SwitchFixtureSession(), session: URLSession(configuration: config)))
    }
    @Test func authenticatedMethodBodyAndRefresh() async throws {
        SwitchHTTPStub.calls = 0
        let client = api()
        try await client.state(deviceID: "1", relay: 0, value: 1)
        try await client.pulse(deviceID: "1", relay: 0, durationMS: 60000)
        try await client.refresh(deviceID: "1")
        #expect(SwitchHTTPStub.calls == 3)
    }
    @Test func unknownErrorsDoNotRetry() async {
        for id in ["2", "3", "4"] {
            SwitchHTTPStub.calls = 0
            do { try await api().state(deviceID: id, relay: 0, value: 1); Issue.record("Expected unknown outcome") }
            catch { #expect((error as? SwitchFailure) == .uncertain) }
            #expect(SwitchHTTPStub.calls == 1)
        }
    }
    @Test func invalidDurationAndIDNeverDispatch() async {
        SwitchHTTPStub.calls = 0
        do { try await api().pulse(deviceID: "1", relay: 0, durationMS: 999); Issue.record("Expected validation") }
        catch { #expect((error as? SwitchFailure) == .validation) }
        do { try await api().state(deviceID: "chip", relay: 0, value: 1); Issue.record("Expected validation") }
        catch { #expect((error as? SwitchFailure) == .validation) }
        #expect(SwitchHTTPStub.calls == 0)
    }
}
