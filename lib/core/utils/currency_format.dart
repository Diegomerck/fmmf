import 'package:intl/intl.dart';

class CurrencyFormat {
  static final NumberFormat _mxnFormat = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 2,
  );

  static final NumberFormat _compactFormat = NumberFormat.compactCurrency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 1,
  );

  /// Formats amount in MXN currency: e.g. "$12,450.50"
  static String formatMXN(double amount, {bool includeDecimals = true}) {
    if (!includeDecimals) {
      final f = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 0);
      return f.format(amount);
    }
    return _mxnFormat.format(amount);
  }

  /// Compact representation for large amounts (e.g. "$1.2M", "$45.2K")
  static String formatCompact(double amount) {
    return _compactFormat.format(amount);
  }

  /// Format yield rate percentage (e.g. "13.50%")
  static String formatRate(double annualRatePercentage) {
    return '${annualRatePercentage.toStringAsFixed(2)}%';
  }
}
