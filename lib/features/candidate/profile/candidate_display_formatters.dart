String titleCase(String value) {
  return value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) {
    final lower = word.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }).join(' ');
}

String salaryText({
  required String currency,
  required int? min,
  required int? max,
}) {
  if (min == null && max == null) return 'Not set';
  if (min != null && max != null && min == max) return '$currency $min';
  if (min == null) return '$currency $max';
  if (max == null) return '$currency $min';
  return '$currency $min - $max';
}

String displayOrNotSet(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? 'Not set' : titleCase(trimmed);
}
