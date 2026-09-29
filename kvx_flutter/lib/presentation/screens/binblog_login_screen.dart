import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/auth/session.dart';
import '../providers/session_provider.dart';

class BinblogLoginScreen extends StatefulWidget {
  const BinblogLoginScreen({super.key});
  @override
  State<BinblogLoginScreen> createState() => _BinblogLoginScreenState();
}

class _BinblogLoginScreenState extends State<BinblogLoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<SessionProvider>();
    final busy =
        model.state.phase == SessionPhase.authenticating ||
        model.state.clearing ||
        model.isSessionTransitioning;
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập Binblog')),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (model.state.reason == SignOutReason.expired)
              const Text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'),
            TextField(
              controller: _username,
              enabled: !busy,
              autocorrect: false,
              autofillHints: const [AutofillHints.username],
              decoration: const InputDecoration(labelText: 'Tên đăng nhập'),
            ),
            TextField(
              controller: _password,
              enabled: !busy,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Mật khẩu'),
            ),
            if (model.state.message != null) ...[
              Text(
                model.state.message!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: busy ? null : () => model.logout(),
                child: const Text('Thử lại đăng xuất'),
              ),
            ],
            if (model.loginError != null)
              Text(
                model.loginError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy || model.state.message != null
                  ? null
                  : () async {
                      if (_username.text.trim().isEmpty ||
                          _password.text.isEmpty) {
                        return;
                      }
                      final password = _password.text;
                      _password.clear();
                      await model.login(_username.text, password);
                    },
              child: busy
                  ? const CircularProgressIndicator(
                      semanticsLabel: 'Đang xử lý phiên',
                    )
                  : const Text('Đăng nhập'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: busy || model.state.message != null
                  ? null
                  : model.loginWithGoogle,
              icon: const Text(
                'G',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              label: const Text('Đăng nhập bằng Google'),
            ),
            if (model.state.phase == SessionPhase.authenticating)
              TextButton(
                onPressed: () {
                  _password.clear();
                  model.logout();
                },
                child: const Text('Hủy đăng nhập'),
              ),
          ],
        ),
      ),
    );
  }
}
