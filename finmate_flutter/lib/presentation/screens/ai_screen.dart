import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

// Chat bubbles + proactive insights header.
class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});
  @override
  ConsumerState<AiScreen> createState() => _AiState();
}

class _AiState extends ConsumerState<AiScreen> {
  final input = TextEditingController();
  bool busy = false;

  Future<void> _send() async {
    final q = input.text.trim();
    if (q.isEmpty || busy) return;
    input.clear();
    ref.read(chatProvider.notifier).addUser(q);
    setState(() => busy = true);
    try {
      final a = await ref.read(apiProvider).chat(q); // <10s target
      ref.read(chatProvider.notifier).addAi(a);
    } catch (e) {
      ref.read(chatProvider.notifier).addAi('Error: $e');
    } finally {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final msgs = ref.watch(chatProvider);
    final insights = ref.watch(insightsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: Column(children: [
        insights.when(
          data: (list) => list.isEmpty
              ? const SizedBox()
              : Container(
                  width: double.infinity, color: Colors.amber[50],
                  padding: const EdgeInsets.all(8),
                  child: Text('Insight: ${list.first['message']}',
                      style: const TextStyle(fontSize: 12))),
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
        ),
        Expanded(
          child: msgs.isEmpty
              ? const Center(child: Text(
                  'Ask about your spending, e.g.\n"Where did my money go in October?"',
                  textAlign: TextAlign.center))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final me = m.role == 'user';
                    return Align(
                      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 300),
                        decoration: BoxDecoration(
                          color: me ? Colors.teal : Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(m.text,
                            style: TextStyle(
                                color: me ? Colors.white : Colors.black87)),
                      ),
                    );
                  }),
        ),
        if (busy) const LinearProgressIndicator(),
        SafeArea(
          child: Row(children: [
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(controller: input,
                        decoration: const InputDecoration(
                            hintText: 'Ask a question...'),
                        onSubmitted: (_) => _send()))),
            IconButton(icon: const Icon(Icons.send), onPressed: _send),
          ]),
        ),
      ]),
    );
  }
}
