import 'package:intl/intl.dart';

const String kCurrencySymbol = '₹';

String formatAmount(double amount) {
  final formatter = NumberFormat('#,##0.00');
  return '$kCurrencySymbol${formatter.format(amount)}';
}

String formatAmountCompact(double amount) {
  if (amount >= 1000000) {
    return '$kCurrencySymbol${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (amount >= 1000) {
    return '$kCurrencySymbol${(amount / 1000).toStringAsFixed(1)}K';
  }
  return formatAmount(amount);
}

String formatBalance(double amount) {
  if (amount == 0) return 'Settled up';
  final formatted = formatAmount(amount.abs());
  return amount > 0 ? '+$formatted' : '-$formatted';
}
