import Foundation
import Testing
@testable import kvx

struct PIRStatisticsTests {
    @Test func decodesHistoryAndSupportsOldAPI() throws {
        let values = Array(repeating: 0, count: 24)
        var payload: [String: Any] = ["date": "2026-09-15", "values": values, "total": 0]
        let old = try JSONDecoder().decode(PIRStatistics.self, from: JSONSerialization.data(withJSONObject: payload))
        #expect(old.recent_events == nil)
        payload["recent_events"] = [["id": 1, "event_type": "motion_detected", "occurred_at": "2026-09-14T18:00:00Z"]]
        let stats = try JSONDecoder().decode(PIRStatistics.self, from: JSONSerialization.data(withJSONObject: payload))
        let event = try #require(stats.recent_events?.first)
        #expect(event.id == 1)
        #expect(PIRCalendar.key(try #require(event.timestamp)) == "2026-09-15")
    }

    @Test func validatesHourlyData() throws {
        let stats = PIRStatistics(date: "2026-09-15", values: Array(repeating: 1, count: 24), total: 24)
        #expect(try stats.validated().total == 24)
        #expect(throws: (any Error).self) {
            try PIRStatistics(date: "2026-09-15", values: [1], total: 1).validated()
        }
        #expect(throws: (any Error).self) {
            try PIRStatistics(date: "2026-09-15", values: Array(repeating: 0, count: 24), total: 1).validated()
        }
    }

    @Test func heatmapThresholds() {
        #expect([0, 1, 3, 4, 8, 9, 15, 16].map { PIRDay(date: "2026-09-15", count: $0).level } == [0, 1, 1, 2, 2, 3, 3, 4])
    }

    @Test func usesVietnamDayAtUTCBoundary() throws {
        let date = try #require(ISO8601DateFormatter().date(from: "2026-09-14T18:00:00Z"))
        #expect(PIRCalendar.key(date) == "2026-09-15")
        #expect(PIRCalendar.key(try #require(PIRCalendar.date("2026-09-15"))) == "2026-09-15")
    }
}
