import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/receipt_parser.dart';
import '../../core/api_client.dart';
import '../../core/ui_kit.dart';
import '../../data/models/models.dart';
import '../providers/providers.dart';

// Manual form (max 3 steps on one screen) + OCR pre-fill.
// OCR: capture/upload -> ML Kit -> parse -> confirm form -> save.
class AddTxnScreen extends ConsumerStatefulWidget {
  final Txn? edit;
  final bool scanFirst;
  const AddTxnScreen({super.key, this.edit, this.scanFirst = false});
  @override
  ConsumerState<AddTxnScreen> createState() => _AddState();
}

class _AddState extends ConsumerState<AddTxnScreen> {
  String type = 'expense';
  final amount = TextEditingController(),
      merchant = TextEditingController(), note = TextEditingController();
  String? catId;
  DateTime date = DateTime.now();
  bool busy = false, scanning = false;
  String source = 'Manual';

  final SpeechToText _speech = SpeechToText();
  bool _listening = false, _parsingVoice = false, _voiceSubmitted = false;
  String _voiceTranscript = '';

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      type = e.type; amount.text = e.amount.toString();
      merchant.text = e.merchant ?? ''; note.text = e.note ?? '';
      catId = e.categoryId; source = e.source ?? 'Manual';
      date = DateTime.tryParse(e.date ?? '') ?? DateTime.now();
    }
    if (widget.scanFirst) Future.microtask(_scan);
  }

  @override
  void dispose() {
    _speech.cancel();
    amount.dispose();
    merchant.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      await _submitVoice();
    } else {
      await _startVoice();
    }
  }

  Future<void> _startVoice() async {
    if (_parsingVoice) return;
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          if (_listening) setState(() => _listening = false);
          _submitVoice();
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _listening = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Input suara gagal: ${error.errorMsg}'),
        ));
      },
    );
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Izin mikrofon ditolak atau layanan suara tidak tersedia.'),
      ));
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

    _voiceTranscript = '';
    _voiceSubmitted = false;
    if (mounted) setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        _voiceTranscript = result.recognizedWords;
        setState(() {});
        if (result.finalResult) {
          _speech.stop();
          setState(() => _listening = false);
          _submitVoice();
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

  Future<void> _submitVoice() async {
    if (_parsingVoice || _voiceSubmitted) return;
    final text = _voiceTranscript.trim();
    if (text.isEmpty) {
      if (mounted) setState(() => _listening = false);
      return;
    }
    _voiceSubmitted = true;
    if (mounted) setState(() => _parsingVoice = true);
    try {
      final parsed = await ref.read(apiProvider).parseVoice(text);
      final rawAmount = parsed['amount'];
      final parsedAmount = rawAmount is num
          ? rawAmount.toDouble()
          : double.tryParse('$rawAmount') ?? 0;
      final parsedMerchant = (parsed['merchant'] ?? '').toString().trim();
      final parsedCategory = (parsed['category'] ?? '').toString().trim();

      List<Category> cats = const [];
      try {
        cats = await ref.read(categoriesProvider.future);
      } catch (_) {
        // Keep amount/merchant filled even if categories failed to load.
      }
      String? matched;
      for (final c in cats) {
        if (c.name.toLowerCase() == parsedCategory.toLowerCase()) {
          matched = c.id;
          break;
        }
      }
      if (matched == null) {
        for (final c in cats) {
          if (c.name.toLowerCase() == 'others') {
            matched = c.id;
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        if (parsedAmount > 0) {
          amount.text = parsedAmount == parsedAmount.roundToDouble()
              ? parsedAmount.toStringAsFixed(0)
              : parsedAmount.toString();
        }
        if (parsedMerchant.isNotEmpty) merchant.text = parsedMerchant;
        if (matched != null) catId = matched;
        source = 'Voice';
        _voiceTranscript = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Isian otomatis dari suara. Cek lagi ya.')));
    } catch (e) {
      if (mounted) showFriendlyError(context, e);
    } finally {
      if (mounted) setState(() => _parsingVoice = false);
    }
  }

  Future<void> _scan() async {
    final imgSource = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                leading:
                    PlayfulIcon(icon: Icons.camera_alt_rounded, color: scheme.primary),
                title: const Text('Kamera'),
                subtitle: const Text('Ambil foto struk atau screenshot'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const SizedBox(height: 4),
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                leading: PlayfulIcon(
                    icon: Icons.photo_library_rounded, color: scheme.secondary),
                title: const Text('Galeri'),
                subtitle: const Text('Pilih gambar struk / mutasi m-banking'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ]),
          ),
        );
      },
    );
    if (imgSource == null) return;

    final img = await ImagePicker().pickImage(source: imgSource);
    if (img == null) return;
    setState(() => scanning = true);
    try {
      final rec = TextRecognizer(script: TextRecognitionScript.latin);
      final res = await rec.processImage(InputImage.fromFilePath(img.path));
      await rec.close();
      final p = parseReceipt(res.text); // <5s on-device target
      if (p.total != null) amount.text = p.total.toString();
      if (p.merchant != null) merchant.text = p.merchant!;
      if (p.date != null) {
        date = DateTime.tryParse(p.date!) ?? date;
      }
      if (p.type != null) type = p.type!;
      source = 'Receipt';
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('OCR selesai — cek lagi nilainya ya.')));
      }
    } catch (e) {
      if (mounted) {
        showFriendlyError(context, e);
      }
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> _save() async {
    final parsedAmount =
        double.tryParse(amount.text.trim().replaceAll(',', '.'));
    if (parsedAmount == null || parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Masukkan nominal yang valid, contoh: 6,78 atau 6.78')));
      return;
    }
    setState(() => busy = true);
    try {
      final body = {
        'type': type, 'amount': parsedAmount,
        'category_id': catId, 'date': date.toIso8601String().substring(0, 10),
        'merchant': merchant.text.isEmpty ? null : merchant.text,
        'note': note.text.isEmpty ? null : note.text, 'source': source,
      };
      final api = ref.read(apiProvider);
      if (widget.edit != null) {
        await api.updateTxn(widget.edit!.id, body);
      } else {
        await api.addTxn(body);
      }
      refreshAll(ref);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showFriendlyError(context, e);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: date,
    );
    if (d != null) setState(() => date = d);
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.edit != null ? 'Edit transaksi' : 'Tambah transaksi'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              tooltip: _listening ? 'Berhenti merekam' : 'Input suara',
              style: IconButton.styleFrom(
                backgroundColor: (_listening ? scheme.error : scheme.secondary)
                    .withValues(alpha: 0.12),
                foregroundColor:
                    _listening ? scheme.error : scheme.secondary,
              ),
              icon: Icon(_listening ? Icons.stop_rounded : Icons.mic),
              onPressed: _toggleVoice,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Scan struk',
              style: IconButton.styleFrom(
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                foregroundColor: scheme.primary,
              ),
              icon: const Icon(Icons.document_scanner_outlined),
              onPressed: _scan,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (scanning) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: const LinearProgressIndicator(minHeight: 6),
              ),
              const SizedBox(height: 10),
              Text('Membaca struk...', style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
            ],
            if (_listening || _parsingVoice) ...[
              SoftCard(
                padding: const EdgeInsets.all(14),
                shadow: false,
                gradient: LinearGradient(
                  colors: [
                    scheme.secondary.withValues(alpha: 0.14),
                    scheme.primary.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: Row(
                  children: [
                    PlayfulIcon(
                      icon: _listening
                          ? Icons.mic_rounded
                          : Icons.auto_awesome_rounded,
                      color: _listening ? scheme.error : scheme.primary,
                      size: 42,
                      iconSize: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _listening
                                ? 'Mendengarkan...'
                                : 'Memproses suara...',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (_voiceTranscript.isNotEmpty)
                            Text(
                              '"$_voiceTranscript"',
                              style: theme.textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (_listening)
                      TextButton(
                        onPressed: _toggleVoice,
                        child: const Text('Selesai'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            SoftCard(
              padding: const EdgeInsets.all(6),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'expense',
                    label: Text('Pengeluaran'),
                    icon: Icon(Icons.shopping_bag_outlined),
                  ),
                  ButtonSegment(
                    value: 'income',
                    label: Text('Pemasukan'),
                    icon: Icon(Icons.attach_money_rounded),
                  ),
                ],
                selected: {type},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => type = s.first),
              ),
            ),
            const SizedBox(height: 18),
            SoftCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Detail transaksi', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Nominal',
                      hintText: '0',
                      prefixText: 'Rp ',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  cats.when(
                    data: (c) => DropdownButtonFormField<String>(
                      initialValue: catId,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: c
                          .map((e) => DropdownMenuItem(
                              value: e.id, child: Text(e.name)))
                          .toList(),
                      onChanged: (v) => setState(() => catId = v),
                    ),
                    loading: () => const SizedBox(
                        height: 56, child: Center(child: LinearProgressIndicator())),
                    error: (e, _) {
                      final message = friendlyError(e);
                      return message.isEmpty
                          ? const SizedBox()
                          : Text(message,
                              style: TextStyle(color: scheme.error),
                              textAlign: TextAlign.center);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: merchant,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Merchant',
                      hintText: 'Contoh: Kopi Kenangan',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: note,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Catatan',
                      hintText: 'Opsional...',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  PlayfulIcon(
                      icon: Icons.calendar_month_rounded,
                      color: scheme.secondary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tanggal', style: theme.textTheme.bodySmall),
                        const SizedBox(height: 2),
                        Text(
                          date.toIso8601String().substring(0, 10),
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  TextButton(onPressed: _pickDate, child: const Text('Ubah')),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GradientPillButton(
              label: busy
                  ? 'Menyimpan...'
                  : (widget.edit != null
                      ? 'Simpan perubahan'
                      : 'Simpan transaksi'),
              icon: Icons.check_rounded,
              busy: busy,
              onPressed: busy ? null : _save,
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('Sumber: $source',
                  style: theme.textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}
