import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/ui_kit.dart';
import '../providers/providers.dart';
import 'shell.dart';

// Profile: user info, Gmail connect/revoke, edit, logout, delete.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: api.profile(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return snap.hasError
                ? errView(snap.error!, () => (context as Element).markNeedsBuild())
                : loading();
          }
          final p = snap.data!;
          final displayName = (p['name'] ?? p['email'] ?? 'FinMate').toString();
          final email = (p['email'] ?? '').toString();
          final initial = displayName.isEmpty ? 'F' : displayName[0].toUpperCase();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              _ProfileHeader(
                name: displayName,
                email: email,
                initial: initial,
              ),
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
                subtitle: 'Kelola profil dan koneksi',
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
                    const Divider(indent: 72, endIndent: 14),
                    _profileTile(
                      context,
                      icon: Icons.mark_email_read_rounded,
                      color: scheme.secondary,
                      title: 'Hubungkan Gmail',
                      subtitle: 'Import otomatis email notifikasi bank',
                      onTap: () async {
                        try {
                          final url = await api.gmailConnect();
                          await launchUrl(Uri.parse(url),
                              mode: LaunchMode.externalApplication);
                        } catch (e) {
                          if (context.mounted) showFriendlyError(context, e);
                        }
                      },
                    ),
                    const Divider(indent: 72, endIndent: 14),
                    _profileTile(
                      context,
                      icon: Icons.link_off_rounded,
                      color: const Color(0xFFFF9F43),
                      title: 'Cabut akses Gmail',
                      subtitle: 'Hentikan import email otomatis',
                      onTap: () async {
                        try {
                          await api.gmailRevoke();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Akses Gmail dicabut.')));
                          }
                        } catch (e) {
                          if (context.mounted) showFriendlyError(context, e);
                        }
                      },
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
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35)),
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () async {
                try {
                  await ref.read(apiProvider).updateProfile(
                      name: name.text, email: email.text);
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
