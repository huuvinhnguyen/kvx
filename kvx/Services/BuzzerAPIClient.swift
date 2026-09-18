import Foundation

struct BuzzerAPIClient: BuzzerRepository {
    var tokenProvider: any AccessTokenProvider = UserDefaultsAccessTokenProvider()
    var session: URLSession = .shared
    var baseURL = URL(string: "https://khuonvien.vn")!

    func detail(deviceID: String) async throws -> BuzzerDetail {
        let data = try await request(deviceID: deviceID, command: nil)
        do {
            return try JSONDecoder().decode(BuzzerDetailDTO.self, from: data).toDomain()
        } catch { throw BuzzerError.invalidResponse }
    }

    func send(_ command: BuzzerCommand, deviceID: String) async throws -> BuzzerCommandReceipt {
        let data = try await request(deviceID: deviceID, command: command)
        guard let receipt = try? JSONDecoder().decode(ReceiptDTO.self, from: data),
              receipt.status == "accepted", receipt.acknowledgement == "broker_only",
              (0...60).contains(receipt.cooldown_seconds ?? 0) else { throw BuzzerError.commandFailed }
        return BuzzerCommandReceipt(cooldownSeconds: command == .test ? max(3, receipt.cooldown_seconds ?? 3) : 0)
    }

    private func request(deviceID: String, command: BuzzerCommand?) async throws -> Data {
        guard !deviceID.isEmpty, deviceID.allSatisfy({ $0.isASCII && $0.isNumber }) else { throw BuzzerError.unavailable }
        guard let token = tokenProvider.accessToken, !token.isEmpty else { throw DeviceAPIError.missingAccessToken }
        var url = baseURL.appendingPathComponent("api/buzzers/\(deviceID)")
        if let command { url.appendPathComponent(command.rawValue) }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = command == nil ? "GET" : "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if command != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data("{}".utf8)
        }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch {
            if command != nil { throw BuzzerError.commandFailed }
            throw error
        }
        guard let response = response as? HTTPURLResponse else { throw BuzzerError.invalidResponse }
        switch response.statusCode {
        case 200: return data
        case 401: throw DeviceAPIError.httpStatus(401)
        case 403, 404: throw BuzzerError.unavailable
        case 422: throw BuzzerError.invalidConfiguration
        case 429:
            let seconds = (try? JSONDecoder().decode(CooldownDTO.self, from: data).retry_after_seconds) ?? 3
            throw BuzzerError.cooldown(min(60, max(1, seconds)))
        default:
            if command != nil { throw BuzzerError.commandFailed }
            throw DeviceAPIError.httpStatus(response.statusCode)
        }
    }
}

private struct ReceiptDTO: Decodable {
    let status: String
    let acknowledgement: String
    let cooldown_seconds: Int?
}

private struct CooldownDTO: Decodable { let retry_after_seconds: Int }

struct BuzzerDetailDTO: Decodable {
    let id: String
    let name: String
    let chip_id: String
    let online: Bool
    let last_seen: String?
    let build_version: String?
    let app_version: String?
    let test_duration_ms: Int?
    let sources: [Source]
    let events: [Event]

    struct Source: Decodable {
        let id: String
        let name: String
        let chip_id: String
        let relay_index: Int
        let duration_ms: Int?
    }
    struct Event: Decodable {
        let id: String
        let source_id: String
        let source_name: String
        let source_chip_id: String
        let occurred_at: String
        let duration_ms: Int?
    }

    func toDomain() throws -> BuzzerDetail {
        guard !id.isEmpty, !chip_id.isEmpty, events.count <= 20,
              Set(sources.map(\.id)).count == sources.count,
              Set(events.map(\.id)).count == events.count else { throw BuzzerError.invalidResponse }
        let mappedSources = try sources.map { source in
            guard !source.id.isEmpty, !source.chip_id.isEmpty, source.relay_index >= 0,
                  (source.duration_ms ?? 0) >= 0 else { throw BuzzerError.invalidResponse }
            return BuzzerSource(id: source.id, name: source.name, chipID: source.chip_id,
                                relayIndex: source.relay_index, durationMS: source.duration_ms)
        }
        let mappedEvents = try events.map { event in
            guard let date = Self.date(event.occurred_at), !event.id.isEmpty,
                  sources.contains(where: { $0.id == event.source_id && $0.chip_id == event.source_chip_id }),
                  (event.duration_ms ?? 0) >= 0 else { throw BuzzerError.invalidResponse }
            return BuzzerMotionEvent(id: event.id, sourceID: event.source_id, sourceName: event.source_name,
                                     sourceChipID: event.source_chip_id, occurredAt: date, durationMS: event.duration_ms)
        }
        return BuzzerDetail(id: id, name: name, chipID: chip_id, online: online,
                            lastSeen: last_seen.flatMap(Self.date), buildVersion: build_version,
                            appVersion: app_version, testDurationMS: test_duration_ms,
                            sources: mappedSources, events: mappedEvents)
    }

    private static func date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let result = formatter.date(from: value) { return result }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}
