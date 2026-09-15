import Foundation
import Combine

@MainActor
final class PIRViewModel: ObservableObject {
    @Published var selectedDate = PIRCalendar.calendar.startOfDay(for: Date())
    @Published private(set) var statistics: PIRStatistics?
    @Published private(set) var events: [PIRMotionEvent]?
    @Published private(set) var days: [PIRDay] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    private var generation = 0
    private let repository: any PIRRepository

    init(repository: any PIRRepository = PIRAPIClient()) {
        self.repository = repository
    }

    func load(chipID: String?) async {
        generation += 1
        let request = generation
        statistics = nil
        error = nil
        guard let chipID, !chipID.isEmpty else {
            error = "Thiết bị chưa có mã chip. Hãy tải lại danh sách thiết bị."
            return
        }
        isLoading = true
        defer { if generation == request { isLoading = false } }
        do {
            async let stats = repository.statistics(chipID: chipID, date: PIRCalendar.key(selectedDate))
            async let heatmap = repository.heatmap(chipID: chipID)
            let result = try await (stats, heatmap)
            guard generation == request, !Task.isCancelled else { return }
            statistics = result.0
            events = result.0.recent_events.map { Array($0.prefix(20)) }
            days = result.1
        } catch {
            guard generation == request, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}
