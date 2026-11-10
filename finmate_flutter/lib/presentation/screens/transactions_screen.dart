import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/ui_kit.dart';
import '../providers/providers.dart';
import 'shell.dart';
import 'add_txn_screen.dart';

// Search/filter list + FAB (Manual / Import email / Scan receipt).
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});
  @override
  ConsumerState<TransactionsScreen> createState() => _TxnState();
}

class _TxnState extends ConsumerState<TransactionsScreen> {
  String q = '', type = 'all';
  String? catId;

  @override
  Widget build(BuildContext context) {
    final txns = ref.watch(txnsProvider);
    final cats = ref.watch(categoriesProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Column(children: [
            SearchBar(
              hintText: 'Cari merchant atau catatan...',
              onChanged: (v) => setState(() => q = v),
              leading: const Icon(Icons.search_rounded),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in const [
                    ('all', 'Semua'),
                    ('income', 'Pemasukan'),
                    ('expense', 'Pengeluaran'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(item.$2),
                        selected: type == item.$1,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => type = item.$1),
                        backgroundColor: scheme.surface,
                        selectedColor: scheme.primary.withValues(alpha: 0.15),
                        side: BorderSide(
                          color: type == item.$1
                              ? scheme.primary.withValues(alpha: 0.45)
                              : scheme.onSurface.withValues(alpha: 0.08),
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        labelStyle: TextStyle(
                          fontWeight: type == item.$1
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: type == item.$1
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            cats.when(
              data: (c) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: scheme.onSurface.withValues(alpha: 0.08)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: catId,
                    hint: const Text('Semua kategori'),
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(18),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem(
                          value: null, child: Text('Semua kategori')),
                      ...c.map((e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(e.name,
                              overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setState(() => catId = v),
                  ),
                ),
              ),
              loading: () => const SizedBox(height: 52),
              error: (_, __) => const SizedBox(),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: txns.when(
            data: (list) {
              var f = list.where((t) =>
                  (q.isEmpty ||
                      (t.merchant ?? '').toLowerCase().contains(q.toLowerCase()) ||
                      (t.note ?? '').toLowerCase().contains(q.toLowerCase())) &&
                  (type == 'all' || t.type == type) &&
                  (catId == null || t.categoryId == catId)).toList();
              if (f.isEmpty) {
                return const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Tidak ada transaksi',
                  message:
                      'Coba ubah filter atau tambahkan transaksi baru lewat tombol Catat.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                itemCount: f.length,
                itemBuilder: (_, i) {
                  final t = f[i];
                  final income = t.type == 'income';
                  final color = income ? scheme.secondary : scheme.tertiary;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Dismissible(
                      key: Key(t.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        decoration: BoxDecoration(
                          color: scheme.error,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                color: scheme.onError),
                            const SizedBox(width: 6),
                            Text('Hapus',
                                style: TextStyle(
                                    color: scheme.onError,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      onDismissed: (_) async {
                        try {
                          await ref.read(apiProvider).deleteTxn(t.id);
                          refreshAll(ref);
                        } catch (e) {
                          if (context.mounted) showFriendlyError(context, e);
                          refreshAll(ref);
                        }
                      },
                      child: SoftCard(
                        padding: const EdgeInsets.all(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => AddTxnScreen(edit: t))),
                          child: Row(
                            children: [
                              PlayfulIcon(
                                icon: income
                                    ? Icons.south_west_rounded
                                    : Icons.north_east_rounded,
                                color: color,
                                size: 48,
                                iconSize: 22,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.merchant ?? t.categoryName ?? '-',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(fontSize: 15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${t.categoryName ?? '-'} • ${t.source ?? ''}',
                                      style: theme.textTheme.bodySmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if ((t.note ?? '').isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        t.note!,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                color: scheme.onSurface
                                                    .withValues(alpha: 0.45)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${income ? '+' : '-'}${formatRupiah(t.amount)}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(t.date ?? '',
                                      style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => loading(),
            error: (e, _) => errView(e, () => ref.invalidate(txnsProvider)),
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
            context: context,
            builder: (_) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _sheetTile(
                    context,
                    icon: Icons.edit_rounded,
                    color: scheme.primary,
                    title: 'Catat manual',
                    subtitle: 'Isi transaksi sendiri',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AddTxnScreen()));
                    },
                  ),
                  _sheetTile(
                    context,
                    icon: Icons.mark_email_read_rounded,
                    color: scheme.secondary,
                    title: 'Import dari Gmail',
                    subtitle: 'Ambil transaksi dari email bank',
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        final n = await ref.read(apiProvider).gmailImport();
                        refreshAll(ref);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('$n transaksi berhasil diimport')));
                        }
                      } catch (e) {
                        if (context.mounted) showFriendlyError(context, e);
                      }
                    },
                  ),
                  _sheetTile(
                    context,
                    icon: Icons.document_scanner_rounded,
                    color: scheme.tertiary,
                    title: 'Scan struk (OCR)',
                    subtitle: 'Foto struk, isi otomatis',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const AddTxnScreen(scanFirst: true)));
                    },
                  ),
                ]),
              ),
            )),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Catat'),
      ),
    );
  }

  Widget _sheetTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      leading: PlayfulIcon(icon: icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}
