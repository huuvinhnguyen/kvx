import Foundation

nonisolated struct PIRAPIClient: PIRRepository {
    var transport = AuthenticatedTransport()
    var baseURL = URL(string: "https://khuonvien.vn")!

    func statistics(chipID: String, date: String) async throws -> PIRStatistics {
        let stats: PIRStatistics = try await get("motion_stats", query: ["chip_id": chipID, "date": date])
        guard stats.date == date else { throw DeviceAPIError.invalidResponse }
        return try stats.validated()
    }

    func heatmap(chipID: String) async throws -> [PIRDay] {
        let heatmap: PIRHeatmap = try await get("motion_heatmap", query: ["chip_id": chipID, "days": "30"])
        guard heatmap.data.allSatisfy({ $0.count >= 0 && PIRCalendar.date($0.date) != nil }),
              Set(heatmap.data.map(\.date)).count == heatmap.data.count else {
            throw DeviceAPIError.invalidResponse
        }
        return heatmap.data
    }

    private func get<T: Decodable>(_ endpoint: String, query: [String: String]) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/devices/\(endpoint)"), resolvingAgainstBaseURL: false)!
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: components.url!, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await transport.data(for: request)
        guard response.statusCode == 200 else { throw DeviceAPIError.httpStatus(response.statusCode) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
