/// Groups digits in thousands: 1234567 -> 1,234,567
String _group(String digits) {
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
    b.write(digits[i]);
  }
  return b.toString();
}

/// Human-friendly number: grouped thousands, up to [maxDecimals] decimals,
/// trailing zeros trimmed, scientific notation for extreme magnitudes.
String fmtNum(double v, {int maxDecimals = 4, bool group = true}) {
  if (v.isNaN || v.isInfinite) return '--';
  if (v != 0 && (v.abs() >= 1e12 || v.abs() < 1e-6)) {
    return v.toStringAsExponential(4);
  }
  var s = v.abs().toStringAsFixed(maxDecimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  final parts = s.split('.');
  final whole = group ? _group(parts[0]) : parts[0];
  final out = parts.length > 1 ? '$whole.${parts[1]}' : whole;
  return (v < 0 && out != '0') ? '-$out' : out;
}

/// Parses user input tolerant of commas ("1,234.5" or "1,5").
double? parseNum(String s) {
  var t = s.trim().replaceAll(' ', '');
  if (t.isEmpty) return null;
  if (t.contains(',') && !t.contains('.')) {
    // "1,5" -> decimal comma; "1,234" is ambiguous, treat as thousands.
    final i = t.lastIndexOf(',');
    t = (t.length - i - 1 == 3 && t.indexOf(',') == i && i > 0)
        ? t.replaceAll(',', '')
        : t.replaceAll(',', '.');
  } else {
    t = t.replaceAll(',', '');
  }
  return double.tryParse(t);
}
