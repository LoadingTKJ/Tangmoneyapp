import 'package:intl/intl.dart';

String formatCurrency(
  double amount,
  String currency, {
  bool withSymbol = true,
  bool showSign = false,
}) {
  final NumberFormat formatter = NumberFormat.currency(
    symbol: withSymbol ? '$currency ' : '',
    decimalDigits: 2,
  );
  if (showSign) {
    return (amount < 0 ? '-' : '+') + formatter.format(amount.abs()).trim();
  }
  return formatter.format(amount).trim();
}

String formatDate(DateTime date) {
  final DateFormat fmt = DateFormat('yyyy-MM-dd');
  return fmt.format(date);
}
