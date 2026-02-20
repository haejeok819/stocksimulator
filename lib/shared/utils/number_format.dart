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


  static String formatKoreanSpokenWon(int value) {
    final bool isNegative = value < 0;
    final int absValue = value.abs();
    final String prefix = isNegative ? '-' : '';

    if (absValue == 0) return '0원';
    if (absValue == 100) return '${prefix}백원';
    if (absValue == 1000) return '${prefix}천원';
    if (absValue == 10000) return '${prefix}만원';

    if (absValue < 10000) {
      final String? underTenThousand = _formatUnderTenThousandSpoken(absValue);
      if (underTenThousand != null) {
        return '$prefix$underTenThousand';
      }
      return '$prefix${formatInt(absValue)}원';
    }

    if (absValue % 10000 != 0) {
      return '$prefix${formatInt(absValue)}원';
    }

    final int manTotal = absValue ~/ 10000;
    if (manTotal < 10000) {
      final String manText = _formatKoreanNumber(manTotal, dropOneAtHighestUnit: true);
      return '$prefix$manText만원';
    }

    final int eok = manTotal ~/ 10000;
    final int man = manTotal % 10000;
    final String eokText = '${_formatKoreanNumber(eok, dropOneAtHighestUnit: false)}억';
    if (man == 0) {
      return '$prefix$eokText원';
    }

    final String manText = '${_formatKoreanNumber(man, dropOneAtHighestUnit: true)}만';
    return '$prefix$eokText $manText원';
  }

  static String formatApproxKoreanSpokenWon(int value) {
    return '약 ${formatKoreanSpokenWon(value)}';
  }

  static String? _formatUnderTenThousandSpoken(int value) {
    if (value < 100 || value % 100 != 0) {
      return null;
    }

    if (value < 1000) {
      final int hundreds = value ~/ 100;
      final String hundredsText = hundreds == 1 ? '백' : '${_digitText(hundreds)}백';
      return '$hundredsText원';
    }

    if (value % 1000 == 0) {
      final int thousands = value ~/ 1000;
      final String thousandsText = thousands == 1 ? '천' : '${_digitText(thousands)}천';
      return '$thousandsText원';
    }

    return null;
  }

  static String _formatKoreanNumber(int value, {required bool dropOneAtHighestUnit}) {
    if (value <= 0) return '0';

    const List<String> digits = <String>['', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];
    const List<String> units = <String>['', '십', '백', '천'];

    String result = '';
    int number = value;
    int unitIndex = 0;

    while (number > 0 && unitIndex < units.length) {
      final int digit = number % 10;
      if (digit != 0) {
        final bool isHighestUnit = number < 10;
        final bool dropOne = digit == 1 && unitIndex > 0 && (!isHighestUnit || dropOneAtHighestUnit);
        final String digitText = dropOne ? '' : digits[digit];
        result = '$digitText${units[unitIndex]}$result';
      }
      number ~/= 10;
      unitIndex += 1;
    }

    return result;
  }

  static String _digitText(int digit) {
    return switch (digit) {
      1 => '일',
      2 => '이',
      3 => '삼',
      4 => '사',
      5 => '오',
      6 => '육',
      7 => '칠',
      8 => '팔',
      9 => '구',
      _ => '',
    };
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
