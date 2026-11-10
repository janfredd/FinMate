import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/ui_kit.dart';
import '../providers/providers.dart';
import 'shell.dart';

// Budgets with progress bars; add/edit dialog.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Tambah budget',
              style: IconButton.styleFrom(
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                foregroundColor: scheme.primary,
              ),
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _dialog(context, ref, null),
            ),
          ),
        ],
      ),
      body: budgets.when(
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.savings_rounded,
              title: 'Belum ada budget',
              message:
                  'Bikin budget biar pengeluaranmu lebih terkontrol dan anti boncos.',
              action: FilledButton.icon(
                onPressed: () => _dialog(context, ref, null),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah budget'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) {
              final b = list[i];
              final pct = (b.pct / 100).clamp(0.0, 1.0);
              final color = b.pct >= 100
                  ? scheme.error
                  : b.pct >= 80
                      ? const Color(0xFFFFA24C)
                      : scheme.secondary;
              final remaining = b.amount - b.spent;
              return SoftCard(
                padding: const EdgeInsets.all(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _dialog(context, ref, b),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          PlayfulIcon(
                              icon: Icons.savings_rounded,
                              color: color,
                              size: 50),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.categoryName ?? 'Tanpa kategori',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  b.period == 'monthly'
                                      ? 'Budget bulanan'
                                      : 'Budget mingguan',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${b.pct.toStringAsFixed(0)}%',
                              style: TextStyle(
                                  color: color, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('Terpakai',
                              style: Theme.of(context).textTheme.bodySmall),
                          const Spacer(),
                          Text(
                            '${formatRupiah(b.spent)} / ${formatRupiah(b.amount)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 10,
                          color: color,
                          backgroundColor: color.withValues(alpha: 0.12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            remaining >= 0
                                ? Icons.check_circle_outline_rounded
                                : Icons.error_outline_rounded,
                            size: 15,
                            color: color,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            remaining >= 0
                                ? 'Sisa ${formatRupiah(remaining)}'
                                : 'Lewat ${formatRupiah(remaining.abs())}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: color),
                          ),
                          const Spacer(),
                          Text('Ketuk untuk edit',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
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
          scrollable: true,
          title: Text(b == null ? 'Tambah budget' : 'Edit budget'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
                initialValue: catId,
                hint: const Text('Kategori'),
                decoration: const InputDecoration(
                    labelText: 'Kategori',
                    prefixIcon: Icon(Icons.category_outlined)),
                items: cats
                    .map((e) => DropdownMenuItem(
                        value: e.id, child: Text(e.name)))
                    .toList(),
                onChanged: (v) => setS(() => catId = v)),
            const SizedBox(height: 14),
            TextField(
                controller: amt,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Nominal',
                    hintText: 'Contoh: 6,78',
                    prefixText: 'Rp ',
                    prefixIcon: Icon(Icons.payments_outlined))),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
                initialValue: period,
                decoration: const InputDecoration(
                    labelText: 'Periode',
                    prefixIcon: Icon(Icons.repeat_rounded)),
                items: const ['monthly', 'weekly']
                    .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e == 'monthly' ? 'Bulanan' : 'Mingguan')))
                    .toList(),
                onChanged: (v) => setS(() => period = v!)),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Batal')),
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
                child: const Text('Simpan')),
          ],
        ),
      ),
    );
  }
}
