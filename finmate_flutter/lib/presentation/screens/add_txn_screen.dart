import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../core/receipt_parser.dart';
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

  Future<void> _scan() async {
    final img = await ImagePicker().pickImage(source: ImageSource.camera);
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
      source = 'Receipt';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('OCR done — please confirm the values.')));
      }
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> _save() async {
    setState(() => busy = true);
    try {
      final body = {
        'type': type, 'amount': double.parse(amount.text),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.edit != null ? 'Edit transaction' : 'Add transaction'),
          actions: [IconButton(icon: const Icon(Icons.camera_alt),
              tooltip: 'Scan receipt', onPressed: _scan)]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          if (scanning) const LinearProgressIndicator(),
          SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
              ],
              selected: {type},
              onSelectionChanged: (s) => setState(() => type = s.first)),
          const SizedBox(height: 12),
          TextField(controller: amount, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount')),
          const SizedBox(height: 12),
          cats.when(
            data: (c) => DropdownButtonFormField<String>(
                initialValue: catId, decoration: const InputDecoration(labelText: 'Category'),
                items: c.map((e) =>
                    DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                onChanged: (v) => setState(() => catId = v)),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Categories: $e'),
          ),
          const SizedBox(height: 12),
          TextField(controller: merchant,
              decoration: const InputDecoration(labelText: 'Merchant')),
          const SizedBox(height: 12),
          TextField(controller: note,
              decoration: const InputDecoration(labelText: 'Note')),
          const SizedBox(height: 12),
          ListTile(title: Text('Date: ${date.toIso8601String().substring(0, 10)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(context: context,
                    firstDate: DateTime(2000), lastDate: DateTime(2100),
                    initialDate: date);
                if (d != null) setState(() => date = d);
              }),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity,
              child: FilledButton(onPressed: busy ? null : _save,
                  child: Text(busy ? 'Saving...' : 'Save ($source)'))),
        ]),
      ),
    );
  }
}
