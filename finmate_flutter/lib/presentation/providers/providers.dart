import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../data/datasources/api_service.dart';
import '../../data/models/models.dart';

final apiClientProvider = Provider((_) => ApiClient());
final apiProvider = Provider((ref) => ApiService(ref.watch(apiClientProvider)));
final authStateProvider = StateProvider<bool>((_) => false);

final categoriesProvider = FutureProvider<List<Category>>(
    (ref) => ref.watch(apiProvider).categories());
final txnsProvider = FutureProvider<List<Txn>>(
    (ref) => ref.watch(apiProvider).transactions());
final summaryProvider = FutureProvider<Summary>(
    (ref) => ref.watch(apiProvider).summary());
final breakdownProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => ref.watch(apiProvider).breakdown());
final budgetsProvider = FutureProvider<List<Budget>>(
    (ref) => ref.watch(apiProvider).budgets());
final insightsProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => ref.watch(apiProvider).insights(refresh: true));

// Chat state for AI Assistant screen.
class ChatMsg {
  final String role; // user | ai
  final String text;
  ChatMsg(this.role, this.text);
}

class ChatNotifier extends StateNotifier<List<ChatMsg>> {
  ChatNotifier() : super([]);
  void addUser(String t) => state = [...state, ChatMsg('user', t)];
  void addAi(String t) => state = [...state, ChatMsg('ai', t)];
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, List<ChatMsg>>((_) => ChatNotifier());

void refreshAll(WidgetRef ref) {
  ref.invalidate(txnsProvider);
  ref.invalidate(summaryProvider);
  ref.invalidate(breakdownProvider);
  ref.invalidate(budgetsProvider);
  ref.invalidate(categoriesProvider);
}
