/// Display/API money strings without spurious ".00" for whole rupee amounts.
class MoneyFormat {
  MoneyFormat._();

  static String display(dynamic value) {
    if (value == null) return '0';
    final raw = value.toString().trim();
    if (raw.isEmpty) return '0';
    final n = double.tryParse(raw);
    if (n == null) {
      if (raw.endsWith('.00')) return raw.substring(0, raw.length - 3);
      return raw;
    }
    if ((n - n.roundToDouble()).abs() < 1e-9) return n.round().toString();
    final fixed = n.toStringAsFixed(2);
    return fixed.replaceAll(RegExp(r'\.?0+$'), '');
  }

  static double parseAmount(dynamic value) {
    return double.tryParse(display(value)) ?? 0;
  }
}
