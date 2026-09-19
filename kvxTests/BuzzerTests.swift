import Foundation
import Testing
@testable import kvx

private final class BuzzerFixtureBundle: NSObject {}

@MainActor
private func buzzerFixture(duration: Int? = 1000, name: String = "Buzzer") -> BuzzerDetail {
    BuzzerDetail(id: "59", name: name, chipID: "fixture_buzzer", online: true, lastSeen: nil,
                 buildVersion: nil, appVersion: nil, testDurationMS: duration, sources: [], events: [])
}

@MainActor
private final class FakeBuzzerRepository: BuzzerRepository {
    var value = buzzerFixture()
    var loadError: Error?
    var sendError: Error?
    var sends: [BuzzerCommand] = []
    var loads = 0
    var suspended = false
    var pendingLoads: [CheckedContinuation<BuzzerDetail, Error>] = []
    var suspendSend = false
    var pendingSend: CheckedContinuation<BuzzerCommandReceipt, Error>?

    func detail(deviceID: String) async throws -> BuzzerDetail {
        loads += 1
        if suspended { return try await withCheckedThrowingContinuation { pendingLoads.append($0) } }
        if let loadError { throw loadError }
        return value
    }
    func send(_ command: BuzzerCommand, deviceID: String) async throws -> BuzzerCommandReceipt {
        sends.append(command)
        if suspendSend { return try await withCheckedThrowingContinuation { pendingSend = $0 } }
        if let sendError { throw sendError }
        return BuzzerCommandReceipt(cooldownSeconds: command == .test ? 3 : 0)
    }
}

@MainActor
struct BuzzerTests {
    private func model(_ repository: FakeBuzzerRepository, now: @escaping () -> Date = Date.init) -> BuzzerViewModel {
        BuzzerViewModel(deviceID: "59", useCases: BuzzerUseCases(repository: repository), now: now)
    }

    @Test func sharedFixtureMapsIdentityUnitsAndDates() throws {
        let bundle = Bundle(for: BuzzerFixtureBundle.self)
        let url = try #require(bundle.url(forResource: "buzzer-detail", withExtension: "json"))
        let dto = try JSONDecoder().decode(BuzzerDetailDTO.self, from: Data(contentsOf: url))
        let detail = try dto.toDomain()
        #expect(detail.id == "59")
        #expect(detail.chipID == "fixture_buzzer")
        #expect(detail.sources.first?.relayIndex == 0)
        #expect(detail.events.first?.durationMS == 1000)
        #expect(detail.events.first?.occurredAt == ISO8601DateFormatter().date(from: "2026-09-17T01:30:00+07:00"))
    }

    @Test func missingOptionalDataIsEmptyButMalformedRequiredDataFails() throws {
        let json = #"{"id":"59","name":"Buzzer","chip_id":"fixture","online":false,"sources":[],"events":[]}"#
        let value = try JSONDecoder().decode(BuzzerDetailDTO.self, from: Data(json.utf8)).toDomain()
        #expect(value.lastSeen == nil && value.sources.isEmpty && !value.canTest)
        let bad = json.replacingOccurrences(of: "\"sources\":[]", with: "\"sources\":null")
        #expect(throws: (any Error).self) { try JSONDecoder().decode(BuzzerDetailDTO.self, from: Data(bad.utf8)).toDomain() }
    }

    @Test func testDurationBoundariesAreValidatedBeforeSending() async throws {
        let repository = FakeBuzzerRepository()
        let useCases = BuzzerUseCases(repository: repository)
        for duration in [100, 10_000] {
            _ = try await useCases.execute(.test, detail: buzzerFixture(duration: duration))
        }
        for duration: Int? in [nil, 99, 10_001] {
            await #expect(throws: BuzzerError.self) {
                try await useCases.execute(.test, detail: buzzerFixture(duration: duration))
            }
        }
        #expect(repository.sends == [.test, .test])
    }

    @Test func refreshReadsSnapshotAndDoesNotRetryCommandWhenReadFails() async {
        let repository = FakeBuzzerRepository()
        let model = model(repository)
        await model.load()
        repository.loadError = URLError(.notConnectedToInternet)
        await model.send(.refresh)
        #expect(repository.sends == [.refresh])
        #expect(model.notice != nil && model.errorMessage != nil)
        #expect(model.detail != nil && !model.isBusy)
        repository.loadError = nil
        await model.load()
        #expect(repository.sends.count == 1 && model.errorMessage == nil)
    }

    @Test func failureDoesNotReportSuccessOrRetry() async {
        let repository = FakeBuzzerRepository()
        let model = model(repository)
        await model.load()
        repository.sendError = BuzzerError.commandFailed
        await model.send(.restart)
        #expect(repository.sends == [.restart])
        #expect(model.notice == nil && model.errorMessage != nil && !model.isBusy)
    }

    @Test func unauthorizedClearsDataAndOffersLogin() async {
        let repository = FakeBuzzerRepository()
        let model = model(repository)
        await model.load()
        repository.loadError = DeviceAPIError.httpStatus(401)
        await model.load()
        #expect(model.needsLogin && model.detail == nil)
        await model.send(.test)
        #expect(repository.sends.isEmpty)
        repository.loadError = nil
        await model.load()
        #expect(!model.needsLogin && model.detail != nil)
    }

    @Test func cooldownPreventsRepeatTestsAndServerCooldownIsHonored() async {
        let repository = FakeBuzzerRepository()
        var now = Date(timeIntervalSince1970: 100)
        let model = model(repository, now: { now })
        await model.load()
        await model.send(.test)
        await model.send(.test)
        #expect(repository.sends.count == 1)
        now = now.addingTimeInterval(3)
        repository.sendError = BuzzerError.cooldown(5)
        await model.send(.test)
        #expect(model.cooldownSeconds(at: now) == 5)
        #expect(model.notice == nil)
    }

    @Test func lostDeviceAccessClearsPreviousSnapshot() async {
        let repository = FakeBuzzerRepository()
        let model = model(repository)
        await model.load()
        repository.loadError = BuzzerError.unavailable
        await model.load()
        await model.send(.restart)
        #expect(model.detail == nil && repository.sends.isEmpty)
    }

    @Test func lateReadsCannotOverwriteNewerStateOrUpdateAfterDisappear() async {
        let repository = FakeBuzzerRepository()
        repository.suspended = true
        let model = model(repository)
        let first = Task { await model.load() }
        while repository.pendingLoads.count < 1 { await Task.yield() }
        let second = Task { await model.load() }
        while repository.pendingLoads.count < 2 { await Task.yield() }
        repository.pendingLoads[1].resume(returning: buzzerFixture(name: "new"))
        await second.value
        repository.pendingLoads[0].resume(returning: buzzerFixture(name: "old"))
        await first.value
        #expect(model.detail?.name == "new")
        let third = Task { await model.load() }
        while repository.pendingLoads.count < 3 { await Task.yield() }
        model.deactivate()
        repository.pendingLoads[2].resume(returning: buzzerFixture(name: "after disappear"))
        await third.value
        #expect(model.detail?.name == "new" && !model.isBusy)
    }

    @Test func duplicateCommandsAreIgnoredWhilePending() async {
        let repository = FakeBuzzerRepository()
        let model = model(repository)
        await model.load()
        repository.suspendSend = true
        let first = Task { await model.send(.restart) }
        while repository.pendingSend == nil { await Task.yield() }
        await model.send(.restart)
        await model.load()
        #expect(repository.sends == [.restart])
        repository.pendingSend?.resume(returning: BuzzerCommandReceipt(cooldownSeconds: 0))
        await first.value
        #expect(!model.isBusy)
    }
}

private struct BuzzerTestToken: AccessTokenProvider { let accessToken: String? = "fixture-token" }

private final class BuzzerHTTPStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let valid = request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-token" &&
            request.value(forHTTPHeaderField: "Accept") == "application/json"
        let isList = request.url?.path == "/api/devices"
        let validCommand = request.httpMethod == "POST" && request.url?.path == "/api/buzzers/59/test"
        let body = isList ? #"{"devices":[{"id":59,"name":"Fixture","chip_id":"fixture_buzzer","device_type":"buzzer","status":1}]}"# :
            #"{"status":"accepted","acknowledgement":"broker_only","cooldown_seconds":3}"#
        let status = valid && (isList || validCommand) ? 200 : 400
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
struct BuzzerHTTPTests {
    @Test func listMapsBuzzerAndCommandsUseDatabaseIDWithBearer() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BuzzerHTTPStub.self]
        let session = URLSession(configuration: configuration)
        let devices = try await BinblogDeviceDataSource(tokenProvider: BuzzerTestToken(), session: session).fetchDevices()
        #expect(devices.first?.type == .buzzer)
        #expect(devices.first?.chipID == "fixture_buzzer")
        let repository = BuzzerAPIClient(tokenProvider: BuzzerTestToken(), session: session)
        let receipt = try await repository.send(.test, deviceID: "59")
        #expect(receipt.cooldownSeconds == 3)
    }
}
