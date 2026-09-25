/// Turns what someone typed into the international form Firebase needs
/// (`+8801711204488`), or null if it cannot be a mobile number.
///
/// People write a Bangladeshi number as `01711 204488`, `01711-204488`,
/// `8801711204488` or `+880 1711 204488`; all four mean the same phone. Firebase
/// test numbers only match the exact international string, so the screen
/// normalises before sending.
String? normalizePhone(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'[\s\-().]'), '');
  if (s.isEmpty) return null;

  if (s.startsWith('+')) {
    // Already international: keep the digits after the plus sign.
    final digits = s.substring(1);
    return RegExp(r'^\d{8,15}$').hasMatch(digits) ? '+$digits' : null;
  }
  if (!RegExp(r'^\d+$').hasMatch(s)) return null;

  // Bangladesh: 01XXXXXXXXX, 1XXXXXXXXX or 8801XXXXXXXXX.
  if (s.startsWith('880')) s = s.substring(3);
  if (s.startsWith('0')) s = s.substring(1);
  if (RegExp(r'^1[3-9]\d{8}$').hasMatch(s)) return '+880$s';
  return null;
}

/// A number for display: `+880 1711 204488`.
String formatPhone(String e164) {
  if (e164.startsWith('+880') && e164.length == 14) {
    return '+880 ${e164.substring(4, 8)} ${e164.substring(8)}';
  }
  return e164;
}
