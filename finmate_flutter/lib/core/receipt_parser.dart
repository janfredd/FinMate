// On-device receipt parsing (mirrors backend/services/parsers.py).
// OCR text -> {merchant, total, date} shown for user confirmation before save.
class ReceiptResult {
  final String? merchant;
  final double? total;
  final String? date;
  ReceiptResult({this.merchant, this.total, this.date});
}

double? parseAmount(String text) {
  final res = [
    RegExp(r'(?:Rp|IDR|Rs\.?)\s*([\d\.,]+)', caseSensitive: false),
    RegExp(r'\$\s*([\d,]+\.?\d*)'),
    RegExp(r'(?:total|amount|grand total|bayar|paid)\s*[:\-]?\s*(?:Rp|IDR)?\s*([\d\.,]+)',
        caseSensitive: false),
  ];
  for (final rx in res) {
    final m = rx.firstMatch(text);
    if (m != null) {
      var raw = m.group(1)!.replaceAll(' ', '');
      if (raw.contains(',') && raw.contains('.')) {
        if (raw.lastIndexOf(',') > raw.lastIndexOf('.')) {
          raw = raw.replaceAll('.', '').replaceAll(',', '.');
        } else {
          raw = raw.replaceAll(',', '');
        }
      } else if (raw.contains(',')) {
        final parts = raw.split(',');
        raw = raw.replaceAll(',', parts.last.length == 2 ? '.' : '');
      } else {
        raw = raw.replaceAll(',', '');
        if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(raw)) {
          raw = raw.replaceAll('.', '');
        }
      }
      final v = double.tryParse(raw);
      if (v != null) return v;
    }
  }
  return null;
}

String? parseDate(String text) {
  for (final rx in [
    RegExp(r'\d{4}-\d{2}-\d{2}'),
    RegExp(r'\d{2}[/-]\d{2}[/-]\d{4}'),
  ]) {
    final m = rx.firstMatch(text);
    if (m != null) return m.group(0);
  }
  return null;
}

ReceiptResult parseReceipt(String fullText) {
  final lines = fullText.split('\n').where((l) => l.trim().isNotEmpty).toList();
  String? merchant;
  for (final l in lines.take(5)) {
    final s = l.trim();
    if (s.length > 2 && parseAmount(s) == null && parseDate(s) == null) {
      merchant = s.length > 100 ? s.substring(0, 100) : s;
      break;
    }
  }
  double? best;
  for (final l in lines) {
    final a = parseAmount(l);
    if (a != null && (best == null || a > best)) best = a;
  }
  return ReceiptResult(merchant: merchant, total: best, date: parseDate(fullText));
}
