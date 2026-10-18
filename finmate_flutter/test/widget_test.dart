import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/receipt_parser.dart';

void main() {
  test('receipt parser extracts total and merchant', () {
    final r = parseReceipt('TOKO MAJU\nJl. Sudirman\nTotal: Rp 50.000\n2026-10-01');
    expect(r.total, 50000);
    expect(r.merchant, contains('TOKO'));
    expect(r.date, '2026-10-01');
  });

  test('amount parser handles USD', () {
    expect(parseAmount('Total \$12.34'), closeTo(12.34, 0.001));
  });
}
