import 'package:intl/intl.dart';

// Formats numbers as Rupiah, keeping decimals only when present.
String formatRupiah(num value) {
  final hasFraction = value != value.roundToDouble();
  final formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: hasFraction ? 2 : 0,
  );
  return formatter.format(value);
}
