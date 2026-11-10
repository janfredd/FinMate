// On-device receipt / m-banking parsing (mirrors backend/services/parsers.py).
// OCR text -> {merchant, total, date, type} shown for user confirmation before save.
class ReceiptResult {
  final String? merchant;
  final double? total;
  final String? date;
  final String? type;
  ReceiptResult({this.merchant, this.total, this.date, this.type});
}

class _AmountCandidate {
  final double value;
  final int score;
  _AmountCandidate(this.value, this.score);
}

final _currencyRx = RegExp(r'(?:Rp\.?|IDR)\s*([\d.,]+)', caseSensitive: false);
final _dollarRx = RegExp(r'\$\s*([\d,]+\.?\d*)');
final _labelRx = RegExp(
    r'(nominal(?:\s+transfer)?|jumlah(?:\s+transfer)?|total(?:\s+bayar)?|grand\s+total|'
    r'amount|nilai|transfer|debit|kredit|bayar|paid|pembayaran|tagihan|diterima|masuk)'
    r'\s*[:\-]?\s*(?:Rp\.?|IDR|\$)?\s*([\d.,]+)',
    caseSensitive: false);

const _merchantLabels = [
  'ke rekening', 'kepada', 'penerima', 'nama penerima', 'merchant', 'tujuan',
  'deskripsi', 'description', 'berita',
];

const _skipMerchant = [
  'transfer berhasil', 'transaksi berhasil', 'pembayaran berhasil', 'berhasil',
  'bukti transfer', 'detail transaksi', 'struk', 'receipt', 'm-banking',
  'mobile banking', 'saldo', 'nominal', 'total', 'tanggal', 'waktu', 'jam',
  'no. referensi', 'referensi', 'bca', 'mandiri', 'bri', 'bni', 'cimb',
  'permata', 'danamon', 'btpn', 'jago', 'seabank', 'gopay', 'ovo', 'dana',
  'shopeepay', 'linkaja',
];

const _monthMap = {
  'jan': 1, 'januari': 1, 'january': 1,
  'feb': 2, 'februari': 2, 'february': 2,
  'mar': 3, 'maret': 3, 'march': 3,
  'apr': 4, 'april': 4,
  'mei': 5, 'may': 5,
  'jun': 6, 'juni': 6, 'june': 6,
  'jul': 7, 'juli': 7, 'july': 7,
  'agu': 8, 'agt': 8, 'agustus': 8, 'aug': 8, 'august': 8,
  'sep': 9, 'september': 9,
  'okt': 10, 'oktober': 10, 'oct': 10, 'october': 10,
  'nov': 11, 'november': 11,
  'des': 12, 'desember': 12, 'dec': 12, 'december': 12,
};

double? _toNumber(String raw) {
  var s = raw.trim().replaceAll(' ', '');
  if (s.isEmpty) return null;
  if (s.contains(',') && s.contains('.')) {
    if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else if (s.contains(',')) {
    final parts = s.split(',');
    s = parts.last.length == 2
        ? '${parts.sublist(0, parts.length - 1).join()}.${parts.last}'
        : s.replaceAll(',', '');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
    s = s.replaceAll('.', '');
  }
  return double.tryParse(s);
}

void _collectAmounts(RegExp rx, int group, String line, List<double> out) {
  for (final m in rx.allMatches(line)) {
    final v = _toNumber(m.group(group)!);
    if (v != null) out.add(v);
  }
}

List<double> _amountsInLine(String line) {
  final out = <double>[];
  _collectAmounts(_currencyRx, 1, line, out);
  _collectAmounts(_dollarRx, 1, line, out);
  _collectAmounts(_labelRx, 2, line, out);
  return out;
}

int _scoreAmount(String context, String line) {
  final t = context.toLowerCase();
  bool has(List<String> keys) => keys.any(t.contains);
  if (has(['saldo', 'balance', 'sisa'])) return 5;
  if (has(['admin', 'biaya', 'fee', 'ppn', 'pajak', 'tax'])) return 10;
  if (has(['nominal'])) return 100;
  if (has(['grand total'])) return 90;
  if (has(['total'])) return 85;
  if (has([
    'jumlah', 'amount', 'nilai', 'transfer', 'debit', 'kredit', 'bayar',
    'paid', 'pembayaran', 'tagihan', 'diterima', 'masuk'
  ])) {
    return 75;
  }
  if (RegExp(r'(?:Rp\.?|IDR|\$)', caseSensitive: false).hasMatch(line)) {
    return 40;
  }
  return 20;
}

double? _pickAmount(String text) {
  final lines = text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  _AmountCandidate? best;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final values = _amountsInLine(line);
    if (values.isEmpty) continue;
    final context = '${i > 0 ? lines[i - 1] : ''} $line';
    final score = _scoreAmount(context, line);
    for (final v in values) {
      if (v <= 0) continue;
      final c = _AmountCandidate(v, score);
      if (best == null ||
          c.score > best.score ||
          (c.score == best.score && c.value > best.value)) {
        best = c;
      }
    }
  }
  return best?.value;
}

double? parseAmount(String text) => _pickAmount(text);

String? _isoDate(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  return '${y.toString().padLeft(4, '0')}-'
      '${m.toString().padLeft(2, '0')}-'
      '${d.toString().padLeft(2, '0')}';
}

String? parseDate(String text) {
  var m = RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b').firstMatch(text);
  if (m != null) {
    return _isoDate(int.parse(m.group(1)!), int.parse(m.group(2)!),
        int.parse(m.group(3)!));
  }
  m = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b').firstMatch(text);
  if (m != null) {
    return _isoDate(int.parse(m.group(3)!), int.parse(m.group(2)!),
        int.parse(m.group(1)!));
  }
  m = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2})\b').firstMatch(text);
  if (m != null) {
    return _isoDate(2000 + int.parse(m.group(3)!), int.parse(m.group(2)!),
        int.parse(m.group(1)!));
  }
  m = RegExp(r'\b(\d{1,2})\s+([A-Za-z]{3,})\s+(\d{4})\b').firstMatch(text);
  if (m != null) {
    final month = _monthMap[m.group(2)!.toLowerCase()];
    if (month != null) {
      return _isoDate(int.parse(m.group(3)!), month, int.parse(m.group(1)!));
    }
  }
  return null;
}

bool _plausibleMerchant(String value) {
  final t = value.trim();
  if (t.length < 2 || t.length > 100) return false;
  if (_pickAmount(t) != null || parseDate(t) != null) return false;
  final lower = t.toLowerCase();
  if (_skipMerchant.any(lower.contains)) return false;
  if (RegExp(r'^[\d\s\-+*/#.,:]+$').hasMatch(t)) return false;
  return true;
}

String _cleanMerchant(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[:\-]+$'), '');

String? _valueAfterLabel(String line, List<String> labels) {
  final lower = line.toLowerCase();
  for (final label in labels) {
    final idx = lower.indexOf(label);
    if (idx == -1) continue;
    var rest = line.substring(idx + label.length).trim();
    rest = rest.replaceFirst(RegExp(r'^[:\-–]\s*'), '').trim();
    if (rest.isNotEmpty) return rest;
  }
  return null;
}

String? _extractMerchant(List<String> lines) {
  for (var i = 0; i < lines.length; i++) {
    final value = _valueAfterLabel(lines[i], _merchantLabels);
    if (value != null && _plausibleMerchant(value)) {
      return _cleanMerchant(value);
    }
    if (value == null && i + 1 < lines.length) {
      final lower = lines[i].toLowerCase().trim();
      final labelOnly = _merchantLabels.any(
          (l) => lower == l || lower == '$l:' || lower == '$l -');
      if (labelOnly && _plausibleMerchant(lines[i + 1])) {
        return _cleanMerchant(lines[i + 1]);
      }
    }
  }
  for (final line in lines.take(8)) {
    if (_plausibleMerchant(line)) return _cleanMerchant(line);
  }
  return null;
}

String? _detectType(String text) {
  final t = text.toLowerCase();
  final income = [
    'transfer masuk', 'dana masuk', 'uang masuk', 'diterima', 'received',
    'kredit', 'credit', 'gaji', 'salary', 'refund', 'pemasukan', 'top up',
    'topup',
  ];
  final expense = [
    'transfer keluar', 'dana keluar', 'debit', 'pembayaran', 'payment',
    'pembelian', 'purchase', 'qris', 'bayar', 'pengeluaran',
    'transfer berhasil',
  ];
  final isIncome = income.any(t.contains);
  final isExpense = expense.any(t.contains);
  if (isIncome && !isExpense) return 'income';
  if (isExpense) return 'expense';
  return null;
}

ReceiptResult parseReceipt(String fullText) {
  final lines = fullText
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  return ReceiptResult(
    merchant: _extractMerchant(lines),
    total: _pickAmount(fullText),
    date: parseDate(fullText),
    type: _detectType(fullText),
  );
}
