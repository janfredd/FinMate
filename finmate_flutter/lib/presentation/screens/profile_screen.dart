import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/providers.dart';
import 'shell.dart';

// Profile: user info, Gmail connect/revoke, edit, logout, delete.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
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
          return ListView(padding: const EdgeInsets.all(16), children: [
            CircleAvatar(radius: 36,
                child: Text((p['name'] ?? p['email'])[0].toUpperCase())),
            const SizedBox(height: 8),
            Center(child: Text(p['name'] ?? '-',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            Center(child: Text(p['email'] ?? '')),
            const Divider(height: 32),
            ListTile(leading: const Icon(Icons.edit),
                title: const Text('Edit profile'),
                onTap: () => _editDialog(context, ref, p)),
            ListTile(leading: const Icon(Icons.email),
                title: const Text('Connect Gmail'),
                subtitle: const Text('Auto-import bank notification emails'),
                onTap: () async {
                  final url = await api.gmailConnect();
                  await launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication);
                }),
            ListTile(leading: const Icon(Icons.link_off),
                title: const Text('Revoke Gmail access'),
                onTap: () async {
                  await api.gmailRevoke();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Gmail access revoked.')));
                  }
                }),
            ListTile(leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  await api.logout();
                  ref.read(authStateProvider.notifier).state = false;
                }),
            ListTile(leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Delete account',
                    style: TextStyle(color: Colors.red)),
                subtitle: const Text('Removes all transactions, budgets, tokens'),
                onTap: () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete account?'),
                      content: const Text('This removes ALL your data permanently.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel')),
                        FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.red),
                            onPressed: () async {
                              await api.deleteAccount();
                              ref.read(authStateProvider.notifier).state = false;
                              if (context.mounted) Navigator.pop(context);
                            },
                            child: const Text('Delete')),
                      ]))),
          ]);
        },
      ),
    );
  }

  void _editDialog(BuildContext ctx, WidgetRef ref, Map<String, dynamic> p) {
    final name = TextEditingController(text: p['name'] ?? '');
    final email = TextEditingController(text: p['email'] ?? '');
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name,
              decoration: const InputDecoration(labelText: 'Name')),
          TextField(controller: email,
              decoration: const InputDecoration(labelText: 'Email')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () async {
                await ref.read(apiProvider).updateProfile(
                    name: name.text, email: email.text);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save')),
        ],
      ),
    );
  }
}
