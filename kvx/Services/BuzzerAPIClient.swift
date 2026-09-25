import Foundation

struct BuzzerAPIClient: BuzzerRepository {
    var tokenProvider: any AccessTokenProvider = UserDefaultsAccessTokenProvider()
    var session: URLSession = .shared
    var baseURL = URL(string: "https://khuonvien.vn")!

    func detail(deviceID: String) async throws -> BuzzerDetail {
        let body = try await get(deviceID: deviceID, suffix: "")
        do {
            return try BuzzerDetailDTO.fromDetail(body).toDomain()
        } catch { throw BuzzerError.invalidResponse }
    }

    func linkedPIRs(deviceID: String) async throws -> [BuzzerSource] {
        let body = try await get(deviceID: deviceID, suffix: "/linked_pirs")
        do { return try BuzzerLinkedPIRDTO.from(body).map { try $0.toDomain() } }
        catch { throw BuzzerError.invalidResponse }
    }

    func availablePIRs(deviceID: String) async throws -> [AvailableBuzzerPIR] {
        let data = try await get(deviceID: deviceID, suffix: "/available_pirs")
        do {
            let result = try JSONDecoder().decode(AvailablePIRResponseDTO.self, from: data)
            guard result.status == "success" else { throw BuzzerError.invalidResponse }
            return result.available_pirs.map { $0.domain }
        } catch { throw BuzzerError.invalidResponse }
    }

    func link(deviceID: String, configuration: BuzzerLinkConfiguration) async throws {
        guard configuration.isValid else { throw BuzzerError.invalidConfiguration }
        let body = try JSONEncoder().encode(LinkRequestDTO(pir_id: Int(configuration.pirID)!, relay_index: configuration.relayIndex, longlast: configuration.longlast))
        let data = try await request(deviceID: deviceID, suffix: "/linked_pirs", method: "POST", body: body)
        do {
            let response = try JSONDecoder().decode(LinkResponseDTO.self, from: data)
            guard response.status == "success", response.linked_pir.id == Int(configuration.pirID),
                  response.linked_pir.relay_index == configuration.relayIndex,
                  response.linked_pir.longlast == configuration.longlast else { throw BuzzerError.uncertainMutation }
        } catch { throw BuzzerError.uncertainMutation }
    }

    func unlink(deviceID: String, pirID: String) async throws {
        guard let id = Int(pirID), id > 0 else { throw BuzzerError.invalidConfiguration }
        let data = try await request(deviceID: deviceID, suffix: "/linked_pirs/\(id)", method: "DELETE")
        do {
            let response = try JSONDecoder().decode(UnlinkResponseDTO.self, from: data)
            guard response.status == "success", response.pir_id == id else { throw BuzzerError.uncertainMutation }
        } catch { throw BuzzerError.uncertainMutation }
    }

    func history(deviceID: String) async throws -> [BuzzerMotionEvent] {
        let body = try await get(deviceID: deviceID, suffix: "/history")
        do { return try BuzzerHistoryEventDTO.from(body).map { try $0.toDomain() } }
        catch { throw BuzzerError.invalidResponse }
    }

    func test(deviceID: String) async throws -> BuzzerTestReceipt {
        let data = try await request(deviceID: deviceID, suffix: "/test", method: "POST")
        do {
            let wrapper = try JSONDecoder().decode(BuzzerTestResponseDTO.self, from: data)
            guard wrapper.status == "success" else { throw BuzzerError.commandFailed }
            return BuzzerTestReceipt(message: wrapper.message, relayIndex: wrapper.relay_index, longlast: wrapper.longlast)
        } catch let error as BuzzerError { throw error }
        catch { throw BuzzerError.commandFailed }
    }

    private func get(deviceID: String, suffix: String) async throws -> Data {
        try await request(deviceID: deviceID, suffix: suffix, method: "GET")
    }

    private func request(deviceID: String, suffix: String, method: String, body: Data? = nil) async throws -> Data {
        guard !deviceID.isEmpty else { throw BuzzerError.unavailable }
        guard let token = tokenProvider.accessToken, !token.isEmpty else { throw DeviceAPIError.missingAccessToken }
        let url = baseURL.appendingPathComponent("api/devices/\(deviceID)/buzzer\(suffix)")
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if method == "POST" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch {
            if method == "POST" && suffix == "/test" { throw BuzzerError.commandFailed }
            if suffix.hasPrefix("/linked_pirs") && method != "GET" { throw BuzzerError.uncertainMutation }
            throw error
        }
        guard let response = response as? HTTPURLResponse else {
            if suffix.hasPrefix("/linked_pirs") && method != "GET" { throw BuzzerError.uncertainMutation }
            throw BuzzerError.invalidResponse
        }
        switch response.statusCode {
        case 200: return data
        case 401: throw DeviceAPIError.httpStatus(401)
        case 404: throw BuzzerError.unavailable
        case 422: throw BuzzerError.invalidConfiguration
        case 429 where suffix == "/test":
            let header = response.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            let seconds = header ?? (try? JSONDecoder().decode(ErrorResponseDTO.self, from: data).retry_after_seconds) ?? 3
            throw BuzzerError.cooldown(min(60, max(1, seconds)))
        case 503 where suffix == "/test": throw BuzzerError.commandFailed
        default:
            if suffix.hasPrefix("/linked_pirs") && method != "GET" { throw BuzzerError.uncertainMutation }
            throw DeviceAPIError.httpStatus(response.statusCode)
        }
    }
}

private struct ErrorResponseDTO: Decodable { let retry_after_seconds: Int? }

struct BuzzerDetailDTO: Decodable {
    let status: String
    let buzzer: Buzzer
    struct Buzzer: Decodable {
        let id: Int
        let name: String
        let chip_id: String
        let device_type: String
        let online: Bool
        let last_seen: String?
        let linked_pir_count: Int
        let last_triggered_at: String?
    }
    static func fromDetail(_ data: Data) throws -> BuzzerDetailDTO { try JSONDecoder().decode(Self.self, from: data) }
    func toDomain() throws -> BuzzerDetail {
        guard status == "success", device_typeValid else { throw BuzzerError.invalidResponse }
        let lastSeen = try Self.date(buzzer.last_seen)
        let lastTriggeredAt = try Self.date(buzzer.last_triggered_at)
        return BuzzerDetail(id: String(buzzer.id), name: buzzer.name, chipID: buzzer.chip_id,
                            online: buzzer.online, lastSeen: lastSeen,
                            linkedPIRCount: buzzer.linked_pir_count,
                            lastTriggeredAt: lastTriggeredAt, sources: [], events: [])
    }
    private var device_typeValid: Bool { buzzer.device_type == "buzzer" && buzzer.linked_pir_count >= 0 }
    static func date(_ value: String?) throws -> Date? {
        guard let value else { return nil }
        guard let date = ISO8601DateFormatter().date(from: value) else { throw BuzzerError.invalidResponse }
        return date
    }
}

private struct BuzzerLinkedPIRResponseDTO: Decodable { let status: String; let linked_pirs: [BuzzerLinkedPIRDTO] }
struct BuzzerLinkedPIRDTO: Decodable {
    let id: Int; let name: String?; let chip_id: String; let relay_index: StoredBuzzerScalar?; let longlast: StoredBuzzerScalar?
    static func from(_ data: Data) throws -> [Self] { let wrapper = try JSONDecoder().decode(BuzzerLinkedPIRResponseDTO.self, from: data); guard wrapper.status == "success" else { throw BuzzerError.invalidResponse }; return wrapper.linked_pirs }
    func toDomain() throws -> BuzzerSource { BuzzerSource(id: String(id), name: name ?? chip_id, chipID: chip_id, relayIndex: relay_index?.integer, longlast: longlast?.integer, relayDisplay: relay_index?.display, longlastDisplay: longlast?.display) }
}

private struct BuzzerHistoryResponseDTO: Decodable { let status: String; let events: [BuzzerHistoryEventDTO] }
struct BuzzerHistoryEventDTO: Decodable {
    let id: Int; let event_type: String; let occurred_at: String; let pir: PIRDTO; let relay_index: StoredBuzzerScalar?; let longlast: StoredBuzzerScalar?
    struct PIRDTO: Decodable { let id: Int; let name: String?; let chip_id: String }
    static func from(_ data: Data) throws -> [Self] { let wrapper = try JSONDecoder().decode(BuzzerHistoryResponseDTO.self, from: data); guard wrapper.status == "success", wrapper.events.count <= 20 else { throw BuzzerError.invalidResponse }; return wrapper.events }
    func toDomain() throws -> BuzzerMotionEvent { guard event_type == "motion_detected", let date = ISO8601DateFormatter().date(from: occurred_at) else { throw BuzzerError.invalidResponse }; return BuzzerMotionEvent(id: String(id), eventType: event_type, pirID: String(pir.id), sourceName: pir.name ?? pir.chip_id, sourceChipID: pir.chip_id, occurredAt: date, relayIndex: relay_index?.integer, longlast: longlast?.integer, relayDisplay: relay_index?.display, longlastDisplay: longlast?.display) }
}

private struct BuzzerTestResponseDTO: Decodable { let status: String; let message: String; let relay_index: Int?; let longlast: Int? }

private struct LinkRequestDTO: Encodable { let pir_id: Int; let relay_index: Int; let longlast: Int }
private struct LinkResponseDTO: Decodable {
    let status: String
    let linked_pir: PIR
    struct PIR: Decodable { let id: Int; let name: String?; let chip_id: String; let relay_index: Int; let longlast: Int }
}
private struct UnlinkResponseDTO: Decodable { let status: String; let pir_id: Int }

struct StoredBuzzerScalar: Decodable {
    let display: String?
    var integer: Int? { display.flatMap(Int.init) }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if let number = try? value.decode(Int.self) { display = String(number) }
        else if let number = try? value.decode(Double.self) { display = String(number) }
        else if let text = try? value.decode(String.self) { display = text }
        else { display = nil }
    }
}
struct AvailablePIRResponseDTO: Decodable {
    let status: String
    let available_pirs: [PIR]
    struct PIR: Decodable {
        let id: Int
        let name: String?
        let chip_id: String
        let linked_buzzer: Buzzer?
        let requires_confirmation: Bool
        struct Buzzer: Decodable { let id: Int; let name: String? }
        var domain: AvailableBuzzerPIR {
            AvailableBuzzerPIR(id: String(id), name: name, chipID: chip_id,
                               linkedBuzzer: linked_buzzer.map { LinkedBuzzer(id: String($0.id), name: $0.name) },
                               requiresConfirmation: requires_confirmation)
        }
    }
}
