class InputSanitizer {
  /// Strips HTML/XML tags and common XSS vectors from user-provided text.
  static String sanitizeText(String? input) {
    if (input == null || input.isEmpty) return '';
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('javascript:', '')
        .trim();
  }

  /// Sanitizes an email address — lowercases and strips dangerous characters.
  static String sanitizeEmail(String? input) {
    if (input == null || input.isEmpty) return '';
    return input.trim().toLowerCase().replaceAll(RegExp(r'[^\w@.+\-]'), '');
  }

  /// Sanitizes a display name — allows Unicode letters, digits, spaces,
  /// hyphens, apostrophes, periods, and underscores. Strips HTML/control chars.
  static String sanitizeDisplayName(String? input) {
    if (input == null || input.isEmpty) return '';
    return input
        .trim()
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\p{C}\p{Zl}\p{Zp}]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Sanitizes a monetary amount string, returns valid double or null.
  static double? sanitizeAmount(String? input) {
    if (input == null || input.isEmpty) return null;
    return double.tryParse(input.replaceAll(RegExp(r'[^0-9.\-]'), ''));
  }

  /// Truncates a string to a maximum length.
  static String truncate(String? input, int maxLength) {
    if (input == null) return '';
    if (input.length <= maxLength) return input;
    return input.substring(0, maxLength);
  }
}
