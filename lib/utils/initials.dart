String twoLetterInitials({String? firstName, String? lastName, String? displayName}) {
  String f = (firstName ?? '').trim();
  String l = (lastName ?? '').trim();
  if (f.isNotEmpty && l.isNotEmpty) {
    // Prefer First then Last -> "MR" for Michael Ramillo
    return ('${f[0]}${l[0]}').toUpperCase();
  }
  if (displayName != null && displayName.trim().isNotEmpty) {
    final parts = displayName.trim().split(RegExp(r"\s+"));
    if (parts.length == 1) {
      final p = parts.first;
      if (p.length >= 2) return p.substring(0, 2).toUpperCase();
      return p.substring(0, 1).toUpperCase();
    }
    // Use first letter of first and first letter of last (First+Last)
    final first = parts.first;
    final last = parts.length > 1 ? parts.last : '';
    final a = (first.isNotEmpty ? first[0] : (last.isNotEmpty ? last[0] : ''));
    final b = (last.isNotEmpty ? last[0] : (first.isNotEmpty ? first[0] : ''));
    return (('$a$b').toUpperCase());
  }
  return 'N';
}
