import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
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
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Transactions'),
          NavigationDestination(icon: Icon(Icons.savings), label: 'Budget'),
          NavigationDestination(icon: Icon(Icons.smart_toy), label: 'AI Assistant'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
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
  return Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      ElevatedButton(onPressed: retry, child: const Text('Retry')),
    ]));
}
Widget emptyView(String msg) => Center(
  child: Text(msg, style: const TextStyle(color: Colors.grey)));
