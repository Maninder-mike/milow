class AddressUtils {
  /// Extract city and state/province from address
  /// Returns format: "City ST" (e.g., "Vaughan ON" or "Irwindale CA")
  /// SPECIAL CASE: Returns "Yard" if address contains "11621 COLD CREEK ROAD VAUGHAN ON (Yard)"
  static String extractCityState(String address) {
    if (address.isEmpty) return address;

    // Special case for specific yard address
    if (address.toUpperCase().contains(
      '11621 COLD CREEK ROAD VAUGHAN ON (YARD)',
    )) {
      return 'Yard';
    }

    // Normalize: replace newlines with commas for easier parsing
    final normalized = address
        .replaceAll('\n', ', ')
        .replaceAll(RegExp(r',\s*,'), ',');

    // Pattern 1: Match "CITY STATE ZIP" at end of segment
    // e.g., "IRWINDALE CA 91702" or "CHARLOTTETOWN PE C1E 0K4"
    final dispatchPattern = RegExp(
      r'([A-Z][A-Z\s]*?)\s+([A-Z]{2})\s+[A-Z0-9]{3,7}(?:\s*[A-Z0-9]{0,4})?\s*$',
      caseSensitive: false,
    );

    final segments = normalized.split(',');
    for (final segment in segments) {
      final trimmed = segment.trim();
      final dispatchMatch = dispatchPattern.firstMatch(trimmed.toUpperCase());
      if (dispatchMatch != null) {
        // Get the last word(s) before state - extract city from end
        final rawCity = dispatchMatch.group(1)!.trim();
        final city = _extractLastCity(rawCity);
        final state = dispatchMatch.group(2)!.toUpperCase();
        return '$city $state';
      }
    }

    // Pattern 2: Match "CITY STATE" followed by ( or end (e.g., "VAUGHAN ON (Yard)")
    final cityStateParenPattern = RegExp(
      r'([A-Z][A-Z\s]*?)\s+([A-Z]{2})\s*(?:\(|$)',
      caseSensitive: false,
    );
    for (final segment in segments) {
      final trimmed = segment.trim();
      final match = cityStateParenPattern.firstMatch(trimmed.toUpperCase());
      if (match != null) {
        final rawCity = match.group(1)!.trim();
        final city = _extractLastCity(rawCity);
        final state = match.group(2)!.toUpperCase();
        return '$city $state';
      }
    }

    // Pattern 3: Standard format "City, ST" or "City, ST ZIP"
    final cityStatePattern = RegExp(
      r'([A-Za-z][A-Za-z\s]+?),\s*([A-Z]{2})(?:\s+[A-Z0-9\s-]+)?(?:,|$)',
      caseSensitive: false,
    );
    final match = cityStatePattern.firstMatch(normalized);
    if (match != null) {
      final city = toTitleCase(match.group(1)!.trim());
      final state = match.group(2)!.toUpperCase();
      return '$city $state';
    }

    // Fallback: just return first non-numeric part abbreviated
    final parts = normalized.split(',');
    for (final part in parts) {
      final trimmed = part.trim();
      if (!RegExp(r'^\d').hasMatch(trimmed) && trimmed.isNotEmpty) {
        return trimmed.length > 20 ? '${trimmed.substring(0, 17)}...' : trimmed;
      }
    }

    return address.length > 20 ? '${address.substring(0, 17)}...' : address;
  }

  /// Format address for PDF export
  /// Returns "Yard" for specific yard address, otherwise returns full address
  static String formatForPdf(String address) {
    if (address.isEmpty) return address;

    // Special case for specific yard address - same check as extractCityState
    if (address.toUpperCase().contains(
      '11621 COLD CREEK ROAD VAUGHAN ON (YARD)',
    )) {
      return 'yard'; // Lowercase 'yard' as per user image requirement
    }

    return address;
  }

  /// Extract the actual city name from a string that might include street names
  /// e.g., "COLD CREEK ROAD VAUGHAN" -> "Vaughan"
  /// e.g., "QUEBEC CITY" -> "Quebec City"
  static String _extractLastCity(String raw) {
    final words = raw.split(RegExp(r'\s+'));
    if (words.isEmpty) return toTitleCase(raw);

    // Common street suffixes to skip
    final streetSuffixes = {
      'ROAD',
      'RD',
      'STREET',
      'ST',
      'AVENUE',
      'AVE',
      'BLVD',
      'BOULEVARD',
      'DRIVE',
      'DR',
      'LANE',
      'LN',
      'WAY',
      'COURT',
      'CT',
      'PLACE',
      'PL',
      'CIRCLE',
      'CIR',
      'HIGHWAY',
      'HWY',
      'ROUTE',
      'RTE',
      'PARKWAY',
      'PKWY',
    };

    // Find the last street suffix and take everything after it
    int lastStreetIndex = -1;
    for (int i = 0; i < words.length; i++) {
      if (streetSuffixes.contains(words[i].toUpperCase())) {
        lastStreetIndex = i;
      }
    }

    if (lastStreetIndex >= 0 && lastStreetIndex < words.length - 1) {
      // Take everything after the last street suffix
      final cityWords = words.sublist(lastStreetIndex + 1);
      return toTitleCase(cityWords.join(' '));
    }

    // If no street suffix found, check if first word looks like a number (street address)
    if (words.length > 1 && RegExp(r'^\d').hasMatch(words.first)) {
      // Skip the street number and take the last 1-2 words as city
      final cityWords = words.length > 2
          ? words.sublist(words.length - 2)
          : [words.last];
      // But if second-to-last is a street suffix, just take last word
      if (cityWords.length > 1 &&
          streetSuffixes.contains(cityWords.first.toUpperCase())) {
        return toTitleCase(cityWords.last);
      }
      return toTitleCase(cityWords.join(' '));
    }

    // Return the whole thing as city (e.g., "QUEBEC CITY")
    return toTitleCase(raw);
  }

  static String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }
}
