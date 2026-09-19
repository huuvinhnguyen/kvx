import Foundation
import Observation

@MainActor
@Observable
final class BuzzerViewModel {
    private(set) var detail: BuzzerDetail?
    private(set) var isLoading = false
    private(set) var pendingCommand: BuzzerCommand?
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

    var isBusy: Bool { isLoading || pendingCommand != nil }

    func cooldownSeconds(at date: Date) -> Int {
        max(0, Int(ceil(cooldownUntil?.timeIntervalSince(date) ?? 0)))
    }

    func load() async {
        guard pendingCommand == nil else { return }
        generation += 1
        let request = generation
        isLoading = true
        errorMessage = nil
        notice = nil
        defer { if generation == request { isLoading = false } }
        do {
            let result = try await useCases.load(deviceID: deviceID)
            guard generation == request, !Task.isCancelled else { return }
            detail = result
            needsLogin = false
        } catch {
            guard generation == request, !Task.isCancelled else { return }
            handle(error)
        }
    }

    func send(_ command: BuzzerCommand) async {
        guard !isBusy, !needsLogin, let detail else { return }
        if command == .test && cooldownSeconds(at: now()) > 0 { return }
        generation += 1
        let request = generation
        pendingCommand = command
        errorMessage = nil
        notice = nil
        defer { if generation == request { pendingCommand = nil } }
        do {
            let receipt = try await useCases.execute(command, detail: detail)
            guard generation == request, !Task.isCancelled else { return }
            if command == .test { cooldownUntil = now().addingTimeInterval(Double(receipt.cooldownSeconds)) }
            notice = "Đã gửi lệnh đến MQTT broker; chưa có xác nhận từ Buzzer."
            // Re-read only. Never replay a mutation when this GET fails.
            do {
                let updated = try await useCases.load(deviceID: deviceID)
                guard generation == request, !Task.isCancelled else { return }
                self.detail = updated
            } catch {
                guard generation == request, !Task.isCancelled else { return }
                handle(error)
            }
        } catch {
            guard generation == request, !Task.isCancelled else { return }
            handle(error)
        }
    }

    func deactivate() {
        generation += 1
        isLoading = false
        pendingCommand = nil
    }

    private func handle(_ error: Error) {
        if case BuzzerError.unavailable = error { detail = nil }
        if let apiError = error as? DeviceAPIError {
            switch apiError {
            case .missingAccessToken, .httpStatus(401):
                detail = nil
                notice = nil
                needsLogin = true
            default: break
            }
        }
        if case BuzzerError.cooldown(let seconds) = error {
            cooldownUntil = now().addingTimeInterval(Double(seconds))
        }
        errorMessage = error.localizedDescription
    }
}
