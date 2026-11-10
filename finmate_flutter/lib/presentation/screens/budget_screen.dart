import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../providers/providers.dart';
import 'shell.dart';

// Budgets with progress bars; add/edit dialog.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets'),
          actions: [IconButton(icon: const Icon(Icons.add),
              onPressed: () => _dialog(context, ref, null))]),
      body: budgets.when(
        data: (list) {
          if (list.isEmpty) return emptyView('No budgets. Tap + to add one.');
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final b = list[i];
              final pct = (b.pct / 100).clamp(0.0, 1.0);
              final color = b.pct >= 100 ? Colors.red
                  : b.pct >= 80 ? Colors.orange : Colors.green;
              return Card(
                child: ListTile(
                  title: Text('${b.categoryName ?? ''} • ${b.period}'),
                  subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    LinearProgressIndicator(value: pct, color: color,
                        minHeight: 8),
                    Text('${formatRupiah(b.spent)} / '
                        '${formatRupiah(b.amount)} '
                        '(${b.pct.toStringAsFixed(0)}%)',
                        style: TextStyle(color: color)),
                  ]),
                  onTap: () => _dialog(context, ref, b),
                ),
              );
            });
        },
        loading: () => loading(),
        error: (e, _) => errView(e, () => ref.invalidate(budgetsProvider)),
      ),
    );
  }

  void _dialog(BuildContext ctx, WidgetRef ref, dynamic b) {
    final cats = ref.read(categoriesProvider).value ?? [];
    String? catId = b?.categoryId;
    final amt = TextEditingController(text: b != null ? b.amount.toString() : '');
    String period = b?.period ?? 'monthly';
    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(b == null ? 'Add budget' : 'Edit budget'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
                initialValue: catId, hint: const Text('Category'),
                items: cats.map((e) => DropdownMenuItem(
                    value: e.id, child: Text(e.name))).toList(),
                onChanged: (v) => setS(() => catId = v)),
            TextField(controller: amt,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Amount', hintText: 'Contoh: 6,78')),
            DropdownButtonFormField<String>(
                initialValue: period,
                items: const ['monthly', 'weekly']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setS(() => period = v!)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () async {
                  final parsedAmount =
                      double.tryParse(amt.text.trim().replaceAll(',', '.'));
                  if (parsedAmount == null || parsedAmount <= 0) {
                    ScaffoldMessenger.of(c).showSnackBar(const SnackBar(
                        content: Text(
                            'Masukkan nominal yang valid, contoh: 6,78')));
                    return;
                  }
                  final now = DateTime.now();
                  final start = DateTime(now.year, now.month, 1);
                  final end = DateTime(now.year, now.month + 1, 0);
                  try {
                    await ref.read(apiProvider).saveBudget({
                      'category_id': catId,
                      'amount': parsedAmount,
                      'period': period,
                      'start_date': start.toIso8601String().substring(0, 10),
                      'end_date': end.toIso8601String().substring(0, 10),
                    }, b?.id);
                    refreshAll(ref);
                    if (c.mounted) Navigator.pop(c);
                  } catch (e) {
                    if (c.mounted) showFriendlyError(c, e);
                  }
                },
                child: const Text('Save')),
          ],
        )),
    );
  }
}
