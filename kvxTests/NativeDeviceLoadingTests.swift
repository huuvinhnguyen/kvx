import Foundation
import Testing
@testable import kvx

private struct TestTokenProvider: AccessTokenProvider {
    let accessToken: String?
}

private final class NativeAPIStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let body: String
        if request.url?.path == "/api/login" {
            body = #"{"token":"test-native-token"}"#
        } else {
            body = #"{"devices":[{"id":64,"name":"PIR phòng khách","chip_id":"esp32_testpir","device_type":"pir","status":1}]}"#
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
struct NativeDeviceLoadingTests {
    private func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NativeAPIStub.self]
        return URLSession(configuration: configuration)
    }

    @Test func missingTokenShowsLoginInsteadOfSampleDevices() async {
        let source = BinblogDeviceDataSource(tokenProvider: TestTokenProvider(accessToken: nil), session: session())
        let model = DeviceViewModel(repository: RemoteDeviceRepository(dataSource: source))
        #expect(model.devices.isEmpty)
        await model.loadDevices()
        #expect(model.needsLogin)
        #expect(model.devices.isEmpty)
        #expect(!model.isLoading)
    }

    @Test func authenticatedAPIMapsAndDisplaysPIR() async throws {
        let source = BinblogDeviceDataSource(tokenProvider: TestTokenProvider(accessToken: "test-native-token"), session: session())
        let model = DeviceViewModel(repository: RemoteDeviceRepository(dataSource: source))
        await model.loadDevices()
        let device = try #require(model.filteredDevices.first)
        #expect(device.type == .pir)
        #expect(device.chipID == "esp32_testpir")
        #expect(!model.needsLogin)
        #expect(model.errorMessage == nil)
        model.toggleStatus(for: device)
        #expect(model.devices.first?.chipID == "esp32_testpir")
    }

    @Test func loginReturnsTokenForSubsequentDeviceRequests() async throws {
        let token = try await BinblogLoginClient(session: session()).login(username: "test", password: "test")
        #expect(token == "test-native-token")
    }

    @Test func expiredSessionClearsPreviousAccountDevices() async {
        struct ExpiredRepository: DeviceRepository {
            func fetchDevices() async throws -> [Device] { throw DeviceAPIError.httpStatus(401) }
        }
        let model = DeviceViewModel(repository: ExpiredRepository())
        model.devices = Device.sampleDevices
        await model.loadDevices()
        #expect(model.devices.isEmpty)
        #expect(model.needsLogin)
    }
}
