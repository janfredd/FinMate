import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/ui_kit.dart';
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
      final msg = friendlyError(e);
      if (msg.isNotEmpty) ref.read(chatProvider.notifier).addAi(msg);
    } finally {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final msgs = ref.watch(chatProvider);
    final insights = ref.watch(insightsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: Column(children: [
        insights.when(
          data: (list) => list.isEmpty
              ? const SizedBox()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: SoftCard(
                    padding: const EdgeInsets.all(14),
                    gradient: LinearGradient(
                      colors: [
                        scheme.secondary.withValues(alpha: 0.16),
                        scheme.primary.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shadow: false,
                    child: Row(
                      children: [
                        PlayfulIcon(
                            icon: Icons.auto_awesome_rounded,
                            color: scheme.secondary,
                            size: 40,
                            iconSize: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Insight: ${list.first['message']}',
                            style: theme.textTheme.bodySmall,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
        ),
        Expanded(
          child: msgs.isEmpty
              ? const EmptyState(
                  icon: Icons.smart_toy_rounded,
                  title: 'Hai, aku FinMate AI',
                  message:
                      'Tanya soal pola pengeluaranmu, sisa budget, atau tips nabung. Aku siap bantu!',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final me = m.role == 'user';
                    return Align(
                      alignment:
                          me ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(14),
                        constraints: const BoxConstraints(maxWidth: 300),
                        decoration: BoxDecoration(
                          gradient: me
                              ? LinearGradient(
                                  colors: [scheme.primary, scheme.tertiary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: me ? null : scheme.surface,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(me ? 20 : 6),
                            bottomRight: Radius.circular(me ? 6 : 20),
                          ),
                          border: me
                              ? null
                              : Border.all(
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.07)),
                          boxShadow: me
                              ? [
                                  BoxShadow(
                                    color:
                                        scheme.primary.withValues(alpha: 0.24),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          m.text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: me ? scheme.onPrimary : scheme.onSurface,
                          ),
                        ),
                      ),
                    );
                  }),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: LinearProgressIndicator(minHeight: 3),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: 'Tanya apa aja...',
                      prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 10),
                _SendButton(onTap: busy ? null : _send),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _SendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: onTap == null ? 0.5 : 1,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.primary, scheme.tertiary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Icon(Icons.send_rounded, color: scheme.onPrimary),
          ),
        ),
      ),
    );
  }
}
