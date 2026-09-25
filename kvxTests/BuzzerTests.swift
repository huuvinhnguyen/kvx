import Foundation
import Testing
@testable import kvx

@MainActor
private final class FakeBuzzerRepository: BuzzerRepository {
    var detailValue = BuzzerDetail(id: "42", name: "Hall Buzzer", chipID: "ESP32_BUZZER_02", online: true, lastSeen: nil, linkedPIRCount: 1, lastTriggeredAt: nil, sources: [], events: [])
    var sourcesValue = [BuzzerSource(id: "7", name: "Hall PIR", chipID: "ESP32_PIR_01", relayIndex: 0, longlast: 1000)]
    var eventsValue = [BuzzerMotionEvent(id: "123", eventType: "motion_detected", pirID: "7", sourceName: "Hall PIR", sourceChipID: "ESP32_PIR_01", occurredAt: Date(), relayIndex: 0, longlast: 1000)]
    var loadError: Error?
    var testError: Error?
    var links = 0
    var unlinks = 0
    var failAvailable = false
    var availableError: Error?
    var linkError: Error?
    var unlinkError: Error?
    var deferLink = false
    var pendingLink: CheckedContinuation<Void, Error>?
    var availableValue = [AvailableBuzzerPIR(id: "7", name: "Hall PIR", chipID: "ESP32_PIR_01", linkedBuzzer: nil, requiresConfirmation: false)]
    func availablePIRs(deviceID: String) async throws -> [AvailableBuzzerPIR] { if let availableError { throw availableError }; if failAvailable { throw BuzzerError.unavailable }; return availableValue }
    func link(deviceID: String, configuration: BuzzerLinkConfiguration) async throws {
        links += 1
        if deferLink { try await withCheckedThrowingContinuation { pendingLink = $0 } }
        if let linkError { throw linkError }
    }
    func unlink(deviceID: String, pirID: String) async throws { unlinks += 1; if let unlinkError { throw unlinkError } }
    var tests = 0
    var loads = 0

    func detail(deviceID: String) async throws -> BuzzerDetail { loads += 1; if let loadError { throw loadError }; return detailValue }
    func linkedPIRs(deviceID: String) async throws -> [BuzzerSource] { if let loadError { throw loadError }; return sourcesValue }
    func history(deviceID: String) async throws -> [BuzzerMotionEvent] { if let loadError { throw loadError }; return eventsValue }
    func test(deviceID: String) async throws -> BuzzerTestReceipt { tests += 1; if let testError { throw testError }; return BuzzerTestReceipt(message: "Command sent to MQTT broker", relayIndex: 0, longlast: 1000) }
}

@MainActor
private final class DeferredBuzzerRepository: BuzzerRepository {
    var pending: [CheckedContinuation<BuzzerDetail, Error>] = []
    func availablePIRs(deviceID: String) async throws -> [AvailableBuzzerPIR] { [] }
    func link(deviceID: String, configuration: BuzzerLinkConfiguration) async throws {}
    func unlink(deviceID: String, pirID: String) async throws {}
    func detail(deviceID: String) async throws -> BuzzerDetail {
        try await withCheckedThrowingContinuation { pending.append($0) }
    }
    func linkedPIRs(deviceID: String) async throws -> [BuzzerSource] { [] }
    func history(deviceID: String) async throws -> [BuzzerMotionEvent] { [] }
    func test(deviceID: String) async throws -> BuzzerTestReceipt { BuzzerTestReceipt(message: "sent", relayIndex: nil, longlast: nil) }
}

@MainActor
struct BuzzerTests {
    @Test func uncertainLinkRequiresRefreshAndDoesNotReplay() async {
        let repository = FakeBuzzerRepository()
        let model = BuzzerViewModel(deviceID: "42", useCases: BuzzerUseCases(repository: repository))
        await model.load(); await model.loadAvailable()
        repository.linkError = BuzzerError.uncertainMutation
        await model.link(BuzzerLinkConfiguration(pirID: "7", relayIndex: 0, longlast: 1000))
        #expect(model.requiresRefresh)
        #expect(model.errorMessage?.contains("Chưa xác nhận") == true)
        await model.link(BuzzerLinkConfiguration(pirID: "7", relayIndex: 0, longlast: 1000))
        await model.unlink(pirID: "7")
        #expect(repository.links == 1 && repository.unlinks == 0 && repository.tests == 0)
        repository.linkError = nil
        await model.load()
        #expect(!model.requiresRefresh)
        await model.link(BuzzerLinkConfiguration(pirID: "7", relayIndex: 0, longlast: 1000))
        #expect(repository.links == 2)
    }

    @Test func uncertainUnlinkRequiresRefresh() async {
        let repository = FakeBuzzerRepository()
        let model = BuzzerViewModel(deviceID: "42", useCases: BuzzerUseCases(repository: repository))
        await model.load(); await model.loadAvailable()
        repository.unlinkError = BuzzerError.uncertainMutation
        await model.unlink(pirID: "7")
        #expect(model.requiresRefresh)
        await model.unlink(pirID: "7")
        #expect(repository.unlinks == 1 && repository.tests == 0)
        repository.unlinkError = nil
        await model.load()
        #expect(!model.requiresRefresh)
    }

    @Test func definiteValidationRejectionDoesNotRequireRefresh() async {
        let repository = FakeBuzzerRepository()
        let model = BuzzerViewModel(deviceID: "42", useCases: BuzzerUseCases(repository: repository))
        await model.load(); await model.loadAvailable()
        repository.linkError = BuzzerError.invalidConfiguration
        await model.link(BuzzerLinkConfiguration(pirID: "7", relayIndex: 0, longlast: 1000))
        #expect(!model.requiresRefresh)
    }

    @Test func disappearingDuringLinkRefreshesAfterReactivation() async {
        let repository = FakeBuzzerRepository()
        repository.deferLink = true
        let model = BuzzerViewModel(deviceID: "42", useCases: BuzzerUseCases(repository: repository))
        await model.activate(); await model.loadAvailable()
        let write = Task { await model.link(BuzzerLinkConfiguration(pirID: "7", relayIndex: 0, longlast: 1000)) }
        while repository.pendingLink == nil { await Task.yield() }
        model.deactivate()
        await model.activate()
        #expect(model.requiresRefresh && model.isMutating)
        repository.sourcesValue = []
        repository.pendingLink?.resume()
        await write.value
        #expect(!model.requiresRefresh && !model.isMutating)
        #expect(model.sources.isEmpty && repository.links == 1)
        #expect(repository.tests == 0)
    }

    @Test func concurrentDuplicateManagementSubmissionIsBlocked() async {
        let repository = FakeBuzzerRepository()
        repository.deferLink = true
        let model = BuzzerViewModel(deviceID: "42", useCases: BuzzerUseCases(repository: repository))
        await model.load(); await model.loadAvailable()

        let first = Task { await model.link(BuzzerLinkConfiguration(pirID: "7", relayIndex: 0, longlast: 1000)) }
        while repository.pendingLink == nil { await Task.yield() }
        await model.link(BuzzerLinkConfiguration(pirID: "7", relayIndex: 1, longlast: 1500))
        await model.unlink(pirID: "7")
        #expect(repository.links == 1 && repository.unlinks == 0)
        #expect(model.isMutating)

        repository.pendingLink?.resume()
        await first.value
        #expect(!model.isMutating && !model.requiresRefresh)
        repository.deferLink = false
        await model.link(BuzzerLinkConfiguration(pirID: "7", relayIndex: 0, longlast: 1000))
        #expect(repository.links == 2)
        #expect(!model.requiresRefresh)
    }

    @Test func disappearingDuringLinkKeepsBlockIfRefreshFails() async {
        let repository = FakeBuzzerRepository()
        repository.deferLink = true
        let model = BuzzerViewModel(deviceID: "42", useCases: BuzzerUseCases(repository: repository))
        await model.activate(); await model.loadAvailable()
        let write = Task { await model.link(BuzzerLinkConfiguration(pirID: "7", relayIndex: 0, longlast: 1000)) }
        while repository.pendingLink == nil { await Task.yield() }
        model.deactivate()
        await model.activate()
        repository.failAvailable = true
        repository.pendingLink?.resume()
        await write.value
        #expect(model.requiresRefresh)
        repository.failAvailable = false
        await model.load()
        #expect(!model.requiresRefresh)
    }

    @Test func linkedAndHistoryAcceptStoredScalarsAndNulls() throws {
        let pirs = try BuzzerLinkedPIRDTO.from(Data(#"{"status":"success","linked_pirs":[{"id":7,"name":null,"chip_id":"pir7","relay_index":"2","longlast":"500"}]}"#.utf8))
        let source = try pirs[0].toDomain()
        #expect(source.name == "pir7" && source.relayIndex == 2 && source.relayDisplay == "2")
        #expect(source.longlast == 500 && source.longlastDisplay == "500")
        let events = try BuzzerHistoryEventDTO.from(Data(#"{"status":"success","events":[{"id":1,"event_type":"motion_detected","occurred_at":"2026-09-19T10:29:00+07:00","pir":{"id":7,"name":null,"chip_id":"pir7"},"relay_index":null,"longlast":null}]}"#.utf8))
        let event = try events[0].toDomain()
        #expect(event.sourceName == "pir7" && event.relayIndex == nil && event.longlast == nil)
    }

    @Test func availablePIRUnauthorizedRequiresLogin() async {
        let repository = FakeBuzzerRepository()
        let model = BuzzerViewModel(deviceID: "42", useCases: BuzzerUseCases(repository: repository))
        await model.load()
        repository.availableError = DeviceAPIError.httpStatus(401)
        await model.loadAvailable()
        #expect(model.needsLogin && model.availableError != nil)
    }

    @Test func successfulMutationWithFailedRefreshBlocksFurtherWrites() async {
        let repository = FakeBuzzerRepository()
        let model = BuzzerViewModel(deviceID: "42", useCases: BuzzerUseCases(repository: repository))
        await model.load()
        await model.loadAvailable()
        repository.failAvailable = true
        await model.link(BuzzerLinkConfiguration(pirID: "7", relayIndex: 0, longlast: 1000))
        #expect(repository.links == 1)
        #expect(model.requiresRefresh)
        await model.link(BuzzerLinkConfiguration(pirID: "7", relayIndex: 0, longlast: 1000))
        #expect(repository.links == 1)
        #expect(repository.tests == 0)
        await model.load()
        #expect(model.errorMessage?.contains("Đã cập nhật cấu hình PIR") == true)
        repository.failAvailable = false
        await model.load()
        #expect(!model.requiresRefresh)
    }

    @Test func successfulUnlinkWithFailedRefreshBlocksFurtherWrites() async {
        let repository = FakeBuzzerRepository()
        let model = BuzzerViewModel(deviceID: "42", useCases: BuzzerUseCases(repository: repository))
        await model.load(); await model.loadAvailable()
        repository.failAvailable = true
        await model.unlink(pirID: "7")
        #expect(model.requiresRefresh && repository.unlinks == 1)
        await model.unlink(pirID: "7")
        #expect(repository.unlinks == 1)
        repository.failAvailable = false
        await model.load()
        #expect(!model.requiresRefresh)
    }

    @Test func availablePIRDecodingPreservesNullableFields() throws {
        let data = Data(#"{"status":"success","available_pirs":[{"id":7,"name":null,"chip_id":"pir7","linked_buzzer":null,"requires_confirmation":true},{"id":8,"name":"PIR","chip_id":"pir8","linked_buzzer":{"id":99,"name":null},"requires_confirmation":true}]}"#.utf8)
        let decoded = try JSONDecoder().decode(AvailablePIRResponseDTO.self, from: data)
        #expect(decoded.available_pirs[0].domain.name == nil)
        #expect(decoded.available_pirs[0].domain.linkedBuzzer == nil)
        #expect(decoded.available_pirs[1].domain.linkedBuzzer?.id == "99")
        #expect(decoded.available_pirs[1].domain.linkedBuzzer?.name == nil)
    }

    @Test func linkValidationAndPrivacy() {
        #expect(BuzzerLinkConfiguration(pirID: "7", relayIndex: 0, longlast: 100).isValid)
        #expect(BuzzerLinkConfiguration(pirID: "7", relayIndex: 0, longlast: 10000).isValid)
        #expect(!BuzzerLinkConfiguration(pirID: "7", relayIndex: -1, longlast: 1000).isValid)
        #expect(!BuzzerLinkConfiguration(pirID: "7", relayIndex: 0, longlast: 10001).isValid)
        let hidden = AvailableBuzzerPIR(id: "7", name: nil, chipID: "pir7", linkedBuzzer: nil, requiresConfirmation: true)
        #expect(hidden.confirmation(currentBuzzerID: "42")?.contains("Cấu hình hiện có") == true)
        let visible = AvailableBuzzerPIR(id: "7", name: "PIR", chipID: "pir7", linkedBuzzer: LinkedBuzzer(id: "99", name: "Other"), requiresConfirmation: true)
        #expect(visible.confirmation(currentBuzzerID: "42")?.contains("Other") == true)
    }

    @Test func linkRefreshesWithoutTesting() async {
        let repository = FakeBuzzerRepository()
        let model = BuzzerViewModel(deviceID: "42", useCases: BuzzerUseCases(repository: repository))
        await model.load()
        await model.loadAvailable()
        await model.link(BuzzerLinkConfiguration(pirID: "7", relayIndex: 0, longlast: 100))
        #expect(repository.links == 1)
        #expect(repository.tests == 0)
        #expect(!model.requiresRefresh)
    }

    @Test func backendEntitiesPreserveDetailLinkedPIRAndHistoryFields() {
        let repository = FakeBuzzerRepository()
        #expect(repository.detailValue.id == "42")
        #expect(repository.sourcesValue.first?.longlast == 1000)
        #expect(repository.eventsValue.first?.eventType == "motion_detected")
        #expect(repository.eventsValue.first?.pirID == "7")
    }

    @Test func useCaseLoadsTheThreeReadEndpointsTogether() async throws {
        let repository = FakeBuzzerRepository()
        let result = try await BuzzerUseCases(repository: repository).load(deviceID: "42")
        #expect(result.0.id == "42")
        #expect(result.1.count == 1)
        #expect(result.2.count == 1)
    }

    @Test func testUsesOnlyTheSupportedTestOperation() async throws {
        let repository = FakeBuzzerRepository()
        let receipt = try await BuzzerUseCases(repository: repository).test(deviceID: "42")
        #expect(receipt.message == "Command sent to MQTT broker")
        #expect(repository.tests == 1)
    }

    @Test func serverCooldownIsRecordedAndBlocksRepeatedTest() async {
        let repository = FakeBuzzerRepository()
        let model = BuzzerViewModel(deviceID: "42", useCases: BuzzerUseCases(repository: repository))
        await model.load()
        repository.testError = BuzzerError.cooldown(5)
        await model.test()
        #expect(model.cooldownSeconds(at: Date()) == 5)
        await model.test()
        #expect(repository.tests == 1)
    }

    @Test func successfulTestStartsLocalCooldownAndReloadDoesNotReplayPost() async {
        let repository = FakeBuzzerRepository()
        var currentTime = Date()
        let model = BuzzerViewModel(deviceID: "42", useCases: BuzzerUseCases(repository: repository), now: { currentTime })
        await model.load()
        await model.test()
        #expect(model.cooldownSeconds(at: currentTime) == 3)
        #expect(repository.tests == 1)
        await model.load()
        #expect(repository.tests == 1)
        repository.testError = BuzzerError.cooldown(8)
        currentTime = currentTime.addingTimeInterval(4)
        await model.test()
        #expect(model.cooldownSeconds(at: currentTime) == 8)
    }

    @Test func staleLoadCannotOverwriteNewerState() async {
        let repository = DeferredBuzzerRepository()
        let model = BuzzerViewModel(deviceID: "42", useCases: BuzzerUseCases(repository: repository))
        let old = Task { await model.load() }
        while repository.pending.count < 1 { await Task.yield() }
        let newer = Task { await model.load() }
        while repository.pending.count < 2 { await Task.yield() }
        let fresh = BuzzerDetail(id: "42", name: "new", chipID: "chip", online: true, lastSeen: nil, linkedPIRCount: 0, lastTriggeredAt: nil, sources: [], events: [])
        let stale = BuzzerDetail(id: "42", name: "old", chipID: "chip", online: true, lastSeen: nil, linkedPIRCount: 0, lastTriggeredAt: nil, sources: [], events: [])
        repository.pending[1].resume(returning: fresh)
        await newer.value
        repository.pending[0].resume(returning: stale)
        await old.value
        #expect(model.detail?.name == "new")
    }

    @Test func detailTimestampsRejectMalformedValuesAndAcceptNull() throws {
        func decode(_ seen: String, _ triggered: String) throws -> BuzzerDetail {
            let json = """
            {"status":"success","buzzer":{"id":42,"name":"Buzzer","chip_id":"chip","device_type":"buzzer","online":true,"last_seen":\(seen),"linked_pir_count":0,"last_triggered_at":\(triggered)}}
            """
            return try BuzzerDetailDTO.fromDetail(Data(json.utf8)).toDomain()
        }
        let empty = try decode("null", "null")
        #expect(empty.lastSeen == nil && empty.lastTriggeredAt == nil)
        #expect(throws: BuzzerError.self) { try decode("\"bad\"", "null") }
        #expect(throws: BuzzerError.self) { try decode("null", "\"bad\"") }
    }

    @Test func emptyLinkedPIRsAndHistoryAreAccepted() throws {
        let pirs = try BuzzerLinkedPIRDTO.from(Data(#"{"status":"success","linked_pirs":[]}"#.utf8))
        let events = try BuzzerHistoryEventDTO.from(Data(#"{"status":"success","events":[]}"#.utf8))
        #expect(pirs.isEmpty && events.isEmpty)
    }

    @Test func unavailableAndUnauthorizedErrorsClearData() async {
        let repository = FakeBuzzerRepository()
        let model = BuzzerViewModel(deviceID: "42", useCases: BuzzerUseCases(repository: repository))
        await model.load()
        repository.loadError = BuzzerError.unavailable
        await model.load()
        #expect(model.detail == nil)
        repository.loadError = DeviceAPIError.httpStatus(401)
        await model.load()
        #expect(model.needsLogin)
        #expect(model.detail == nil)
    }
}

private struct BuzzerTestToken: AccessTokenProvider { let accessToken: String? = "fixture-token" }

private final class BuzzerHTTPStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    private func bodyData() -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
    override func startLoading() {
        let path = request.url?.path ?? ""
        if path.hasPrefix("/api/devices/88/buzzer/linked_pirs") && request.httpMethod != "GET" {
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
            return
        }
        let isLink = path == "/api/devices/42/buzzer/linked_pirs" && request.httpMethod == "POST"
        let isUnlink = path == "/api/devices/42/buzzer/linked_pirs/7" && request.httpMethod == "DELETE"
        let valid = request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-token"
            && (isLink || isUnlink || request.httpMethod == (path.hasSuffix("/test") ? "POST" : "GET"))
            && (!path.hasSuffix("/test") || request.httpBody == nil)
            && (!isUnlink || request.httpBody == nil)
            && (!isUnlink || request.httpBodyStream == nil)
            && (!isLink || ((try? JSONSerialization.jsonObject(with: bodyData() ?? Data())) as? [String: Int]) == ["pir_id": 7, "relay_index": 0, "longlast": 100])
        let body: String
        switch path {
        case "/api/devices/42/buzzer":
            body = #"{"status":"success","buzzer":{"id":42,"name":"Hall Buzzer","chip_id":"ESP32_BUZZER_02","device_type":"buzzer","online":true,"last_seen":null,"linked_pir_count":1,"last_triggered_at":null}}"#
        case "/api/devices/42/buzzer/available_pirs":
            body = #"{"status":"success","available_pirs":[{"id":7,"name":null,"chip_id":"pir7","linked_buzzer":null,"requires_confirmation":true}]}"#
        case "/api/devices/42/buzzer/linked_pirs/7":
            body = #"{"status":"success","pir_id":7}"#
        case "/api/devices/42/buzzer/linked_pirs" where isLink:
            body = #"{"status":"success","linked_pir":{"id":7,"name":null,"chip_id":"pir7","relay_index":0,"longlast":100}}"#
        case "/api/devices/42/buzzer/linked_pirs":
            body = #"{"status":"success","linked_pirs":[{"id":7,"name":"Hall PIR","chip_id":"ESP32_PIR_01","relay_index":0,"longlast":1000}]}"#
        case "/api/devices/42/buzzer/history":
            body = #"{"status":"success","events":[{"id":123,"event_type":"motion_detected","occurred_at":"2026-09-19T10:29:00+07:00","pir":{"id":7,"name":"Hall PIR","chip_id":"ESP32_PIR_01"},"relay_index":0,"longlast":1000}]}"#
        case "/api/devices/42/buzzer/test":
            body = #"{"status":"success","message":"Command sent to MQTT broker","relay_index":0,"longlast":1000}"#
        default: body = #"{"status":"error"}"#
        }
        let scenario = path.split(separator: "/").dropFirst(2).first.flatMap { Int($0) }.flatMap { [401, 422, 429, 503].contains($0) ? $0 : nil }
        let status = valid ? (scenario ?? 200) : 401
        let headers = status == 429 ? ["Retry-After": "7"] : nil
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
struct BuzzerHTTPTests {
    @Test func uncertainManagementTransportIsNotADefiniteRejection() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BuzzerHTTPStub.self]
        let client = BuzzerAPIClient(tokenProvider: BuzzerTestToken(), session: URLSession(configuration: configuration))
        do { try await client.link(deviceID: "88", configuration: BuzzerLinkConfiguration(pirID: "7", relayIndex: 0, longlast: 100)); Issue.record("Expected uncertain POST") }
        catch BuzzerError.uncertainMutation {} catch { Issue.record("Wrong POST error: \(error)") }
        do { try await client.unlink(deviceID: "88", pirID: "7"); Issue.record("Expected uncertain DELETE") }
        catch BuzzerError.uncertainMutation {} catch { Issue.record("Wrong DELETE error: \(error)") }
    }

    @Test func managementUsesDocumentedPathsAndNumericBody() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BuzzerHTTPStub.self]
        let client = BuzzerAPIClient(tokenProvider: BuzzerTestToken(), session: URLSession(configuration: configuration))
        #expect(try await client.availablePIRs(deviceID: "42").count == 1)
        try await client.link(deviceID: "42", configuration: BuzzerLinkConfiguration(pirID: "7", relayIndex: 0, longlast: 100))
        try await client.unlink(deviceID: "42", pirID: "7")
    }

    @Test func clientUsesDocumentedDeviceScopedEndpoints() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BuzzerHTTPStub.self]
        let session = URLSession(configuration: configuration)
        let client = BuzzerAPIClient(tokenProvider: BuzzerTestToken(), session: session)
        let detail = try await client.detail(deviceID: "42")
        let pirs = try await client.linkedPIRs(deviceID: "42")
        let events = try await client.history(deviceID: "42")
        let receipt = try await client.test(deviceID: "42")
        #expect(detail.id == "42")
        #expect(pirs.first?.id == "7")
        #expect(events.first?.eventType == "motion_detected")
        #expect(receipt.message == "Command sent to MQTT broker")
    }

    @Test func httpErrorsAndRetryAfterAreMapped() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BuzzerHTTPStub.self]
        let client = BuzzerAPIClient(tokenProvider: BuzzerTestToken(), session: URLSession(configuration: configuration))
        do { _ = try await client.detail(deviceID: "401"); Issue.record("Expected 401") }
        catch DeviceAPIError.httpStatus(401) {} catch { Issue.record("Wrong 401 error: \(error)") }
        do { _ = try await client.test(deviceID: "422"); Issue.record("Expected 422") }
        catch BuzzerError.invalidConfiguration {} catch { Issue.record("Wrong 422 error: \(error)") }
        do { _ = try await client.test(deviceID: "429"); Issue.record("Expected 429") }
        catch BuzzerError.cooldown(let seconds) { #expect(seconds == 7) }
        catch { Issue.record("Wrong 429 error: \(error)") }
        do { _ = try await client.test(deviceID: "503"); Issue.record("Expected 503") }
        catch BuzzerError.commandFailed {} catch { Issue.record("Wrong 503 error: \(error)") }
    }
}
