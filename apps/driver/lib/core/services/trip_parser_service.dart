class TripParserService {
  static Map<String, dynamic> parse(String text) {
    final result = <String, dynamic>{};

    // Extract Trip Number
    final tripMatch = RegExp(r'Trip#\s*(\d+)').firstMatch(text);
    if (tripMatch != null) {
      result['tripNumber'] = tripMatch.group(1);
    }

    // Extract Truck Number
    final truckMatch = RegExp(r'Truck#\s*(\S+)').firstMatch(text);
    if (truckMatch != null) {
      result['truckNumber'] = truckMatch.group(1);
    }

    // Extract Trailer Number
    final trailerMatch = RegExp(
      r'Trailer\s*[#:]\s*(\S+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (trailerMatch != null) {
      result['trailerNumber'] = trailerMatch.group(1);
    }

    // Extract Pick Up (Start Location)
    // Looking for "Pick #1" followed by address lines until "Date"
    final pickMatch = RegExp(
      r'Pick #\d+\n(.*?)\nDate',
      dotAll: true,
    ).firstMatch(text);
    if (pickMatch != null) {
      final rawAddress = pickMatch.group(1)?.trim() ?? '';
      // Remove the company name (first line) if it looks like one, or keep it as part of address
      // For now, we'll use the whole block as the address, but maybe clean up newlines
      result['startLocation'] = rawAddress.replaceAll('\n', ', ');
    }

    // Extract Drop Off (End Location)
    final dropMatch = RegExp(
      r'Drop #\d+\n(.*?)\nDate',
      dotAll: true,
    ).firstMatch(text);
    if (dropMatch != null) {
      final rawAddress = dropMatch.group(1)?.trim() ?? '';
      result['endLocation'] = rawAddress.replaceAll('\n', ', ');
    }

    // Extract Date/Time from Pick #1 section
    final pickDateMatch = RegExp(
      r'Pick #1.*?Date\s+(\d{1,2}/\d{1,2}/\d{4})\s+Time\s+([^\n]+)',
      dotAll: true,
    ).firstMatch(text);

    if (pickDateMatch != null) {
      try {
        final dateStr = pickDateMatch.group(1)!;
        final timeStr = pickDateMatch
            .group(2)!
            .split('-')[0]
            .trim(); // Take start time

        String normalizedTime = timeStr;
        if (!timeStr.contains(':')) {
          normalizedTime = timeStr.replaceAllMapped(
            RegExp(r'(\d+)([AP]M)'),
            (m) => '${m[1]}:00 ${m[2]}',
          );
        }

        final dateTimeStr = '$dateStr $normalizedTime';
        result['date'] = dateTimeStr;
      } catch (e) {
        // Ignore parsing errors
      }
    }

    // Extract all Notes - collect from both Pick and Drop sections
    final allNotes = <String>[];

    // Find all "Notes" sections and extract their content
    final notesPattern = RegExp(
      r'Notes\s+(.+?)(?=\n(?:Pick|Drop|Truck|Trip|$))',
      dotAll: true,
    );
    final notesMatches = notesPattern.allMatches(text);

    for (final match in notesMatches) {
      final noteText = match.group(1)?.trim();
      if (noteText != null && noteText.isNotEmpty) {
        allNotes.add(noteText);
      }
    }

    if (allNotes.isNotEmpty) {
      result['notes'] = allNotes.join('\n');
    }

    return result;
  }
}
