import Foundation

struct BinblogDeviceDataSource {
    private let baseURL = URL(string: "https://khuonvien.vn")!
    private let session: URLSession
    private let tokenProvider: AccessTokenProvider

    init(tokenProvider: AccessTokenProvider = UserDefaultsAccessTokenProvider(), session: URLSession = .shared) {
        self.session = session
        self.tokenProvider = tokenProvider
    }

    func fetchDevices() async throws -> [Device] {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/devices"))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let accessToken = tokenProvider.accessToken, !accessToken.isEmpty else {
            throw DeviceAPIError.missingAccessToken
        }
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeviceAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw DeviceAPIError.httpStatus(httpResponse.statusCode)
        }

        let payload = try JSONDecoder().decode(DeviceListResponse.self, from: data)
        return payload.devices.map(DeviceMapper.map)
    }
}

private struct DeviceListResponse: Decodable {
    let devices: [APIDevice]
}

private struct APIDevice: Decodable {
    let id: Int
    let chipID: String?
    let name: String
    let deviceType: String?
    let status: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case chipID = "chip_id"
        case deviceType = "device_type"
        case status
    }
}

private enum DeviceMapper {
    static func map(_ apiDevice: APIDevice) -> Device {
        let normalizedType = apiDevice.deviceType?.lowercased() ?? ""
        let type: Device.DeviceType
        if normalizedType == "buzzer" {
            type = .buzzer
        } else if normalizedType == "pir" {
            type = .pir
        } else if normalizedType.contains("ipad") {
            type = .iPad
        } else if normalizedType.contains("simulator") {
            type = .simulator
        } else if normalizedType.contains("temperature") || normalizedType.contains("sensor") || normalizedType.contains("dht") {
            type = .temperature
        } else if normalizedType.contains("switch") {
            type = .switch
        } else {
            type = .iPhone
        }

        let deviceStatus: Device.DeviceStatus
        switch apiDevice.status {
        case 1:
            deviceStatus = .online
        case 2:
            deviceStatus = .busy
        default:
            deviceStatus = .offline
        }

        return Device(id: String(apiDevice.id), name: apiDevice.name, chipID: apiDevice.chipID, type: type, status: deviceStatus)
    }
}

enum DeviceAPIError: LocalizedError {
    case missingAccessToken
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            return "Chưa có access token. Hãy đăng nhập Binblog trước."
        case .invalidResponse:
            return "Phản hồi từ Binblog không hợp lệ."
        case .httpStatus(401):
            return "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại Binblog."
        case .httpStatus(let statusCode):
            return "Binblog trả về lỗi HTTP \(statusCode)."
        }
    }
}
