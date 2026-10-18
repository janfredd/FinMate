import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../../core/api_client.dart';

// Email/password register + login + reset. Max simplicity per spec.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthState();
}

class _AuthState extends ConsumerState<AuthScreen> {
  final email = TextEditingController(), pw = TextEditingController(),
      name = TextEditingController();
  bool isLogin = true, busy = false;
  String? msg;

  Future<void> _go() async {
    setState(() { busy = true; msg = null; });
    try {
      final api = ref.read(apiProvider);
      if (isLogin) {
        await api.login(email.text.trim(), pw.text);
      } else {
        await api.register(email.text.trim(), pw.text,
            name.text.trim().isEmpty ? null : name.text.trim());
      }
      ref.read(authStateProvider.notifier).state = true;
    } catch (e) {
      setState(() => msg = friendlyError(e));
    } finally {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FinMate')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Icon(Icons.account_balance_wallet, size: 72, color: Colors.teal),
          const SizedBox(height: 12),
          if (!isLogin)
            TextField(controller: name,
                decoration: const InputDecoration(labelText: 'Name')),
          if (!isLogin) const SizedBox(height: 12),
          TextField(controller: email, keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 12),
          TextField(controller: pw, obscureText: true,
              decoration: const InputDecoration(labelText: 'Password')),
          const SizedBox(height: 16),
          if (msg != null)
            Text(msg!, style: const TextStyle(color: Colors.red)),
          SizedBox(width: double.infinity,
            child: FilledButton(onPressed: busy ? null : _go,
              child: busy
                  ? const CircularProgressIndicator()
                  : Text(isLogin ? 'Login' : 'Register'))),
          TextButton(
              onPressed: () => setState(() => isLogin = !isLogin),
              child: Text(isLogin
                  ? 'No account? Register'
                  : 'Have an account? Login')),
          TextButton(
              onPressed: () async {
                try {
                  await ref.read(apiProvider).resetPassword(email.text.trim());
                  setState(() => msg = 'If the email exists, a reset link was sent.');
                } catch (e) {
                  setState(() => msg = friendlyError(e));
                }
              },
              child: const Text('Forgot password?')),
        ]),
      ),
    );
  }
}
