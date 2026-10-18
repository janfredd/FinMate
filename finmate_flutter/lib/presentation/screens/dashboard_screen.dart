import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/providers.dart';
import 'shell.dart';

// Summary cards + pie chart + recent transactions.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sum = ref.watch(summaryProvider);
    final br = ref.watch(breakdownProvider);
    final tx = ref.watch(txnsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: () async => refreshAll(ref),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          sum.when(
            data: (s) => Column(children: [
              Row(children: [
                _card('Income', s.income, Colors.green, Icons.arrow_downward),
                const SizedBox(width: 8),
                _card('Expense', s.expense, Colors.red, Icons.arrow_upward),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _card('Balance', s.balance, Colors.teal, Icons.wallet),
                const SizedBox(width: 8),
                _card('Savings', s.savings, Colors.blue, Icons.savings),
              ]),
            ]),
            loading: () => loading(),
            error: (e, _) => errView(e, () => ref.invalidate(summaryProvider)),
          ),
          const SizedBox(height: 16),
          const Text('Expense breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(
            height: 220,
            child: br.when(
              data: (items) {
                if (items.isEmpty) return emptyView('No expenses yet.');
                final total =
                    items.fold<double>(0, (a, e) => a + (e['total'] as num).toDouble());
                return Row(children: [
                  Expanded(
                    child: PieChart(PieChartData(sections: [
                      for (var i = 0; i < items.length; i++)
                        PieChartSectionData(
                          value: (items[i]['total'] as num).toDouble(),
                          title: total == 0 ? '' :
                              '${((items[i]['total'] as num).toDouble() / total * 100).toStringAsFixed(0)}%',
                          color: Colors.primaries[i % Colors.primaries.length],
                          radius: 70),
                    ])),
                  ),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: items.map((e) => Text(
                            '${e['category_name']}: ${e['total']}',
                            overflow: TextOverflow.ellipsis)).toList()),
                  ),
                ]);
              },
              loading: () => loading(),
              error: (e, _) => errView(e, () => ref.invalidate(breakdownProvider)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Recent transactions', style: TextStyle(fontWeight: FontWeight.bold)),
          tx.when(
            data: (list) => Column(
                children: list.take(5).map((t) => ListTile(
                  leading: Icon(t.type == 'income'
                      ? Icons.arrow_downward : Icons.arrow_upward,
                      color: t.type == 'income' ? Colors.green : Colors.red),
                  title: Text(t.merchant ?? t.categoryName ?? '-'),
                  subtitle: Text('${t.date ?? ''} • ${t.source ?? ''}'),
                  trailing: Text(t.amount.toStringAsFixed(0),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                )).toList()),
            loading: () => loading(),
            error: (e, _) => errView(e, () => ref.invalidate(txnsProvider)),
          ),
        ]),
      ),
    );
  }

  Widget _card(String label, double v, Color c, IconData icon) => Expanded(
    child: Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(icon, color: c, size: 18), const SizedBox(width: 4),
                Text(label, style: const TextStyle(fontSize: 12))]),
              Text(v.toStringAsFixed(0),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c)),
            ]))));
}
