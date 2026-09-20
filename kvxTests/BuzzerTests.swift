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
    var tests = 0
    var loads = 0

    func detail(deviceID: String) async throws -> BuzzerDetail { loads += 1; if let loadError { throw loadError }; return detailValue }
    func linkedPIRs(deviceID: String) async throws -> [BuzzerSource] { if let loadError { throw loadError }; return sourcesValue }
    func history(deviceID: String) async throws -> [BuzzerMotionEvent] { if let loadError { throw loadError }; return eventsValue }
    func test(deviceID: String) async throws -> BuzzerTestReceipt { tests += 1; if let testError { throw testError }; return BuzzerTestReceipt(message: "Command sent to MQTT broker", relayIndex: 0, longlast: 1000) }
}

@MainActor
struct BuzzerTests {
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
    override func startLoading() {
        let path = request.url?.path ?? ""
        let valid = request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-token"
        let body: String
        switch path {
        case "/api/devices/42/buzzer":
            body = #"{"status":"success","buzzer":{"id":42,"name":"Hall Buzzer","chip_id":"ESP32_BUZZER_02","device_type":"buzzer","online":true,"last_seen":null,"linked_pir_count":1,"last_triggered_at":null}}"#
        case "/api/devices/42/buzzer/linked_pirs":
            body = #"{"status":"success","linked_pirs":[{"id":7,"name":"Hall PIR","chip_id":"ESP32_PIR_01","relay_index":0,"longlast":1000}]}"#
        case "/api/devices/42/buzzer/history":
            body = #"{"status":"success","events":[{"id":123,"event_type":"motion_detected","occurred_at":"2026-09-19T10:29:00+07:00","pir":{"id":7,"name":"Hall PIR","chip_id":"ESP32_PIR_01"},"relay_index":0,"longlast":1000}]}"#
        case "/api/devices/42/buzzer/test":
            body = #"{"status":"success","message":"Command sent to MQTT broker","relay_index":0,"longlast":1000}"#
        default: body = #"{"status":"error"}"#
        }
        let status = valid && path.contains("/api/devices/42/buzzer") ? 200 : 401
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
struct BuzzerHTTPTests {
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
}
