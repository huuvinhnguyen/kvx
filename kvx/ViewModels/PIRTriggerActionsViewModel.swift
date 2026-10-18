import Foundation
import Observation

@MainActor
@Observable
final class PIRTriggerActionsViewModel {
    enum Phase: Equatable {
        case idle, loading, ready, legacy, invalidLegacy, mutating, reconciling, uncertain, failed, featureDisabled
    }

    private(set) var phase: Phase = .idle
    private(set) var snapshot: PIRTriggerSnapshot?
    private(set) var errorMessage: String?
    private(set) var notice: String?
    private(set) var needsLogin = false
    private let chipID: String
    private let useCases: PIRTriggerActionUseCases
    private var generation = 0
    private var mutationInFlight = false

    init(chipID: String, useCases: PIRTriggerActionUseCases) {
        self.chipID = chipID
        self.useCases = useCases
    }

    var actions: [PIRTriggerAction] { snapshot?.configuration.actions ?? [] }
    var targets: [PIRTriggerTarget] { snapshot?.targets ?? [] }
    var isBusy: Bool { [.loading, .mutating, .reconciling].contains(phase) }
    var canManagePersistedActions: Bool { phase == .ready && snapshot?.configuration.mode == .actions }
    var canAdd: Bool {
        guard phase == .ready, let mode = snapshot?.configuration.mode else { return false }
        return mode == .empty || mode == .actions
    }
    var canMigrateLegacy: Bool {
        phase == .legacy && actions.count == 1 && actions[0].origin == .legacy && actions[0].target.map { target in targets.contains(where: { $0.id == target.id }) } == true
    }
    var availableTargetsForAdd: [PIRTriggerTarget] {
        let used = Set(actions.compactMap(\.target?.id))
        return targets.filter { !used.contains($0.id) }
    }

    func load() async {
        guard !mutationInFlight else { return }
        generation += 1
        let request = generation
        phase = phase == .uncertain ? .reconciling : .loading
        errorMessage = nil
        notice = nil
        await performLoad(request: request, uncertainOnFailure: phase == .reconciling)
    }

    func create(_ draft: PIRTriggerActionDraft) async {
        guard canAdd, availableTargetsForAdd.contains(where: { $0.id == draft.targetID }), draft.isValid(using: targets) else { return }
        await mutate(successMessage: "Đã thêm hành động.") { try await self.useCases.create(chipID: self.chipID, draft: draft) }
    }

    func update(action: PIRTriggerAction, draft: PIRTriggerActionDraft) async {
        guard canManagePersistedActions, let id = action.id, draft.isValid(using: targets) else { return }
        await mutate(successMessage: "Đã cập nhật hành động.") { try await self.useCases.update(chipID: self.chipID, actionID: id, draft: draft) }
    }

    func delete(_ action: PIRTriggerAction) async {
        guard canManagePersistedActions, let id = action.id else { return }
        await mutate(successMessage: "Đã xóa hành động.") { try await self.useCases.delete(chipID: self.chipID, actionID: id) }
    }

    func reorder(fromOffsets: IndexSet, toOffset: Int) async {
        guard canManagePersistedActions else { return }
        var reordered = actions
        let moved = fromOffsets.sorted().map { reordered[$0] }
        for index in fromOffsets.sorted(by: >) { reordered.remove(at: index) }
        let insertion = toOffset - fromOffsets.filter { $0 < toOffset }.count
        reordered.insert(contentsOf: moved, at: insertion)
        let ids = reordered.compactMap(\.id)
        guard ids.count == reordered.count, Set(ids).count == ids.count, ids != actions.compactMap(\.id) else { return }
        await mutate(successMessage: "Đã cập nhật thứ tự hành động.") { try await self.useCases.reorder(chipID: self.chipID, actionIDs: ids) }
    }

    func migrateLegacy() async {
        guard canMigrateLegacy else { return }
        await mutate(successMessage: "Đã chuyển cấu hình cũ sang danh sách hành động.") { try await self.useCases.migrateLegacy(chipID: self.chipID) }
    }

    private func mutate(successMessage: String, operation: () async throws -> Void) async {
        guard !mutationInFlight, !isBusy else { return }
        mutationInFlight = true
        generation += 1
        let request = generation
        phase = .mutating
        errorMessage = nil
        notice = nil
        do {
            try await operation()
            guard generation == request else { mutationInFlight = false; return }
            await reconcile(request: request, successMessage: successMessage, uncertainOutcome: false)
        } catch let failure as PIRTriggerActionFailure {
            guard generation == request else { mutationInFlight = false; return }
            switch failure {
            case .authentication:
                needsLogin = true
                errorMessage = failure.localizedDescription
                phase = .failed
                mutationInFlight = false
            case .featureDisabled:
                errorMessage = failure.localizedDescription
                phase = .featureDisabled
                mutationInFlight = false
            case .uncertainMutation, .connection, .invalidResponse:
                phase = .uncertain
                errorMessage = PIRTriggerActionFailure.uncertainMutation.localizedDescription
                await reconcile(request: request, successMessage: "Đã tải lại trạng thái máy chủ sau kết quả chưa xác định.", uncertainOutcome: true)
            case .rejected, .unavailable:
                await reconcile(request: request, successMessage: nil, uncertainOutcome: false, preservedError: failure.localizedDescription)
            }
        } catch {
            guard generation == request else { mutationInFlight = false; return }
            phase = .uncertain
            errorMessage = PIRTriggerActionFailure.uncertainMutation.localizedDescription
            await reconcile(request: request, successMessage: "Đã tải lại trạng thái máy chủ sau kết quả chưa xác định.", uncertainOutcome: true)
        }
    }

    private func reconcile(request: Int, successMessage: String?, uncertainOutcome: Bool, preservedError: String? = nil) async {
        phase = .reconciling
        do {
            let loaded = try await useCases.load(chipID: chipID)
            guard generation == request else { mutationInFlight = false; return }
            apply(loaded)
            errorMessage = preservedError
            notice = successMessage
            needsLogin = false
        } catch let failure as PIRTriggerActionFailure {
            guard generation == request else { mutationInFlight = false; return }
            if case .authentication = failure {
                needsLogin = true
                phase = .failed
            } else if case .featureDisabled = failure {
                phase = .featureDisabled
            } else {
                phase = .uncertain
            }
            let prefix = uncertainOutcome ? "Chưa xác nhận được kết quả cập nhật. " : "Đã gửi cập nhật nhưng chưa tải lại được trạng thái. "
            errorMessage = prefix + failure.localizedDescription
        } catch {
            guard generation == request else { mutationInFlight = false; return }
            phase = .uncertain
            errorMessage = "Chưa tải lại được trạng thái máy chủ. Hãy thử Refresh trước khi chỉnh sửa tiếp."
        }
        mutationInFlight = false
    }

    private func performLoad(request: Int, uncertainOnFailure: Bool) async {
        do {
            let loaded = try await useCases.load(chipID: chipID)
            guard generation == request else { return }
            apply(loaded)
            needsLogin = false
        } catch let failure as PIRTriggerActionFailure {
            guard generation == request else { return }
            errorMessage = failure.localizedDescription
            switch failure {
            case .authentication: needsLogin = true; phase = .failed
            case .featureDisabled: phase = .featureDisabled
            default: phase = uncertainOnFailure ? .uncertain : .failed
            }
        } catch {
            guard generation == request else { return }
            errorMessage = error.localizedDescription
            phase = uncertainOnFailure ? .uncertain : .failed
        }
    }

    private func apply(_ loaded: PIRTriggerSnapshot) {
        snapshot = loaded
        switch loaded.configuration.mode {
        case .empty, .actions: phase = .ready
        case .legacy: phase = .legacy
        case .invalidLegacy: phase = .invalidLegacy
        }
    }
}
