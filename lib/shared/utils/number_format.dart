import 'package:intl/intl.dart';

class AppNumberFormat {
  AppNumberFormat._();

  static final NumberFormat _intFormatter = NumberFormat('#,###', 'en_US');

  static String formatInt(num value) {
    return _intFormatter.format(value.round());
  }

  static String formatMoney(num value, {String symbol = '₩ '}) {
    return '$symbol${formatInt(value)}';
  }

  static String formatPrice(num value, {int decimals = 0}) {
    final NumberFormat formatter = NumberFormat('#,##0${decimals > 0 ? '.${'0' * decimals}' : ''}', 'en_US');
    final num target = decimals == 0 ? value.round() : value;
    return formatter.format(target);
  }

  static String formatPercent(num value, {int decimals = 2, bool signed = true}) {
    final NumberFormat formatter = NumberFormat('#,##0.${'0' * decimals}', 'en_US');
    final String sign = signed ? (value >= 0 ? '+' : '') : '';
    return '$sign${formatter.format(value)}%';
  }

  static String formatPercentPoint(num value, {int decimals = 2, bool signed = false}) {
    final NumberFormat formatter = NumberFormat('#,##0.${'0' * decimals}', 'en_US');
    final String sign = signed ? (value >= 0 ? '+' : '') : '';
    return '$sign${formatter.format(value)}%p';
  }
}
