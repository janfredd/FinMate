import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/ui_kit.dart';
import '../providers/providers.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';
import 'budget_screen.dart';
import 'ai_screen.dart';
import 'profile_screen.dart';
import 'auth_screen.dart';

// Root: shows Auth when logged out, else 5-tab bottom navigation.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logged = ref.watch(authStateProvider);
    return logged ? const HomeShell() : const AuthScreen();
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int idx = 0;
  final screens = const [
    DashboardScreen(), TransactionsScreen(), BudgetScreen(), AiScreen(), ProfileScreen()
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => setState(() => idx = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings_rounded),
            label: 'Budget',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy_rounded),
            label: 'AI Assistant',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Auto-login if a JWT is stored.
class SplashLoader extends ConsumerStatefulWidget {
  const SplashLoader({super.key});
  @override
  ConsumerState<SplashLoader> createState() => _SplashLoaderState();
}

class _SplashLoaderState extends ConsumerState<SplashLoader> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final t = await ref.read(apiClientProvider).readToken();
      ref.read(authStateProvider.notifier).state = t != null && t.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) => const RootGate();
}

Widget loading() => const Center(child: CircularProgressIndicator());
Widget errView(Object e, VoidCallback retry) {
  final message = friendlyError(e);
  if (message.isEmpty) return const SizedBox.shrink();
  return EmptyState(
    icon: Icons.cloud_off_rounded,
    title: 'Ups, ada kendala',
    message: message,
    action: FilledButton.icon(
      onPressed: retry,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Coba lagi'),
    ),
  );
}

Widget emptyView(String msg) => EmptyState(
      icon: Icons.inbox_rounded,
      title: 'Belum ada data',
      message: msg,
    );
