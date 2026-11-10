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

  test('parses m-banking transfer screenshot', () {
    final r = parseReceipt('BCA mobile\nTransfer Berhasil\nKe Rekening\n'
        'BUDI SANTOSO\n1234567890\nNominal\nRp100.000\n'
        'Biaya Admin Rp2.500\nTotal Rp102.500\nSaldo Rp900.000\n'
        '03/11/2026');
    expect(r.total, 100000);
    expect(r.merchant, 'BUDI SANTOSO');
    expect(r.date, '2026-11-03');
    expect(r.type, 'expense');
  });
}
