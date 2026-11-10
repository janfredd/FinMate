import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../../core/api_client.dart';
import '../../core/ui_kit.dart';

// Email/password register + login + reset. Max simplicity per spec.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthState();
}

class _AuthState extends ConsumerState<AuthScreen> {
  final email = TextEditingController(), pw = TextEditingController(),
      name = TextEditingController();
  bool isLogin = true, busy = false, showPw = false;
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.surface,
              scheme.primary.withValues(alpha: 0.07),
              scheme.tertiary.withValues(alpha: 0.09),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: FinLogo(),
                    ),
                    const SizedBox(height: 10),
                    const _AuthIllustration(),
                    const SizedBox(height: 18),
                    SoftCard(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            isLogin
                                ? 'Selamat datang kembali'
                                : 'Buat akun baru',
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isLogin
                                ? 'Masuk buat lanjut ngatur finansialmu.'
                                : 'Daftar dan mulai perjalanan finansialmu.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 22),
                          if (!isLogin) ...[
                            TextField(
                              controller: name,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Nama',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          TextField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: pw,
                            obscureText: !showPw,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => busy ? null : _go(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                tooltip: showPw
                                    ? 'Sembunyikan password'
                                    : 'Tampilkan password',
                                icon: Icon(showPw
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded),
                                onPressed: () =>
                                    setState(() => showPw = !showPw),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(apiProvider)
                                      .resetPassword(email.text.trim());
                                  setState(() => msg =
                                      'Kalau email terdaftar, link reset sudah dikirim.');
                                } catch (e) {
                                  setState(() => msg = friendlyError(e));
                                }
                              },
                              child: const Text('Lupa password?'),
                            ),
                          ),
                          if (msg != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      size: 18, color: scheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      msg!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: scheme.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          GradientPillButton(
                            label: isLogin ? 'Masuk' : 'Daftar',
                            icon: isLogin
                                ? Icons.login_rounded
                                : Icons.person_add_alt_1_rounded,
                            busy: busy,
                            onPressed: busy ? null : _go,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLogin
                                    ? 'Belum punya akun?'
                                    : 'Sudah punya akun?',
                                style: theme.textTheme.bodySmall,
                              ),
                              TextButton(
                                onPressed: () =>
                                    setState(() => isLogin = !isLogin),
                                child: Text(isLogin ? 'Daftar' : 'Masuk'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthIllustration extends StatelessWidget {
  const _AuthIllustration();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 24,
            top: 18,
            child: _bubble(56, scheme.secondary.withValues(alpha: 0.16)),
          ),
          Positioned(
            right: 18,
            top: 0,
            child: _bubble(74, scheme.tertiary.withValues(alpha: 0.16)),
          ),
          Positioned(
            right: 40,
            bottom: 4,
            child: _bubble(44, scheme.primary.withValues(alpha: 0.13)),
          ),
          Transform.rotate(
            angle: -0.06,
            child: Container(
              width: 152,
              height: 152,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(52),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.32),
                    blurRadius: 34,
                    spreadRadius: -8,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Icon(Icons.account_balance_wallet_rounded,
                  size: 68, color: scheme.onPrimary),
            ),
          ),
          Positioned(
            left: 34,
            top: 34,
            child: _miniCard(
                theme, Icons.trending_up_rounded, const Color(0xFF2BD9B4)),
          ),
          Positioned(
            right: 26,
            bottom: 38,
            child: _miniCard(theme, Icons.savings_rounded, scheme.primary),
          ),
          Positioned(
            left: 60,
            bottom: 18,
            child: _miniCard(theme, Icons.auto_awesome_rounded, scheme.tertiary),
          ),
        ],
      ),
    );
  }

  Widget _bubble(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _miniCard(ThemeData theme, IconData icon, Color color) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
