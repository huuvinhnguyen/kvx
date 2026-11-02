import Foundation

nonisolated struct SwitchAPIClient: SwitchRepository {
    var transport = AuthenticatedTransport()
    var baseURL = URL(string: "https://khuonvien.vn")!
    static func validID(_ value: String) -> Bool {
        value.range(of: "^[1-9][0-9]{0,18}$", options: .regularExpression) != nil && Int64(value) != nil
    }
    private func path(_ id: String, relay: Int? = nil, suffix: String = "") throws -> String {
        guard Self.validID(id), relay.map({ (0...31).contains($0) }) ?? true else { throw SwitchFailure.validation }
        return "api/switches/\(id)" + (relay.map { "/relays/\($0)" } ?? "") + suffix
    }
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; return decoder
    }
    func detail(deviceID: String) async throws -> SwitchDetail {
        let data = try await request(path(deviceID))
        return try Self.decodeDetail(data)
    }
    static func decodeDetail(_ data: Data) throws -> SwitchDetail {
        do {
            let response = try decoder.decode(DetailDTO.self, from: data)
            let d = response.switchDetail
            guard response.status == "success", validID(d.id), d.deviceType == "switch",
                  d.timezone == "Asia/Ho_Chi_Minh", d.online == nil,
                  d.stateSource == "server_snapshot", !d.physicalStateVerified,
                  d.limits.durationMinMs == 1000, d.limits.durationMaxMs == 86400000,
                  d.relays.count <= 32,
                  d.relays.enumerated().allSatisfy({ i, r in r.index == i && (r.switchValue == nil || r.switchValue == 0 || r.switchValue == 1) }) else { throw SwitchFailure.invalidData }
            if let seen = d.lastSeen, SwitchTimestamp.date(seen) == nil { throw SwitchFailure.invalidData }
            // Codable optional fields accept missing keys: check nullable contract keys separately.
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let raw = root?["switch"] as? [String: Any], raw.keys.contains("last_seen"), raw.keys.contains("online"),
                  let relays = raw["relays"] as? [[String: Any]],
                  relays.allSatisfy({ $0.keys.contains("switch_value") && $0.keys.contains("duration_ms") && $0.keys.contains("reminders_active") }) else { throw SwitchFailure.invalidData }
            return d
        } catch { throw SwitchFailure.invalidData }
    }
    func reminders(deviceID: String, relay: Int, afterID: String?) async throws -> SwitchReminderPage {
        var query = [URLQueryItem(name: "limit", value: "100")]
        if let afterID {
            guard Self.validID(afterID) else { throw SwitchFailure.validation }
            query.append(URLQueryItem(name: "after_id", value: afterID))
        }
        let data = try await request(path(deviceID, relay: relay, suffix: "/reminders"), query: query)
        return try Self.decodeReminders(data, deviceID: deviceID, relay: relay, afterID: afterID)
    }
    static func decodeReminders(_ data: Data, deviceID: String, relay: Int, afterID: String?) throws -> SwitchReminderPage {
        do {
            let p = try decoder.decode(SwitchReminderPage.self, from: data)
            let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard p.status == "success", p.reminders.count <= 100, raw?.keys.contains("next_after_id") == true,
                  let rows = raw?["reminders"] as? [[String: Any]], rows.allSatisfy({ $0.keys.contains("duration_ms") && $0.keys.contains("start_time") }) else { throw SwitchFailure.invalidData }
            var previous = Int64(afterID ?? "0") ?? 0
            for row in p.reminders {
                guard validID(row.id), let id = Int64(row.id), id > previous,
                      row.deviceId == deviceID, row.relayIndex == relay else { throw SwitchFailure.invalidData }
                previous = id
            }
            if let next = p.nextAfterId, next != p.reminders.last?.id || !validID(next) { throw SwitchFailure.invalidData }
            return p
        } catch { throw SwitchFailure.invalidData }
    }
    func statistics(deviceID: String, relay: Int) async throws -> SwitchStatistics {
        let data = try await request(path(deviceID, relay: relay, suffix: "/statistics"))
        return try Self.decodeStatistics(data)
    }
    static func decodeStatistics(_ data: Data) throws -> SwitchStatistics {
        do {
            let s = try decoder.decode(SwitchStatistics.self, from: data)
            let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard s.status == "success", s.timezone == "Asia/Ho_Chi_Minh", s.metric == "log_records",
                  s.physicalRuntimeSeconds == nil, !s.physicalRuntimeVerified, raw?.keys.contains("physical_runtime_seconds") == true,
                  s.totalRecords >= 0, (1...31).contains(s.days.count), s.days.first?.date == s.from, s.days.last?.date == s.to else { throw SwitchFailure.invalidData }
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 7 * 3600); formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
            guard let first = formatter.date(from: s.from), formatter.string(from: first) == s.from else { throw SwitchFailure.invalidData }
            var sum = 0
            for (i, day) in s.days.enumerated() {
                guard formatter.string(from: first.addingTimeInterval(Double(i) * 86400)) == day.date, day.count >= 0 else { throw SwitchFailure.invalidData }
                let added = sum.addingReportingOverflow(day.count); guard !added.overflow else { throw SwitchFailure.invalidData }; sum = added.partialValue
            }
            guard sum == s.totalRecords else { throw SwitchFailure.invalidData }
            return s
        } catch { throw SwitchFailure.invalidData }
    }
    func state(deviceID: String, relay: Int, value: Int) async throws {
        guard value == 0 || value == 1 else { throw SwitchFailure.validation }
        try await command(path(deviceID, relay: relay, suffix: "/state"), body: ["switch_value": value])
    }
    func pulse(deviceID: String, relay: Int, durationMS: Int) async throws {
        guard (1000...86400000).contains(durationMS), durationMS % 1000 == 0 else { throw SwitchFailure.validation }
        try await command(path(deviceID, relay: relay, suffix: "/pulse"), body: ["duration_ms": durationMS])
    }
    func refresh(deviceID: String) async throws { try await command(path(deviceID, suffix: "/refresh")) }
    private func command(_ path: String, body: [String: Int]? = nil) async throws {
        let data = try await request(path, method: "POST", body: body)
        do {
            let r = try Self.decoder.decode(CommandDTO.self, from: data)
            guard r.status == "accepted", r.outcome == "publish_returned", r.acknowledgement == "none",
                  !r.requestId.isEmpty, Self.validID(r.eventId) else { throw SwitchFailure.uncertain }
        } catch { throw SwitchFailure.uncertain }
    }
    private func request(_ path: String, method: String = "GET", body: [String: Int]? = nil, query: [URLQueryItem] = []) async throws -> Data {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!, timeoutInterval: 20)
        request.httpMethod = method; request.setValue("application/json", forHTTPHeaderField: "Accept")
        if method == "POST" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        }
        let data: Data; let response: HTTPURLResponse
        do { (data, response) = try await transport.data(for: request) }
        catch let e as SessionFailure { throw e }
        catch { throw method == "GET" ? SwitchFailure.connection : SwitchFailure.uncertain }
        switch response.statusCode {
        case 200: return data
        case 401: throw SwitchFailure.authentication
        case 403, 404: throw SwitchFailure.unavailable
        case 400, 406, 413, 415, 422: throw SwitchFailure.validation
        case 503:
            let code = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["code"] as? String
            if code == "feature_unavailable" || code == "command_unavailable" { throw SwitchFailure.unavailable }
            fallthrough
        default: throw method == "GET" ? SwitchFailure.connection : SwitchFailure.uncertain
        }
    }

}

nonisolated private struct DetailDTO: Decodable {
    let status: String; let switchDetail: SwitchDetail
    enum CodingKeys: String, CodingKey { case status; case switchDetail = "switch" }
}
nonisolated private struct CommandDTO: Decodable {
    let status: String; let outcome: String; let acknowledgement: String; let requestId: String; let eventId: String
}
