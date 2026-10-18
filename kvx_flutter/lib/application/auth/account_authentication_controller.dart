import 'package:flutter/foundation.dart';
import '../../domain/auth/account_authentication.dart';
import '../../domain/auth/session.dart';

class _MutationDispatchGate {
  bool _cancelled = false;
  bool _dispatched = false;

  bool beginDispatch() {
    if (_cancelled) return false;
    _dispatched = true;
    return true;
  }

  bool cancel() {
    _cancelled = true;
    return _dispatched;
  }
}

// One instance belongs to one authenticated graph. It holds only nonsecret
// reconciliation state and survives account screen navigation.
class AccountMethodsContinuity {
  final int generation;
  ReconciliationGate gate;
  AccountMethodsContinuity(
    this.generation, {
    this.gate = ReconciliationGate.clean,
  }) {
    if (gate == ReconciliationGate.pendingUnlink) {
      _pendingUnlinkGoogle = true;
      _needsRefresh = true;
    }
    if (gate == ReconciliationGate.pendingRotation) {
      _lostCodes = true;
      _needsRefresh = true;
    }
  }

  bool _pendingUnlinkGoogle = false;
  bool _needsRefresh = false;
  bool _lostCodes = false;
  MutationLease? verifiedRotation;
  bool _active = true;

  bool get writeBlocked =>
      _active &&
      (gate != ReconciliationGate.clean ||
          _pendingUnlinkGoogle ||
          _needsRefresh ||
          _lostCodes);
  bool get lostCodes => _lostCodes;
  bool get isActive => _active;

  void applyGate(ReconciliationGate next) {
    if (!_active) return;
    gate = next;
    if (next == ReconciliationGate.pendingUnlink) {
      _pendingUnlinkGoogle = true;
      _needsRefresh = true;
    }
    if (next == ReconciliationGate.clean) {
      _pendingUnlinkGoogle = false;
      _needsRefresh = false;
      _lostCodes = false;
      verifiedRotation = null;
    }
  }

  void markRotationVerified(MutationLease lease) {
    if (!_active || gate != ReconciliationGate.pendingRotation) return;
    verifiedRotation = lease;
    _needsRefresh = false;
  }

  void markUnlink() {
    if (_active) _pendingUnlinkGoogle = true;
  }

  void markUnverifiedWrite() {
    if (_active) _needsRefresh = true;
  }

  void markLostCodes() {
    if (!_active) return;
    _lostCodes = true;
    _needsRefresh = true;
  }

  void acknowledgeLostCodes() {
    if (_active) _lostCodes = false;
  }

  void invalidate() {
    _active = false;
    _pendingUnlinkGoogle = false;
    _needsRefresh = false;
    _lostCodes = false;
    verifiedRotation = null;
    gate = ReconciliationGate.unavailable;
  }

  bool reconcile(AuthenticationMethods methods) {
    if (!_active) return false;
    if (gate != ReconciliationGate.clean) return false;
    if (_pendingUnlinkGoogle && methods.google != null) return false;
    _pendingUnlinkGoogle = false;
    _needsRefresh = false;
    return true;
  }
}

class AccountAuthenticationController extends ChangeNotifier {
  final AccountAuthRepository repository;
  final SessionAccess authority;
  final int generation;
  final AccountMethodsContinuity continuity;
  AuthenticationMethods? methods;
  List<String> codes = const [];
  String? message;
  bool busy = false;
  bool writeInFlight = false;
  bool get writeBlocked => continuity.writeBlocked;
  bool get lostCodes => continuity.lostCodes;
  bool privacySuspended = false;
  bool _disposed = false;
  int _revision = 0;
  _MutationDispatchGate? _mutationGate;
  ReauthenticationPurpose? _mutationPurpose;
  ReconciliationAccess get journal => authority as ReconciliationAccess;

  AccountAuthenticationController({
    required this.repository,
    required this.authority,
    required this.generation,
    AccountMethodsContinuity? continuity,
  }) : continuity = continuity ?? AccountMethodsContinuity(generation) {
    assert(this.continuity.generation == generation);
  }

  bool get current =>
      !_disposed && continuity.isActive && authority.isCurrent(generation);
  bool get canRotate =>
      current &&
      !privacySuspended &&
      !busy &&
      !writeBlocked &&
      !lostCodes &&
      codes.isEmpty &&
      methods?.passwordUsable == true;
  bool get canUnlink =>
      current &&
      !privacySuspended &&
      !busy &&
      !writeBlocked &&
      codes.isEmpty &&
      methods?.canUnlinkGoogle == true;

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  bool _valid(int revision) =>
      current && !privacySuspended && revision == _revision;

  void suspendForPrivacy() {
    if (_disposed || privacySuspended) return;
    privacySuspended = true;
    final hadCodes = codes.isNotEmpty;
    final purpose = _mutationPurpose;
    final dispatched = _mutationGate?.cancel() ?? false;
    _revision++;
    repository.cancel();
    _mutationGate = null;
    _mutationPurpose = null;
    busy = false;
    writeInFlight = false;
    codes = const [];
    if (dispatched ||
        hadCodes ||
        continuity.gate == ReconciliationGate.pendingRotation) {
      if (hadCodes ||
          purpose == ReauthenticationPurpose.rotateRecoveryCodes ||
          continuity.gate == ReconciliationGate.pendingRotation) {
        continuity.markLostCodes();
      } else {
        continuity.markUnverifiedWrite();
      }
      if (dispatched && purpose == ReauthenticationPurpose.unlinkIdentity) {
        continuity.markUnlink();
      }
      message = lostCodes
          ? 'Mã mới có thể đã được tạo nhưng không còn hiển thị. Mã cũ có thể đã bị hủy. Tải lại trạng thái trước khi tạo bộ khác.'
          : 'Kết quả gỡ Google chưa rõ. Tải lại trạng thái trước khi thao tác tiếp.';
    }
    _publish();
  }

  void resumeForPrivacy() {
    if (_disposed || !privacySuspended) return;
    privacySuspended = false;
    _publish();
  }

  Future<void> refresh() async {
    if (busy || !current || privacySuspended) return;
    final revision = ++_revision;
    busy = true;
    message = null;
    _publish();
    try {
      await _fetchAndApply(revision);
    } catch (error) {
      if (!_valid(revision)) return;
      message = _message(error);
    } finally {
      if (_valid(revision)) {
        busy = false;
        _publish();
      }
    }
  }

  Future<void> rotate(String password) =>
      _mutate(password, ReauthenticationPurpose.rotateRecoveryCodes);
  Future<void> unlink(String password) =>
      _mutate(password, ReauthenticationPurpose.unlinkIdentity);

  Future<void> _mutate(String password, ReauthenticationPurpose purpose) async {
    if (busy ||
        !current ||
        privacySuspended ||
        writeBlocked ||
        codes.isNotEmpty ||
        lostCodes ||
        methods?.passwordUsable != true ||
        (purpose == ReauthenticationPurpose.unlinkIdentity &&
            methods?.canUnlinkGoogle != true) ||
        password.isEmpty) {
      return;
    }
    final revision = ++_revision;
    busy = true;
    writeInFlight = true;
    message = null;
    _publish();
    MutationLease? lease;
    _MutationDispatchGate? dispatchGate;
    var preparationAttempted = false;
    try {
      final grant = await repository.reauthenticate(password, purpose);
      if (!_valid(revision)) return;
      if (!grant.usableFor(purpose, DateTime.now())) {
        throw const AccountAuthFailure(
          AccountAuthFailureKind.reauthenticationRequired,
        );
      }
      preparationAttempted = true;
      lease = await journal.prepareMutation(
        purpose == ReauthenticationPurpose.unlinkIdentity
            ? ReconciliationOperation.unlinkGoogle
            : ReconciliationOperation.rotateRecoveryCodes,
        generation,
      );
      continuity.applyGate(
        purpose == ReauthenticationPurpose.unlinkIdentity
            ? ReconciliationGate.pendingUnlink
            : ReconciliationGate.pendingRotation,
      );
      if (!_valid(revision)) {
        try {
          await journal.clearMutation(
            lease,
            MarkerResolution.provenNotDispatched,
          );
        } catch (_) {}
        return;
      }
      final gate = _MutationDispatchGate();
      dispatchGate = gate;
      _mutationGate = gate;
      _mutationPurpose = purpose;
      if (purpose == ReauthenticationPurpose.rotateRecoveryCodes) {
        final issued = await repository.rotateCodes(
          grant,
          lease: lease,
          beginDispatch: gate.beginDispatch,
        );
        if (!_valid(revision)) return;
        codes = List.unmodifiable(issued);
      } else {
        await repository.unlinkGoogle(
          grant,
          lease: lease,
          beginDispatch: gate.beginDispatch,
        );
      }
      if (!_valid(revision)) return;
      if (purpose == ReauthenticationPurpose.unlinkIdentity) {
        continuity.markUnlink();
      }
      await _fetchAndApply(revision);
      if (!_valid(revision)) return;
      message =
          purpose == ReauthenticationPurpose.unlinkIdentity && !writeBlocked
          ? 'Đã cập nhật phương thức đăng nhập.'
          : purpose == ReauthenticationPurpose.rotateRecoveryCodes
          ? 'Lưu các mã mới ngay. Chúng chỉ hiển thị một lần.'
          : message;
    } catch (error) {
      if (preparationAttempted && lease == null && _valid(revision)) {
        try {
          continuity.applyGate(journal.reconciliationGate(generation));
        } catch (_) {}
      }
      final dispatched = dispatchGate?.cancel() ?? false;
      if (lease != null && !dispatched) {
        try {
          await journal.clearMutation(
            lease,
            MarkerResolution.provenNotDispatched,
          );
          if (current) continuity.applyGate(ReconciliationGate.clean);
        } catch (_) {
          if (_valid(revision)) {
            message = const SessionFailure(
              SessionFailureKind.storage,
            ).toString();
          }
        }
      }
      if (!_valid(revision)) return;
      if (lease != null && dispatched) {
        if (purpose == ReauthenticationPurpose.rotateRecoveryCodes &&
            codes.isEmpty) {
          continuity.markLostCodes();
        } else if (purpose == ReauthenticationPurpose.unlinkIdentity) {
          continuity.markUnlink();
        }
        try {
          final refreshed = await _fetchAndApply(revision);
          if (!_valid(revision)) return;
          if (refreshed &&
              purpose == ReauthenticationPurpose.unlinkIdentity &&
              error is AccountAuthFailure &&
              error.kind == AccountAuthFailureKind.lastAuthenticationMethod &&
              continuity.gate == ReconciliationGate.pendingUnlink) {
            await journal.clearMutation(
              lease,
              MarkerResolution.lastMethodRejected,
            );
            if (!_valid(revision)) return;
            continuity.applyGate(ReconciliationGate.clean);
            message = _message(error);
          }
        } catch (_) {
          if (_valid(revision)) {
            message =
                'Chưa xác minh được trạng thái máy chủ. Tải lại phương thức trước khi tiếp tục.';
          }
        }
        if (_valid(revision) &&
            purpose == ReauthenticationPurpose.rotateRecoveryCodes) {
          message = codes.isEmpty
              ? 'Không nhận được mã mới. Mã cũ có thể đã bị hủy. Kiểm tra trạng thái trước khi tạo bộ khác.'
              : 'Mã mới đang hiển thị; chưa tải được trạng thái máy chủ. Hãy lưu mã và tải lại trước khi xác nhận.';
        }
      } else {
        message = _message(error);
      }
    } finally {
      if (_valid(revision)) {
        _mutationGate = null;
        _mutationPurpose = null;
        busy = false;
        writeInFlight = false;
        _publish();
      }
    }
  }

  Future<bool> _fetchAndApply(int revision) async {
    if (continuity.gate == ReconciliationGate.storageBlocked) {
      continuity.applyGate(await journal.refreshReconciliation(generation));
      if (!_valid(revision)) return false;
    }
    final pending = journal.pendingMutation(generation);
    final updated = await repository.methods();
    if (!_valid(revision)) return false;
    if (pending != null &&
        pending.marker.operation == ReconciliationOperation.unlinkGoogle &&
        updated.google == null) {
      await journal.clearMutation(pending, MarkerResolution.providerAbsent);
      if (!_valid(revision)) return false;
      continuity.applyGate(ReconciliationGate.clean);
    } else if (pending != null &&
        pending.marker.operation ==
            ReconciliationOperation.rotateRecoveryCodes) {
      continuity.markRotationVerified(pending);
    }
    methods = updated;
    if (!continuity.reconcile(updated)) {
      message = switch (continuity.gate) {
        ReconciliationGate.pendingUnlink =>
          'Binblog vẫn ghi nhận Google. Tải lại trạng thái trước khi thao tác tiếp.',
        ReconciliationGate.pendingRotation =>
          'Mã có thể đã thay đổi. Xác nhận sau khi kiểm tra trạng thái trước khi tạo bộ khác.',
        _ =>
          'Phiên này chưa thể thay đổi phương thức. Đăng xuất bền vững rồi đăng nhập lại hoặc liên hệ hỗ trợ.',
      };
    }
    return true;
  }

  bool get canAcknowledgeLostCodes =>
      !privacySuspended &&
      !busy &&
      lostCodes &&
      continuity.verifiedRotation != null;

  Future<void> acknowledgeCodes() => _acknowledgeRotation();
  Future<void> acknowledgeLostCodes() =>
      canAcknowledgeLostCodes ? _acknowledgeRotation() : Future.value();

  Future<void> _acknowledgeRotation() async {
    if (privacySuspended || busy) return;
    codes = const [];
    final lease = continuity.verifiedRotation;
    if (lease == null) {
      continuity.markLostCodes();
      message = 'Tải lại trạng thái trước khi xác nhận bộ mã.';
      _publish();
      return;
    }
    final revision = ++_revision;
    busy = true;
    _publish();
    try {
      await journal.clearMutation(lease, MarkerResolution.codesAcknowledged);
      if (!_valid(revision)) return;
      continuity.applyGate(ReconciliationGate.clean);
    } catch (_) {
      if (!_valid(revision)) return;
      continuity.markLostCodes();
      message =
          'Chưa lưu được trạng thái xác nhận. Tải lại và thử lại; không tạo bộ mã khác lúc này.';
    } finally {
      if (_valid(revision)) {
        busy = false;
        _publish();
      }
    }
  }

  static String _message(Object error) => switch (error) {
    AccountAuthFailure(:final message) => message,
    SessionFailure() => error.toString(),
    _ => 'Không tải được phương thức đăng nhập.',
  };

  @override
  void dispose() {
    final dispatched = _mutationGate?.cancel() ?? false;
    if (codes.isNotEmpty ||
        continuity.gate == ReconciliationGate.pendingRotation ||
        (dispatched &&
            _mutationPurpose == ReauthenticationPurpose.rotateRecoveryCodes)) {
      continuity.markLostCodes();
    } else if (dispatched &&
        _mutationPurpose == ReauthenticationPurpose.unlinkIdentity) {
      continuity.markUnlink();
    }
    _disposed = true;
    _revision++;
    _mutationGate = null;
    _mutationPurpose = null;
    repository.cancel();
    codes = const [];
    methods = null;
    message = null;
    busy = false;
    writeInFlight = false;
    super.dispose();
  }
}
