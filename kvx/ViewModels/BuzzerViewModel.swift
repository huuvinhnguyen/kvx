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
    private(set) var availablePIRs: [AvailableBuzzerPIR] = []
    private(set) var isLoadingAvailable = false
    private(set) var isMutating = false
    private(set) var availableError: String?
    private(set) var requiresRefresh = false
    private(set) var errorMessage: String?
    private(set) var notice: String?
    private(set) var needsLogin = false
    private(set) var cooldownUntil: Date?
    private let deviceID: String
    private let useCases: BuzzerUseCases
    private let now: () -> Date
    private var generation = 0
    private var isActive = true
    private var refreshAfterMutation = false
    private var mutationSucceededAwaitingRefresh = false

    init(deviceID: String, useCases: BuzzerUseCases, now: @escaping () -> Date = Date.init) {
        self.deviceID = deviceID
        self.useCases = useCases
        self.now = now
    }

    var isBusy: Bool { isLoading || isTesting || isMutating }

    func cooldownSeconds(at date: Date) -> Int {
        max(0, Int(ceil(cooldownUntil?.timeIntervalSince(date) ?? 0)))
    }

    func load() async {
        if isMutating { refreshAfterMutation = true; return }
        guard !isTesting else { return }
        let reconciling = requiresRefresh
        generation += 1
        let request = generation
        isLoading = true
        errorMessage = nil
        if !requiresRefresh { notice = nil }
        defer { if generation == request { isLoading = false } }
        do {
            let (detail, sources, events) = try await useCases.load(deviceID: deviceID)
            guard generation == request, !Task.isCancelled else { return }
            if requiresRefresh {
                let available = try await useCases.availablePIRs(deviceID: deviceID)
                guard generation == request, !Task.isCancelled else { return }
                availablePIRs = available
            }
            self.detail = detail
            self.sources = sources
            self.events = events
            needsLogin = false
            requiresRefresh = false
            if mutationSucceededAwaitingRefresh { notice = "Đã cập nhật cấu hình PIR. Liên kết không chạy Test Buzzer hoặc phát âm." }
            else if reconciling { notice = "Đã tải lại cấu hình PIR từ máy chủ." }
            mutationSucceededAwaitingRefresh = false
            refreshAfterMutation = false
        } catch {
            guard generation == request, !Task.isCancelled else { return }
            handle(error)
            if requiresRefresh {
                let prefix = mutationSucceededAwaitingRefresh
                    ? "Đã cập nhật cấu hình PIR nhưng chưa tải lại được dữ liệu. "
                    : "Chưa xác nhận được kết quả cập nhật cấu hình. "
                errorMessage = prefix + "Hãy tải lại trước khi chỉnh sửa tiếp. \(error.localizedDescription)"
            }
        }
    }

    func loadAvailable() async {
        guard !isMutating else { return }
        let request = generation
        isLoadingAvailable = true
        availableError = nil
        defer { if generation == request { isLoadingAvailable = false } }
        do {
            let values = try await useCases.availablePIRs(deviceID: deviceID)
            guard generation == request, !Task.isCancelled else { return }
            availablePIRs = values
        } catch {
            guard generation == request, !Task.isCancelled else { return }
            if let apiError = error as? DeviceAPIError {
                switch apiError {
                case .httpStatus(401), .missingAccessToken: handle(error)
                default: break
                }
            }
            availableError = error.localizedDescription
        }
    }

    func link(_ configuration: BuzzerLinkConfiguration) async {
        guard !isBusy, !requiresRefresh, configuration.isValid,
              availablePIRs.contains(where: { $0.id == configuration.pirID }) else { return }
        await mutate { try await useCases.link(deviceID: deviceID, configuration: configuration) }
    }

    func unlink(pirID: String) async {
        guard !isBusy, !requiresRefresh, sources.contains(where: { $0.id == pirID }) else { return }
        await mutate { try await useCases.unlink(deviceID: deviceID, pirID: pirID) }
    }

    private func mutate(_ operation: () async throws -> Void) async {
        generation += 1
        let request = generation
        isMutating = true
        errorMessage = nil
        notice = nil
        do {
            try await operation()
        } catch {
            if generation == request, !Task.isCancelled {
                if case BuzzerError.uncertainMutation = error {
                    requiresRefresh = true
                    mutationSucceededAwaitingRefresh = false
                    errorMessage = error.localizedDescription
                } else { handle(error) }
            }
            await finishMutation()
            return
        }
        guard generation == request, !Task.isCancelled else { await finishMutation(); return }
        mutationSucceededAwaitingRefresh = true
        notice = "Đã cập nhật cấu hình PIR. Đang tải lại danh sách…"
        do {
            async let loaded = useCases.load(deviceID: deviceID)
            async let available = useCases.availablePIRs(deviceID: deviceID)
            let (newDetail, newSources, newEvents) = try await loaded
            let newAvailable = try await available
            guard generation == request, !Task.isCancelled else { await finishMutation(); return }
            detail = newDetail; sources = newSources; events = newEvents; availablePIRs = newAvailable
            requiresRefresh = false
            mutationSucceededAwaitingRefresh = false
            notice = "Đã cập nhật cấu hình PIR. Liên kết không chạy Test Buzzer hoặc phát âm."
        } catch {
            guard generation == request, !Task.isCancelled else { await finishMutation(); return }
            requiresRefresh = true
            errorMessage = "Đã cập nhật cấu hình PIR nhưng chưa tải lại được dữ liệu. Hãy tải lại trước khi chỉnh sửa tiếp. \(error.localizedDescription)"
        }
        await finishMutation()
    }

    private func finishMutation() async {
        isMutating = false
        if isActive && refreshAfterMutation {
            refreshAfterMutation = false
            await load()
        }
    }

    func activate() async {
        isActive = true
        await load()
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
            cooldownUntil = now().addingTimeInterval(3)
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
        isActive = false
        if isMutating {
            requiresRefresh = true
            refreshAfterMutation = true
        }
        generation += 1
        isLoading = false
        isTesting = false
        isLoadingAvailable = false
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
