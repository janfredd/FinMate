import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/format.dart';
import '../../core/notification_service.dart';
import '../../core/ui_kit.dart';
import '../../data/models/models.dart';
import '../providers/providers.dart';
import 'shell.dart';

// Summary cards + pie chart + recent transactions.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<DashboardScreen> {
  static bool _insightNotified = false;

  void _notifyInsight(List<Map<String, dynamic>> list) {
    if (_insightNotified || list.isEmpty) return;
    final message = list.first['message']?.toString() ?? '';
    if (message.isEmpty) return;
    _insightNotified = true;
    NotificationService.showInsight(message);
  }

  @override
  Widget build(BuildContext context) {
    final sum = ref.watch(summaryProvider);
    final br = ref.watch(breakdownProvider);
    final tx = ref.watch(txnsProvider);
    final insights = ref.watch(insightsProvider);
    final scheme = Theme.of(context).colorScheme;

    ref.listen(insightsProvider, (_, next) {
      if (next.hasValue) _notifyInsight(next.value!);
    });
    if (insights.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notifyInsight(insights.value!);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: FinLogo(size: 42, showName: false),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => refreshAll(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            sum.when(
              data: (s) => Column(
                children: [
                  PressableScale(child: _BalanceCard(amount: s.balance)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: PressableScale(
                          child: _StatCard(
                            label: 'Pemasukan',
                            value: s.income,
                            icon: Icons.south_west_rounded,
                            color: scheme.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PressableScale(
                          child: _StatCard(
                            label: 'Pengeluaran',
                            value: s.expense,
                            icon: Icons.north_east_rounded,
                            color: scheme.tertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PressableScale(child: _SavingsCard(amount: s.savings)),
                ],
              ),
              loading: () => SizedBox(height: 220, child: loading()),
              error: (e, _) =>
                  errView(e, () => ref.invalidate(summaryProvider)),
            ),
            insights.when(
              data: (list) => list.isEmpty
                  ? const SizedBox()
                  : Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: PressableScale(
                        child: _InsightBanner(
                          message: list.first['message']?.toString() ?? '',
                        ),
                      ),
                    ),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 28),
            const SectionHeader(
              title: 'Expense breakdown',
              subtitle: 'Ke mana uangmu pergi?',
            ),
            const SizedBox(height: 12),
            PressableScale(
              child: SoftCard(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 220,
                  child: br.when(
                    data: (items) => _Breakdown(items: items),
                    loading: () => loading(),
                    error: (e, _) =>
                        errView(e, () => ref.invalidate(breakdownProvider)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const SectionHeader(
              title: 'Recent transactions',
              subtitle: 'Aktivitas terbaru kamu',
            ),
            const SizedBox(height: 12),
            tx.when(
              data: (list) {
                if (list.isEmpty) {
                  return const SoftCard(
                    child: EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'Belum ada transaksi',
                      message:
                          'Yuk mulai catat pemasukan atau pengeluaran pertamamu!',
                    ),
                  );
                }
                final recent = list.take(5).toList();
                return PressableScale(
                  child: SoftCard(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    child: Column(
                      children: [
                        for (var i = 0; i < recent.length; i++) ...[
                          FadeSlideIn(
                            key: ValueKey('recent-${recent[i].id}'),
                            delay: Duration(milliseconds: i * 60),
                            child: _TxnRow(txn: recent[i]),
                          ),
                          if (i != recent.length - 1)
                            const Divider(indent: 66, endIndent: 12),
                        ],
                      ],
                    ),
                  ),
                );
              },
              loading: () => SizedBox(height: 120, child: loading()),
              error: (e, _) => errView(e, () => ref.invalidate(txnsProvider)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double amount;
  const _BalanceCard({required this.amount});

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
            color: scheme.primary.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: -6,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -36,
            top: -46,
            child: _Orb(size: 120, opacity: 0.14),
          ),
          const Positioned(
            right: 54,
            bottom: -56,
            child: _Orb(size: 80, opacity: 0.1),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: fg.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.account_balance_wallet_rounded,
                        color: fg, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Total Balance',
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: fg.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'FinMate',
                      style: TextStyle(
                          color: fg, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatRupiah(amount),
                  style: TextStyle(
                    color: fg,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Saldo gabungan dari semua transaksi',
                style:
                    TextStyle(color: fg.withValues(alpha: 0.72), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final double opacity;
  const _Orb({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlayfulIcon(icon: icon, color: color, size: 40, iconSize: 20),
          const SizedBox(height: 12),
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatRupiah(value),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightBanner extends StatelessWidget {
  final String message;
  const _InsightBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final titleColor = dark ? const Color(0xFFFFE082) : const Color(0xFF7A5B00);
    final bodyColor =
        dark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF6B5400);
    return SoftCard(
      padding: const EdgeInsets.all(16),
      shadow: false,
      gradient: LinearGradient(
        colors: dark
            ? const [Color(0xFF3A3320), Color(0xFF2C2819)]
            : const [Color(0xFFFFF8E1), Color(0xFFFFF0B8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: dark ? 0.08 : 0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('💡', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Insight',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('✨', style: TextStyle(fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.45,
                    color: bodyColor,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingsCard extends StatelessWidget {
  final double amount;
  const _SavingsCard({required this.amount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final positive = amount >= 0;
    final accent = positive ? scheme.primary : scheme.error;
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          PlayfulIcon(
            icon: positive
                ? Icons.savings_rounded
                : Icons.sentiment_dissatisfied_rounded,
            color: accent,
            size: 54,
            iconSize: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tabungan', style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatRupiah(amount),
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  positive
                      ? 'Terus konsisten ya!'
                      : 'Waduh, pengeluaran lebih besar dari pemasukan. Yuk, hemat lagi!',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              positive ? '😎' : '☹️',
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _Breakdown({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.pie_chart_outline_rounded,
        title: 'Belum ada pengeluaran',
        message: 'Grafik akan muncul setelah kamu mencatat pengeluaran.',
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final palette = [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      const Color(0xFFFFB84D),
      const Color(0xFF5AA9FF),
      const Color(0xFFFF8A9B),
      const Color(0xFF8B7CFF),
    ];
    final total =
        items.fold<double>(0, (a, e) => a + (e['total'] as num).toDouble());
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 28,
              sections: [
                for (var i = 0; i < items.length; i++)
                  PieChartSectionData(
                    value: (items[i]['total'] as num).toDouble(),
                    title: total == 0
                        ? ''
                        : '${((items[i]['total'] as num).toDouble() / total * 100).toStringAsFixed(0)}%',
                    color: palette[i % palette.length],
                    radius: 42,
                    titleStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: palette[i % palette.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            items[i]['category_name']?.toString() ?? '-',
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          formatRupiah((items[i]['total'] as num).toDouble()),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TxnRow extends StatelessWidget {
  final Txn txn;
  const _TxnRow({required this.txn});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final income = txn.type == 'income';
    final color = income ? scheme.secondary : scheme.tertiary;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      leading: PlayfulIcon(
        icon: income ? Icons.south_west_rounded : Icons.north_east_rounded,
        color: color,
        size: 44,
        iconSize: 20,
      ),
      title: Text(
        txn.merchant ?? txn.categoryName ?? '-',
        style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${txn.date ?? ''} • ${txn.source ?? ''}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Text(
        '${income ? '+' : '-'}${formatRupiah(txn.amount)}',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
