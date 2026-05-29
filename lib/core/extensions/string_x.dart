extension StringX on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String get titleCase => split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');

  String get initial {
    final t = trim();
    return t.isEmpty ? '?' : t[0].toUpperCase();
  }

  String? get nullIfBlank {
    final t = trim();
    return t.isEmpty ? null : t;
  }

  bool get isBlank => trim().isEmpty;
  bool get isNotBlank => trim().isNotEmpty;
}

extension NullableStringX on String? {
  bool get isNullOrBlank => this == null || this!.trim().isEmpty;
  String orEmpty() => this ?? '';
  String orDefault(String fallback) =>
      (this == null || this!.trim().isEmpty) ? fallback : this!;
}
