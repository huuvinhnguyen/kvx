import Foundation
import Testing
@testable import kvx

private final class NativeAPIStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    private func requestBody() -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
    override func startLoading() {
        let body: String
        var status = 200
        if request.url?.path == "/api/login" {
            let credentials = (try? JSONSerialization.jsonObject(with: requestBody())) as? [String: String]
            if request.httpMethod != "POST" || request.value(forHTTPHeaderField: "Authorization") != nil || credentials?["password"] != "test" {
                status = 400
                body = "{}"
            } else {
                switch credentials?["username"] {
                case "rejected": status = 401; body = "{}"
                case "empty": body = #"{"token":""}"#
                case "whitespace": body = #"{"token":"   "}"#
                case "missing": body = "{}"
                default: body = #"{"token":"test-native-token"}"#
                }
            }
        } else {
            body = #"{"devices":[{"id":64,"name":"PIR phòng khách","chip_id":"esp32_testpir","device_type":"pir","status":1}]}"#
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
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
        let source = BinblogDeviceDataSource(transport: AuthenticatedTransport(session: session()))
        let model = DeviceViewModel(repository: RemoteDeviceRepository(dataSource: source))
        #expect(model.devices.isEmpty)
        await model.loadDevices()
        #expect(model.needsLogin)
        #expect(model.devices.isEmpty)
        #expect(!model.isLoading)
    }

    @Test func authenticatedAPIMapsAndDisplaysPIR() async throws {
        let source = BinblogDeviceDataSource(transport: AuthenticatedTransport(authority: FixedTestSession(token: "test-native-token"), session: session()))
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

    @Test func loginRejectsCredentialsAndUnusableBackendTokens() async {
        for username in ["rejected", "empty", "whitespace", "missing"] {
            do {
                _ = try await BinblogLoginClient(session: session()).login(username: username, password: "test")
                Issue.record("Expected rejected login response")
            } catch {}
        }
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
