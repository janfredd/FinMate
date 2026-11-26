import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/api_client.dart';
import '../../core/app_router.dart';
import '../../core/format.dart';
import '../../core/ui_kit.dart';
import '../../data/models/models.dart';
import '../providers/providers.dart';
import 'shell.dart';
import 'add_txn_screen.dart';

// Search/filter list + FAB (Manual / Scan receipt / Voice input).
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
                          child:
                              Text(e.name, overflow: TextOverflow.ellipsis))),
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
              var f = list
                  .where((t) =>
                      (q.isEmpty ||
                          (t.merchant ?? '')
                              .toLowerCase()
                              .contains(q.toLowerCase()) ||
                          (t.note ?? '')
                              .toLowerCase()
                              .contains(q.toLowerCase())) &&
                      (type == 'all' || t.type == type) &&
                      (catId == null || t.categoryId == catId))
                  .toList();
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
                  return FadeSlideIn(
                    key: ValueKey(t.id),
                    delay: Duration(milliseconds: (i > 8 ? 8 : i) * 40),
                    child: Padding(
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
                                context, slideFadeRoute(AddTxnScreen(edit: t))),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
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
      floatingActionButton: PressableScale(
        child: FloatingActionButton.extended(
          onPressed: _showAddSheet,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Catat'),
        ),
      ),
    );
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetTile(
              ctx,
              icon: Icons.edit_rounded,
              color: Theme.of(ctx).colorScheme.primary,
              title: 'Input Manual',
              subtitle: 'Isi transaksi sendiri',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, slideFadeRoute(const AddTxnScreen()));
              },
            ),
            _sheetTile(
              ctx,
              icon: Icons.document_scanner_rounded,
              color: Theme.of(ctx).colorScheme.tertiary,
              title: 'Scan Struk',
              subtitle: 'Foto struk, isi otomatis',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    slideFadeRoute(const AddTxnScreen(scanFirst: true)));
              },
            ),
            _sheetTile(
              ctx,
              icon: Icons.mic_rounded,
              color: Theme.of(ctx).colorScheme.secondary,
              title: 'Input Suara',
              subtitle: 'Ucapkan transaksi, isi otomatis',
              onTap: () {
                Navigator.pop(ctx);
                Future.microtask(_startVoiceInput);
              },
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _startVoiceInput() async {
    final result = await showModalBottomSheet<_VoiceResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _VoiceInputSheet(),
    );
    if (result == null || !mounted) return;
    await Navigator.push(
      context,
      slideFadeRoute(
        AddTxnScreen(
          initialAmount: result.amount,
          initialMerchant: result.merchant,
          initialCategoryId: result.categoryId,
          initialSource: 'Voice',
        ),
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

class _VoiceResult {
  final double amount;
  final String merchant;
  final String? categoryId;
  const _VoiceResult({
    required this.amount,
    required this.merchant,
    this.categoryId,
  });
}

class _VoiceInputSheet extends ConsumerStatefulWidget {
  const _VoiceInputSheet();

  @override
  ConsumerState<_VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends ConsumerState<_VoiceInputSheet> {
  final SpeechToText _speech = SpeechToText();
  bool _starting = true, _listening = false, _processing = false;
  bool _submitted = false;
  String _transcript = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_start);
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          if (_listening) setState(() => _listening = false);
          _submit();
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _starting = false;
          _listening = false;
          _error = 'Input suara gagal: ${error.errorMsg}';
        });
      },
    );
    if (!mounted) return;
    if (!available) {
      setState(() {
        _starting = false;
        _error = 'Izin mikrofon ditolak atau layanan suara tidak tersedia.';
      });
      return;
    }

    String? localeId;
    try {
      final locales = await _speech.locales();
      for (final l in locales) {
        if (l.localeId.toLowerCase().startsWith('id')) {
          localeId = l.localeId;
          break;
        }
      }
    } catch (_) {
      // Fall back to the device default locale.
    }
    if (!mounted) return;

    _transcript = '';
    _submitted = false;
    setState(() {
      _starting = false;
      _listening = true;
    });
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _transcript = result.recognizedWords);
        if (result.finalResult) {
          _speech.stop();
          setState(() => _listening = false);
          _submit();
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  Future<void> _stopAndSubmit() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
    }
    await _submit();
  }

  Future<void> _submit() async {
    if (_processing || _submitted) return;
    final text = _transcript.trim();
    if (text.isEmpty) {
      if (mounted) {
        setState(() {
          _starting = false;
          _listening = false;
          _error = 'Belum ada suara yang terdengar. Coba lagi ya.';
        });
      }
      return;
    }
    _submitted = true;
    if (mounted) {
      setState(() {
        _processing = true;
        _error = null;
      });
    }
    try {
      final parsed = await ref.read(apiProvider).parseVoice(text);
      final rawAmount = parsed['amount'];
      final amount = rawAmount is num
          ? rawAmount.toDouble()
          : double.tryParse('$rawAmount') ?? 0;
      final merchant = (parsed['merchant'] ?? '').toString().trim();
      final category = (parsed['category'] ?? '').toString().trim();

      List<Category> cats = const [];
      try {
        cats = await ref.read(categoriesProvider.future);
      } catch (_) {
        // Keep amount/merchant filled even if categories failed to load.
      }

      String? categoryId;
      for (final c in cats) {
        if (c.name.toLowerCase() == category.toLowerCase()) {
          categoryId = c.id;
          break;
        }
      }
      if (categoryId == null) {
        for (final c in cats) {
          if (c.name.toLowerCase() == 'others') {
            categoryId = c.id;
            break;
          }
        }
      }

      if (!mounted) return;
      Navigator.pop(
        context,
        _VoiceResult(
          amount: amount,
          merchant: merchant,
          categoryId: categoryId,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _submitted = false;
        _error = friendlyError(e);
      });
    }
  }

  void _retry() {
    setState(() {
      _starting = true;
      _processing = false;
      _submitted = false;
      _transcript = '';
      _error = null;
    });
    _start();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = _processing
        ? 'Memproses ucapan...'
        : _starting
            ? 'Menyiapkan mikrofon...'
            : _listening
                ? 'Mendengarkan...'
                : 'Input suara';
    final hint = _processing
        ? 'Transaksi kamu sedang diisi otomatis.'
        : _listening
            ? 'Ucapkan misalnya "Kopi Kenangan 25 ribu".'
            : 'Tekan Selesai setelah selesai berbicara.';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.secondary, scheme.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.3),
                    blurRadius: 26,
                    spreadRadius: -4,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Icon(
                _processing ? Icons.auto_awesome_rounded : Icons.mic_rounded,
                color: scheme.onPrimary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              status,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (_transcript.isNotEmpty) ...[
              const SizedBox(height: 16),
              SoftCard(
                padding: const EdgeInsets.all(14),
                shadow: false,
                child: Text(
                  '"$_transcript"',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error),
              ),
            ],
            const SizedBox(height: 24),
            if (_processing)
              const CircularProgressIndicator()
            else if (_listening)
              GradientPillButton(
                label: 'Selesai',
                icon: Icons.stop_rounded,
                onPressed: _stopAndSubmit,
              )
            else if (_error != null)
              GradientPillButton(
                label: 'Coba lagi',
                icon: Icons.refresh_rounded,
                onPressed: _retry,
              )
            else
              GradientPillButton(
                label: 'Batal',
                icon: Icons.close_rounded,
                onPressed: () => Navigator.pop(context),
              ),
          ],
        ),
      ),
    );
  }
}
