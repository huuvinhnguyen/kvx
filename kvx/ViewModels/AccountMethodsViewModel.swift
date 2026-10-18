import Foundation
import Observation

// Owned by the authenticated graph, not by an account screen. It contains no
// credentials, recovery codes, or response data.
@MainActor @Observable
final class AccountMethodsContinuity {
    let generation: UInt64
    private(set) var gate: ReconciliationGate
    private(set) var pendingUnlinkProvider: String?
    private(set) var needsRefresh = false
    private(set) var lostCodes = false
    private(set) var verifiedRotation: MutationLease?
    private var active = true

    init(generation: UInt64, gate: ReconciliationGate = .clean) {
        self.generation = generation
        self.gate = gate
        if gate == .pendingUnlink { pendingUnlinkProvider = "google"; needsRefresh = true }
        if gate == .pendingRotation { lostCodes = true; needsRefresh = true }
    }

    var writeBlocked: Bool { active && (gate != .clean || pendingUnlinkProvider != nil || needsRefresh || lostCodes) }
    var isActive: Bool { active }

    func applyGate(_ next: ReconciliationGate) {
        guard active else { return }
        gate = next
        if next == .pendingUnlink { pendingUnlinkProvider = "google"; needsRefresh = true }
        if next == .clean {
            pendingUnlinkProvider = nil
            needsRefresh = false
            lostCodes = false
            verifiedRotation = nil
        }
    }

    func markRotationVerified(_ lease: MutationLease) {
        guard active, gate == .pendingRotation else { return }
        verifiedRotation = lease
        needsRefresh = false
    }

    func markUnlink(_ provider: String) { if active { pendingUnlinkProvider = provider } }
    func markUnverifiedWrite() { if active { needsRefresh = true } }
    func markLostCodes() { if active { lostCodes = true; needsRefresh = true } }
    func acknowledgeLostCodes() { if active { lostCodes = false } }

    func invalidate() {
        active = false
        pendingUnlinkProvider = nil
        needsRefresh = false
        lostCodes = false
        verifiedRotation = nil
        gate = .unavailable
    }

    func reconcile(_ methods: AuthenticationMethods) -> Bool {
        guard active else { return false }
        if gate != .clean { return false }
        if let provider = pendingUnlinkProvider,
           methods.providers.contains(where: { $0.provider == provider }) {
            return false
        }
        pendingUnlinkProvider = nil
        needsRefresh = false
        return true
    }
}

nonisolated private final class MutationDispatchGate: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var dispatched = false

    func beginDispatch() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !cancelled else { return false }
        dispatched = true
        return true
    }

    func cancel() -> Bool {
        lock.lock(); defer { lock.unlock() }
        cancelled = true
        return dispatched
    }
}

@MainActor @Observable
final class AccountMethodsViewModel {
    private let repository: any AccountAuthRepository
    private let authority: any SessionAuthorizing
    private let generation: UInt64
    private let continuity: AccountMethodsContinuity
    private var operation: Task<Void, Never>?
    private var runID = 0
    private var mutationGate: MutationDispatchGate?
    private var mutationPurpose: ReauthenticationPurpose?

    var requested: ReauthenticationPurpose?
    var password = ""
    private(set) var methods: AuthenticationMethods?
    private(set) var codes: [String] = []
    private(set) var message: String?
    private(set) var busy = false
    private(set) var writeInFlight = false
    var writeBlocked: Bool { continuity.writeBlocked }
    var lostCodes: Bool { continuity.lostCodes }
    private(set) var privacySuspended = false

    init(repository: any AccountAuthRepository, authority: any SessionAuthorizing, generation: UInt64,
         continuity: AccountMethodsContinuity? = nil) {
        self.repository = repository
        self.authority = authority
        self.generation = generation
        self.continuity = continuity ?? AccountMethodsContinuity(generation: generation)
        precondition(self.continuity.generation == generation)
    }

    var canRotate: Bool { continuity.isActive && !privacySuspended && !busy && !writeBlocked && !lostCodes && codes.isEmpty && methods?.passwordUsable == true }
    var canUnlink: Bool { continuity.isActive && !privacySuspended && !busy && !writeBlocked && codes.isEmpty && methods?.canUnlinkGoogle == true }

    private func valid(_ id: Int) async -> Bool {
        guard id == runID, continuity.isActive, !privacySuspended, !Task.isCancelled else { return false }
        return await authority.isCurrent(generation)
    }

    func beginPrompt(_ purpose: ReauthenticationPurpose) {
        guard purpose == .rotateRecoveryCodes ? canRotate : canUnlink else { return }
        password = ""
        requested = purpose
    }

    func dismissPrompt() {
        password = ""
        requested = nil
    }

    func submitPrompt() {
        let entered = password
        let purpose = requested
        dismissPrompt()
        guard !entered.isEmpty else { return }
        if purpose == .unlinkIdentity { unlink(password: entered) }
        else if purpose == .rotateRecoveryCodes { rotate(password: entered) }
    }

    func suspendForPrivacy() {
        guard !privacySuspended else { return }
        privacySuspended = true
        dismissPrompt()
        let hadCodes = !codes.isEmpty
        let purpose = mutationPurpose
        let dispatched = mutationGate?.cancel() ?? false
        runID += 1
        operation?.cancel()
        operation = nil
        mutationGate = nil
        mutationPurpose = nil
        busy = false
        writeInFlight = false
        codes = []
        if dispatched || hadCodes || continuity.gate == .pendingRotation {
            if hadCodes || purpose == .rotateRecoveryCodes || continuity.gate == .pendingRotation { continuity.markLostCodes() }
            else { continuity.markUnverifiedWrite() }
            if dispatched && purpose == .unlinkIdentity {
                continuity.markUnlink("google")
            }
            message = lostCodes
                ? "Mã mới có thể đã được tạo nhưng không còn hiển thị. Mã cũ có thể đã bị hủy. Tải lại trạng thái trước khi tạo bộ khác."
                : "Kết quả gỡ Google chưa rõ. Tải lại trạng thái trước khi thao tác tiếp."
        }
    }

    func resumeForPrivacy() { privacySuspended = false }

    func refresh() {
        guard continuity.isActive, !busy, !privacySuspended else { return }
        runID += 1
        let id = runID
        busy = true
        message = nil
        operation = Task {
            do {
                _ = try await fetchAndApply(id)
            } catch {
                guard await valid(id) else { return }
                message = safeMessage(error)
            }
            if await valid(id) { busy = false; operation = nil }
        }
    }

    func rotate(password: String) { mutate(password: password, purpose: .rotateRecoveryCodes) }
    func unlink(password: String) { mutate(password: password, purpose: .unlinkIdentity) }

    private func mutate(password: String, purpose: ReauthenticationPurpose) {
        guard continuity.isActive, !password.isEmpty, !privacySuspended, !busy, !writeBlocked, !lostCodes, codes.isEmpty,
              methods?.passwordUsable == true,
              purpose != .unlinkIdentity || methods?.canUnlinkGoogle == true else { return }
        runID += 1
        let id = runID
        busy = true
        writeInFlight = true
        message = nil
        operation = Task {
            var lease: MutationLease?
            var dispatchGate: MutationDispatchGate?
            var preparationAttempted = false
            do {
                let grant = try await repository.reauthenticate(password: password, purpose: purpose)
                guard await valid(id) else { return }
                guard grant.usable(for: purpose) else { throw AccountAuthFailure.reauthenticationRequired }
                let kind: ReconciliationOperation = purpose == .unlinkIdentity ? .unlinkGoogle : .rotateRecoveryCodes
                preparationAttempted = true
                lease = try await authority.prepareMutation(kind, generation: generation)
                continuity.applyGate(.from(lease!.marker))
                guard await valid(id) else {
                    try? await authority.clearMutation(lease!, resolution: .provenNotDispatched)
                    return
                }
                let gate = MutationDispatchGate()
                dispatchGate = gate
                mutationGate = gate
                mutationPurpose = purpose
                if purpose == .rotateRecoveryCodes {
                    let issued = try await repository.rotateCodes(grant: grant, lease: lease!, beginDispatch: { gate.beginDispatch() })
                    guard await valid(id) else { return }
                    codes = issued
                } else {
                    try await repository.unlinkGoogle(grant: grant, lease: lease!, beginDispatch: { gate.beginDispatch() })
                }
                guard await valid(id) else { return }
                if purpose == .unlinkIdentity { continuity.markUnlink("google") }
                _ = try await fetchAndApply(id)
                guard await valid(id) else { return }
                message = purpose == .unlinkIdentity && !writeBlocked
                    ? "Đã cập nhật phương thức đăng nhập."
                    : purpose == .rotateRecoveryCodes
                    ? "Lưu các mã mới ngay. Chúng chỉ hiển thị một lần."
                    : message
            } catch {
                if preparationAttempted && lease == nil {
                    if await valid(id), let gate = try? await authority.reconciliationGate(generation) {
                        continuity.applyGate(gate)
                    }
                }
                if let lease, dispatchGate?.cancel() != true {
                    do {
                        try await authority.clearMutation(lease, resolution: .provenNotDispatched)
                        if continuity.isActive {
                            if await authority.isCurrent(generation) { continuity.applyGate(.clean) }
                        }
                    } catch { message = SessionFailure.storage.localizedDescription }
                }
                guard await valid(id) else { return }
                if let lease, dispatchGate?.cancel() == true {
                    if purpose == .rotateRecoveryCodes && codes.isEmpty { continuity.markLostCodes() }
                    else { continuity.markUnlink("google") }
                    do {
                        let refreshed = try await fetchAndApply(id)
                        guard await valid(id) else { return }
                        if refreshed, purpose == .unlinkIdentity,
                           (error as? AccountAuthFailure) == .lastAuthenticationMethod,
                           continuity.gate == .pendingUnlink {
                            try await authority.clearMutation(lease, resolution: .lastMethodRejected)
                            guard await valid(id) else { return }
                            continuity.applyGate(.clean)
                            message = safeMessage(error)
                        }
                    } catch {
                        if await valid(id) { message = "Chưa xác minh được trạng thái máy chủ. Tải lại phương thức trước khi tiếp tục." }
                    }
                    if await valid(id), purpose == .rotateRecoveryCodes {
                        message = codes.isEmpty
                            ? "Không nhận được mã mới. Mã cũ có thể đã bị hủy. Kiểm tra trạng thái trước khi tạo bộ khác."
                            : "Mã mới đang hiển thị; chưa tải được trạng thái máy chủ. Hãy lưu mã và tải lại trước khi xác nhận."
                    }
                } else {
                    message = safeMessage(error)
                }
            }
            if await valid(id) {
                mutationGate = nil
                mutationPurpose = nil
                busy = false
                writeInFlight = false
                operation = nil
            }
        }
    }

    private func fetchAndApply(_ id: Int) async throws -> Bool {
        if continuity.gate == .storageBlocked {
            let gate = try await authority.refreshReconciliation(generation)
            guard await valid(id) else { return false }
            continuity.applyGate(gate)
        }
        let pending = try await authority.pendingMutation(generation)
        let updated = try await repository.methods()
        guard await valid(id) else { return false }
        if let pending, pending.marker.operation == .unlinkGoogle,
           !updated.providers.contains(where: { $0.provider == "google" }) {
            try await authority.clearMutation(pending, resolution: .providerAbsent)
            guard await valid(id) else { return false }
            continuity.applyGate(.clean)
        } else if let pending, pending.marker.operation == .rotateRecoveryCodes {
            continuity.markRotationVerified(pending)
        }
        methods = updated
        if !continuity.reconcile(updated) {
            message = continuity.gate == .pendingUnlink
                ? "Binblog vẫn ghi nhận Google. Tải lại trạng thái trước khi thao tác tiếp."
                : continuity.gate == .pendingRotation
                ? "Mã có thể đã thay đổi. Xác nhận sau khi kiểm tra trạng thái trước khi tạo bộ khác."
                : "Phiên này chưa thể thay đổi phương thức. Đăng xuất bền vững rồi đăng nhập lại hoặc liên hệ hỗ trợ."
        }
        return true
    }

    var canAcknowledgeLostCodes: Bool { !privacySuspended && !busy && lostCodes && continuity.verifiedRotation != nil }

    func acknowledgeCodes() { acknowledgeRotation() }
    func acknowledgeLostCodes() { guard canAcknowledgeLostCodes else { return }; acknowledgeRotation() }

    private func acknowledgeRotation() {
        guard !privacySuspended, !busy else { return }
        codes = []
        guard let lease = continuity.verifiedRotation else {
            continuity.markLostCodes()
            message = "Tải lại trạng thái trước khi xác nhận bộ mã."
            return
        }
        runID += 1
        let id = runID
        busy = true
        operation = Task {
            do {
                try await authority.clearMutation(lease, resolution: .codesAcknowledged)
                guard await valid(id) else { return }
                continuity.applyGate(.clean)
            } catch {
                guard await valid(id) else { return }
                continuity.markLostCodes()
                message = "Chưa lưu được trạng thái xác nhận. Tải lại và thử lại; không tạo bộ mã khác lúc này."
            }
            if await valid(id) { busy = false; operation = nil }
        }
    }

    func cancel() {
        runID += 1
        let dispatched = mutationGate?.cancel() ?? false
        if !codes.isEmpty || continuity.gate == .pendingRotation || (dispatched && mutationPurpose == .rotateRecoveryCodes) {
            continuity.markLostCodes()
        } else if dispatched && mutationPurpose == .unlinkIdentity {
            continuity.markUnlink("google")
        }
        operation?.cancel()
        operation = nil
        mutationGate = nil
        mutationPurpose = nil
        dismissPrompt()
        privacySuspended = false
        busy = false
        writeInFlight = false
        methods = nil
        codes = []
        message = nil
    }

    private func safeMessage(_ error: Error) -> String {
        (error as? AccountAuthFailure)?.localizedDescription
            ?? (error as? SessionFailure)?.localizedDescription
            ?? "Không tải được phương thức đăng nhập."
    }
}
