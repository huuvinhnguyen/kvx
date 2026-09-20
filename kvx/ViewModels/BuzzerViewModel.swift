import Foundation
import Observation

@MainActor
@Observable
final class BuzzerViewModel {
    private(set) var detail: BuzzerDetail?
    private(set) var sources: [BuzzerSource] = []
    private(set) var events: [BuzzerMotionEvent] = []
    private(set) var isLoading = false
    private(set) var isTesting = false
    private(set) var errorMessage: String?
    private(set) var notice: String?
    private(set) var needsLogin = false
    private(set) var cooldownUntil: Date?
    private let deviceID: String
    private let useCases: BuzzerUseCases
    private let now: () -> Date
    private var generation = 0

    init(deviceID: String, useCases: BuzzerUseCases, now: @escaping () -> Date = Date.init) {
        self.deviceID = deviceID
        self.useCases = useCases
        self.now = now
    }

    var isBusy: Bool { isLoading || isTesting }

    func cooldownSeconds(at date: Date) -> Int {
        max(0, Int(ceil(cooldownUntil?.timeIntervalSince(date) ?? 0)))
    }

    func load() async {
        guard !isTesting else { return }
        generation += 1
        let request = generation
        isLoading = true
        errorMessage = nil
        notice = nil
        defer { if generation == request { isLoading = false } }
        do {
            let (detail, sources, events) = try await useCases.load(deviceID: deviceID)
            guard generation == request, !Task.isCancelled else { return }
            self.detail = detail
            self.sources = sources
            self.events = events
            needsLogin = false
        } catch {
            guard generation == request, !Task.isCancelled else { return }
            handle(error)
        }
    }

    func test() async {
        guard !isBusy, !needsLogin, detail != nil, cooldownSeconds(at: now()) == 0 else { return }
        generation += 1
        let request = generation
        isTesting = true
        errorMessage = nil
        notice = nil
        defer { if generation == request { isTesting = false } }
        do {
            let receipt = try await useCases.test(deviceID: deviceID)
            guard generation == request, !Task.isCancelled else { return }
            notice = receipt.message.isEmpty ? "Đã gửi lệnh đến MQTT broker; chưa có xác nhận từ Buzzer." : receipt.message
            await loadAfterTest(request: request)
        } catch {
            guard generation == request, !Task.isCancelled else { return }
            handle(error)
        }
    }

    private func loadAfterTest(request: Int) async {
        do {
            let (detail, sources, events) = try await useCases.load(deviceID: deviceID)
            guard generation == request, !Task.isCancelled else { return }
            self.detail = detail
            self.sources = sources
            self.events = events
        } catch {
            guard generation == request, !Task.isCancelled else { return }
            handle(error)
        }
    }

    func deactivate() {
        generation += 1
        isLoading = false
        isTesting = false
    }

    private func handle(_ error: Error) {
        if case BuzzerError.unavailable = error { detail = nil; sources = []; events = [] }
        if let apiError = error as? DeviceAPIError {
            switch apiError {
            case .missingAccessToken, .httpStatus(401):
                detail = nil; sources = []; events = []; notice = nil; needsLogin = true
            default: break
            }
        }
        if case BuzzerError.cooldown(let seconds) = error { cooldownUntil = now().addingTimeInterval(Double(seconds)) }
        errorMessage = error.localizedDescription
    }
}
