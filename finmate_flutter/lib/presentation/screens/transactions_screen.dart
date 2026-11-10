import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            SearchBar(hintText: 'Search merchant or note...',
                onChanged: (v) => setState(() => q = v),
                leading: const Icon(Icons.search)),
            const SizedBox(height: 8),
            Row(children: [
              DropdownButton<String>(
                  value: type,
                  items: const ['all', 'income', 'expense']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => type = v!)),
              const SizedBox(width: 8),
              Expanded(
                child: cats.when(
                  data: (c) => DropdownButton<String?>(
                      value: catId, hint: const Text('Category'),
                      isExpanded: true,
                      items: <DropdownMenuItem<String?>>[
                            const DropdownMenuItem(value: null, child: Text('All'))]
                          .followedBy(c.map((e) => DropdownMenuItem(
                              value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis))))
                          .toList(),
                      onChanged: (v) => setState(() => catId = v)),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ),
            ]),
          ]),
        ),
        Expanded(
          child: txns.when(
            data: (list) {
              var f = list.where((t) =>
                  (q.isEmpty ||
                      (t.merchant ?? '').toLowerCase().contains(q.toLowerCase()) ||
                      (t.note ?? '').toLowerCase().contains(q.toLowerCase())) &&
                  (type == 'all' || t.type == type) &&
                  (catId == null || t.categoryId == catId)).toList();
              if (f.isEmpty) return emptyView('No transactions found.');
              return ListView.builder(
                itemCount: f.length,
                itemBuilder: (_, i) {
                  final t = f[i];
                  return Dismissible(
                    key: Key(t.id),
                    background: Container(color: Colors.red),
                    onDismissed: (_) async {
                      try {
                        await ref.read(apiProvider).deleteTxn(t.id);
                        refreshAll(ref);
                      } catch (e) {
                        if (context.mounted) showFriendlyError(context, e);
                        refreshAll(ref);
                      }
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                          backgroundColor: t.type == 'income' ? Colors.green[100] : Colors.red[100],
                          child: Icon(t.type == 'income' ? Icons.add : Icons.remove)),
                      title: Text('${t.merchant ?? t.categoryName ?? '-'} • ${formatRupiah(t.amount)}'),
                      subtitle: Text('${t.date ?? ''} • ${t.categoryName ?? ''} • ${t.source ?? ''}\n${t.note ?? ''}'),
                      isThreeLine: true,
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => AddTxnScreen(edit: t))),
                    ),
                  );
                });
            },
            loading: () => loading(),
            error: (e, _) => errView(e, () => ref.invalidate(txnsProvider)),
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
            context: context,
            builder: (_) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(leading: const Icon(Icons.edit),
                    title: const Text('Manual entry'),
                    onTap: () { Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const AddTxnScreen())); }),
                ListTile(leading: const Icon(Icons.email),
                    title: const Text('Import from Gmail'),
                    onTap: () async { Navigator.pop(context);
                      try {
                        final n = await ref.read(apiProvider).gmailImport();
                        refreshAll(ref);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Imported $n transactions')));
                        }
                      } catch (e) {
                        if (context.mounted) showFriendlyError(context, e);
                      }
                    }),
                ListTile(leading: const Icon(Icons.camera_alt),
                    title: const Text('Scan receipt (OCR)'),
                    onTap: () { Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const AddTxnScreen(scanFirst: true))); }),
              ]))),
        child: const Icon(Icons.add),
      ),
    );
  }
}
