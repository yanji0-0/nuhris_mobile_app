/// Shared employee initials logic used by all mobile avatars.
///
/// Initials are derived from [employee.first_name] and [employee.last_name]
/// so they stay consistent regardless of display-name formatting
/// (e.g. "Joseph Michael Aramil" vs "Aramil, Joseph Michael" both → JA).
String employeeInitialsFromAccount(Map<String, dynamic> account) {
  final user =
      (account['user'] as Map?)?.cast<String, dynamic>() ??
      const <String, dynamic>{};
  final employee =
      (account['employee'] as Map?)?.cast<String, dynamic>() ??
      const <String, dynamic>{};

  final firstName = (employee['first_name'] ?? '').toString().trim();
  final lastName = (employee['last_name'] ?? '').toString().trim();

  final fromEmployeeRecord = _initialsFromFirstAndLastName(
    firstName: firstName,
    lastName: lastName,
  );
  if (fromEmployeeRecord != null) {
    return fromEmployeeRecord;
  }

  final fallbackName = (user['name'] ?? '').toString().trim();
  return _initialsFromFullName(fallbackName);
}

String? _initialsFromFirstAndLastName({
  required String firstName,
  required String lastName,
}) {
  if (firstName.isEmpty && lastName.isEmpty) {
    return null;
  }

  if (firstName.isNotEmpty && lastName.isNotEmpty) {
    return (firstName[0] + lastName[0]).toUpperCase();
  }

  if (firstName.isNotEmpty) {
    return firstName.substring(0, 1).toUpperCase();
  }

  return lastName.substring(0, 1).toUpperCase();
}

String _initialsFromFullName(String name) {
  final cleaned = name.replaceAll(',', ' ').trim();
  if (cleaned.isEmpty) {
    return 'E';
  }

  final parts = cleaned
      .split(RegExp(r'\s+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) {
    return 'E';
  }

  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }

  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}
