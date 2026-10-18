import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../application/auth/account_authentication_controller.dart';
import '../../data/auth/auth_management_client.dart';
import '../../domain/auth/session.dart';

class AccountMethodsScreen extends StatefulWidget {
  final SessionAccess authority;
  final int generation;
  final http.Client client;
  final AccountMethodsContinuity? continuity;
  const AccountMethodsScreen({
    super.key,
    required this.authority,
    required this.generation,
    required this.client,
    this.continuity,
  });

  @override
  State<AccountMethodsScreen> createState() => _AccountMethodsScreenState();
}

class _AccountMethodsScreenState extends State<AccountMethodsScreen>
    with WidgetsBindingObserver {
  late final AccountAuthenticationController model;
  TextEditingController? _passwordInput;
  DialogRoute<String>? _passwordDialogRoute;
  int _dialogRevision = 0;
  bool _privacyShield = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    model = AccountAuthenticationController(
      repository: AuthManagementClient(
        authority: widget.authority,
        generation: widget.generation,
        client: widget.client,
      ),
      authority: widget.authority,
      generation: widget.generation,
      continuity: widget.continuity,
    )..addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) model.refresh();
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      model.resumeForPrivacy();
      if (model.methods == null) model.refresh();
      if (mounted) setState(() => _privacyShield = false);
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _dialogRevision++;
      _passwordInput?.clear();
      model.suspendForPrivacy();
      final route = _passwordDialogRoute;
      _passwordDialogRoute = null;
      if (route != null && route.isActive) {
        route.navigator?.removeRoute(route);
      }
      if (mounted) setState(() => _privacyShield = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dialogRevision++;
    final route = _passwordDialogRoute;
    _passwordDialogRoute = null;
    _passwordInput = null;
    // A screen can be removed while its root Navigator remains alive. Wait for
    // the current frame before removing only this screen's dialog route.
    // A Navigator being torn down disposes the route itself instead.
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = route.navigator;
        if (route.isActive && navigator != null && navigator.mounted) {
          navigator.removeRoute(route);
        }
      });
    }
    model.removeListener(_changed);
    model.dispose();
    super.dispose();
  }

  Future<void> _confirm({required bool unlink}) async {
    if (model.busy || model.privacySuspended || _passwordDialogRoute != null) {
      return;
    }
    final revision = ++_dialogRevision;
    final input = TextEditingController();
    _passwordInput = input;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          unlink
              ? 'Gỡ Google'
              : model.methods?.codesEnrolled == true
              ? 'Xoay mã khôi phục'
              : 'Tạo mã khôi phục',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              unlink
                  ? 'Chỉ tiếp tục khi mật khẩu Binblog còn dùng được. Máy chủ sẽ kiểm tra lại phương thức cuối cùng.'
                  : 'Bộ mã cũ sẽ không còn dùng được. Mã mới chỉ hiển thị một lần.',
            ),
            TextField(
              controller: input,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Mật khẩu Binblog'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, input.text),
            child: const Text('Xác minh và tiếp tục'),
          ),
        ],
      ),
    );
    _passwordDialogRoute = route;
    try {
      // Navigator force-disposal completes route.completed, but it need not
      // complete the future returned by push. Either signal must release the
      // owner so the controller can be disposed after the route is gone.
      final submitted = await Future.any<String?>([
        navigator.push<String>(route),
        route.completed,
      ]);
      input.clear();
      if (!mounted ||
          revision != _dialogRevision ||
          model.privacySuspended ||
          submitted == null ||
          submitted.isEmpty) {
        return;
      }
      if (unlink) {
        await model.unlink(submitted);
      } else {
        await model.rotate(submitted);
      }
    } finally {
      if (identical(_passwordDialogRoute, route)) _passwordDialogRoute = null;
      if (identical(_passwordInput, input)) _passwordInput = null;
      input.clear();
      await route.completed;
      input.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_privacyShield) {
      return const Scaffold(body: SizedBox.expand());
    }
    final methods = model.methods;
    return PopScope(
      canPop: !model.writeInFlight && model.codes.isEmpty,
      child: Scaffold(
        appBar: AppBar(title: const Text('Phương thức đăng nhập')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (model.busy) const LinearProgressIndicator(),
            if (model.message != null && model.message!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(model.message!),
              ),
            if (model.writeBlocked) ...[
              const Text(
                'Chưa xác minh được trạng thái máy chủ. Không thể thay đổi tài khoản lúc này.',
              ),
              TextButton(
                onPressed: model.busy ? null : model.refresh,
                child: const Text('Tải lại phương thức'),
              ),
            ],
            if (model.lostCodes) ...[
              const Text(
                'Không nhận được bộ mã mới. Mã trước đó có thể đã bị hủy. Chỉ tạo bộ khác sau khi đã kiểm tra trạng thái.',
              ),
              TextButton(
                onPressed: !model.canAcknowledgeLostCodes
                    ? null
                    : model.acknowledgeLostCodes,
                child: const Text('Tôi hiểu, cho phép tạo bộ mã khác'),
              ),
            ],
            if (methods == null) ...[
              const Text('Chưa tải được trạng thái phương thức từ Binblog.'),
              TextButton(
                onPressed: model.busy ? null : model.refresh,
                child: const Text('Tải lại'),
              ),
            ] else ...[
              ListTile(
                title: const Text('Mật khẩu'),
                subtitle: Text(
                  methods.passwordUsable ? 'Có thể đăng nhập' : 'Chưa khả dụng',
                ),
              ),
              for (final provider in methods.providers)
                ListTile(
                  title: Text(
                    provider.provider == 'google'
                        ? 'Google'
                        : 'Nhà cung cấp khác',
                  ),
                  subtitle: Text(
                    provider.usable ? 'Có thể đăng nhập' : 'Chưa khả dụng',
                  ),
                ),
              ListTile(
                title: const Text('Mã khôi phục'),
                subtitle: Text(methods.codesEnrolled ? 'Đã tạo' : 'Chưa tạo'),
              ),
              if (model.codes.isNotEmpty) ...[
                const Text(
                  'Lưu các mã này ngay. Chúng sẽ biến mất khi rời màn hình hoặc xác nhận.',
                ),
                for (final code in model.codes) Text(code),
                FilledButton(
                  onPressed: model.acknowledgeCodes,
                  child: const Text('Tôi đã lưu các mã'),
                ),
              ],
              if (methods.passwordUsable)
                FilledButton(
                  onPressed: model.canRotate
                      ? () => _confirm(unlink: false)
                      : null,
                  child: Text(
                    methods.codesEnrolled
                        ? 'Xoay mã khôi phục'
                        : 'Tạo mã khôi phục',
                  ),
                ),
              if (methods.canUnlinkGoogle)
                OutlinedButton(
                  onPressed: model.canUnlink
                      ? () => _confirm(unlink: true)
                      : null,
                  child: const Text('Gỡ Google'),
                ),
              TextButton(
                onPressed: model.busy ? null : model.refresh,
                child: const Text('Làm mới trạng thái'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
