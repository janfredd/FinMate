import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/ui_kit.dart';
import '../providers/providers.dart';
import 'shell.dart';

// Profile: user info, edit, logout, delete.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with WidgetsBindingObserver {
  bool _checkingPayment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(profileProvider);
      final orderId = ref.read(pendingPaymentOrderProvider);
      if (orderId != null) _checkPaymentStatus(orderId);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(profileProvider);
      final orderId = ref.read(pendingPaymentOrderProvider);
      if (orderId != null) _checkPaymentStatus(orderId);
    }
  }

  Future<void> _checkPaymentStatus(String orderId) async {
    if (_checkingPayment) return;
    _checkingPayment = true;
    try {
      final status = await ref.read(apiProvider).checkPaymentStatus(orderId);
      final txStatus = (status['transaction_status'] ?? '').toString();
      final success = status['success'] == true;
      final premium = status['is_premium'] == true;
      if (success && premium) {
        ref.read(pendingPaymentOrderProvider.notifier).state = null;
        ref.invalidate(profileProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Pembayaran Berhasil, kamu sekarang Premium!')));
        }
      } else if (const {'deny', 'cancel', 'expire', 'failure'}
          .contains(txStatus)) {
        ref.read(pendingPaymentOrderProvider.notifier).state = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Pembayaran belum berhasil. Silakan coba lagi.')));
        }
      }
    } catch (e) {
      if (mounted) showFriendlyError(context, e);
    } finally {
      _checkingPayment = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final profile = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profile.when(
        data: (p) {
          final displayName = (p['name'] ?? p['email'] ?? 'FinMate').toString();
          final email = (p['email'] ?? '').toString();
          final initial =
              displayName.isEmpty ? 'F' : displayName[0].toUpperCase();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              _ProfileHeader(
                name: displayName,
                email: email,
                initial: initial,
              ),
              const SizedBox(height: 24),
              if (p['is_premium'] == true)
                const _PremiumStatusCard()
              else
                _PremiumCard(
                  isPremium: false,
                  onCheckStatus: _checkPaymentStatus,
                ),
              const SizedBox(height: 16),
              _ExportTile(isPremium: p['is_premium'] == true),
              const SizedBox(height: 24),
              const SectionHeader(
                title: 'Preferensi',
                subtitle: 'Atur tampilan favoritmu',
              ),
              const SizedBox(height: 12),
              SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: PlayfulIcon(
                    icon: isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: isDark
                        ? const Color(0xFFFFC46B)
                        : const Color(0xFFFFA24C),
                  ),
                  title: Text(isDark ? 'Mode Gelap' : 'Mode Terang'),
                  subtitle: Text(isDark
                      ? 'Ketuk untuk beralih ke mode terang'
                      : 'Ketuk untuk beralih ke mode gelap'),
                  trailing: Switch.adaptive(
                    value: isDark,
                    onChanged: (value) {
                      ref.read(themeProvider.notifier).state =
                          value ? ThemeMode.dark : ThemeMode.light;
                    },
                  ),
                  onTap: () {
                    ref.read(themeProvider.notifier).state =
                        isDark ? ThemeMode.light : ThemeMode.dark;
                  },
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader(
                title: 'Akun',
                subtitle: 'Kelola profil akunmu',
              ),
              const SizedBox(height: 12),
              SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    _profileTile(
                      context,
                      icon: Icons.edit_rounded,
                      color: scheme.primary,
                      title: 'Edit profil',
                      subtitle: 'Ubah nama atau email',
                      onTap: () => _editDialog(context, ref, p),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    _profileTile(
                      context,
                      icon: Icons.logout_rounded,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                      title: 'Logout',
                      subtitle: 'Keluar dari akun ini',
                      onTap: () async {
                        await api.logout();
                        ref.read(authStateProvider.notifier).state = false;
                      },
                    ),
                    const Divider(indent: 72, endIndent: 14),
                    _profileTile(
                      context,
                      icon: Icons.delete_forever_rounded,
                      color: scheme.error,
                      title: 'Hapus akun',
                      subtitle: 'Semua data akan dihapus permanen',
                      titleColor: scheme.error,
                      onTap: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                                title: const Text('Hapus akun?'),
                                content: const Text(
                                    'Semua transaksi, budget, dan token akan dihapus permanen.'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Batal')),
                                  FilledButton(
                                      style: FilledButton.styleFrom(
                                          backgroundColor: scheme.error,
                                          foregroundColor: scheme.onError),
                                      onPressed: () async {
                                        try {
                                          await api.deleteAccount();
                                          ref
                                              .read(authStateProvider.notifier)
                                              .state = false;
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            showFriendlyError(context, e);
                                          }
                                        }
                                      },
                                      child: const Text('Hapus')),
                                ],
                              )),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: loading,
        error: (e, _) => errView(e, () => ref.invalidate(profileProvider)),
      ),
    );
  }

  Widget _profileTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: PlayfulIcon(icon: icon, color: color),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: titleColor ?? Theme.of(context).colorScheme.onSurface)),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.chevron_right_rounded,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35)),
      onTap: onTap,
    );
  }

  void _editDialog(BuildContext ctx, WidgetRef ref, Map<String, dynamic> p) {
    final name = TextEditingController(text: p['name'] ?? '');
    final email = TextEditingController(text: p['email'] ?? '');
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Edit profil'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              decoration: const InputDecoration(
                  labelText: 'Nama',
                  prefixIcon: Icon(Icons.person_outline_rounded))),
          const SizedBox(height: 12),
          TextField(
              controller: email,
              decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline_rounded))),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
              onPressed: () async {
                try {
                  await ref
                      .read(apiProvider)
                      .updateProfile(name: name.text, email: email.text);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) showFriendlyError(ctx, e);
                }
              },
              child: const Text('Simpan')),
        ],
      ),
    );
  }
}

class _PremiumStatusCard extends StatelessWidget {
  const _PremiumStatusCard();

  static const _gold = Color(0xFFFFC46B);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SoftCard(
      padding: const EdgeInsets.all(20),
      gradient: LinearGradient(
        colors: dark
            ? const [Color(0xFF3A3320), Color(0xFF2C2819)]
            : const [Color(0xFFFFF8E1), Color(0xFFFFF0B8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: _gold, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: Premium 🌟',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Semua fitur premium sudah aktif untuk akunmu.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified_rounded, color: _gold, size: 24),
        ],
      ),
    );
  }
}

class _ExportTile extends ConsumerStatefulWidget {
  final bool isPremium;
  const _ExportTile({required this.isPremium});

  @override
  ConsumerState<_ExportTile> createState() => _ExportTileState();
}

class _ExportTileState extends ConsumerState<_ExportTile> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final csv = await ref.read(apiProvider).exportTransactionsCsv();
      final file =
          File('${Directory.systemTemp.path}/finmate_transactions.csv');
      await file.writeAsString(csv);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ekspor berhasil'),
          content: Text(
              'Riwayat transaksi berhasil diekspor ke CSV:\n\n${file.path}'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup')),
          ],
        ),
      );
    } on PremiumRequiredException catch (e) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Khusus Premium'),
          content: Text(e.message),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showFriendlyError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: PlayfulIcon(
          icon: Icons.file_download_rounded,
          color: widget.isPremium ? scheme.primary : scheme.onSurface,
        ),
        title: const Text('Ekspor Data (CSV)'),
        subtitle: Text(widget.isPremium
            ? 'Unduh seluruh riwayat transaksi kamu'
            : 'Fitur khusus pengguna Premium'),
        trailing: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : Icon(
                widget.isPremium
                    ? Icons.chevron_right_rounded
                    : Icons.lock_rounded,
                color: scheme.onSurface.withValues(alpha: 0.4),
              ),
        onTap: _busy ? null : _export,
      ),
    );
  }
}

class _PremiumCard extends ConsumerStatefulWidget {
  final bool isPremium;
  final Future<void> Function(String orderId) onCheckStatus;
  const _PremiumCard({
    required this.isPremium,
    required this.onCheckStatus,
  });

  @override
  ConsumerState<_PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends ConsumerState<_PremiumCard> {
  bool _busy = false;

  static const _navy = Color(0xFF0F172A);
  static const _gold = Color(0xFFFFC46B);

  Future<void> _upgrade() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final session = await ref.read(apiProvider).createPayment(49000);
      if (session.redirectUrl.isEmpty || session.orderId.isEmpty) {
        throw const FriendlyException(
            'Gagal membuat transaksi. Silakan coba lagi.');
      }
      ref.read(pendingPaymentOrderProvider.notifier).state = session.orderId;
      final opened = await launchUrl(Uri.parse(session.redirectUrl),
          mode: LaunchMode.externalApplication);
      if (!opened) {
        ref.read(pendingPaymentOrderProvider.notifier).state = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Tidak dapat membuka halaman pembayaran.')));
        }
        return;
      }
      await widget.onCheckStatus(session.orderId);
    } catch (e) {
      if (mounted) showFriendlyError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.isPremium;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navy, Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.35),
            blurRadius: 30,
            spreadRadius: -6,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: _gold, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FinMate Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      active
                          ? 'Semua fitur premium sudah aktif'
                          : 'Buka semua fitur eksklusif FinMate',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (active)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'AKTIF',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _benefit('Analisis AI tanpa batas'),
          _benefit('Budget & insight lanjutan'),
          _benefit('Ekspor laporan keuangan'),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: active || _busy ? null : _upgrade,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: _navy,
                      ),
                    )
                  : const Icon(Icons.rocket_launch_rounded, size: 20),
              label: Text(
                active
                    ? 'Premium Aktif'
                    : _busy
                        ? 'Memproses...'
                        : 'Upgrade Sekarang — Rp 49.000',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _navy,
                disabledBackgroundColor: active
                    ? _gold.withValues(alpha: 0.35)
                    : _gold.withValues(alpha: 0.5),
                disabledForegroundColor: _navy.withValues(alpha: 0.7),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: _gold, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final String initial;
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onPrimary;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.28),
            blurRadius: 30,
            spreadRadius: -6,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              initial,
              style: TextStyle(
                color: fg,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: fg,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.76),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.verified_rounded, color: fg, size: 22),
          ),
        ],
      ),
    );
  }
}
