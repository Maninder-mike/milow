class TripParserService {
  static Map<String, dynamic> parse(String text) {
    final result = <String, dynamic>{};

    // Extract Trip Number
    final tripMatch = RegExp(r'Trip#\s*(\S+)').firstMatch(text);
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
    // Also cleaning up P/Up Ref and Ph# lines if they appear
    final pickMatch = RegExp(
      r'Pick #1\n(.*?)(?=\nDate)',
      dotAll: true,
    ).firstMatch(text);
    if (pickMatch != null) {
      String rawAddress = pickMatch.group(1)?.trim() ?? '';
      // Extract metadata lines like Ph# or Ref to append to notes later
      final metadataLines = <String>[];
      rawAddress = rawAddress.split('\n').where((line) {
        if (line.contains('Ph#') || line.contains('Ref')) {
          metadataLines.add(line.trim());
          return false;
        }
        return true;
      }).join(', ');
      
      result['startLocation'] = rawAddress.trim();
      if (metadataLines.isNotEmpty) {
        result['startMetadata'] = metadataLines;
      }
    }

    // Extract Drop Off (End Location)
    final dropMatch = RegExp(
      r'Drop #1\n(.*?)(?=\nDate)',
      dotAll: true,
    ).firstMatch(text);
    if (dropMatch != null) {
      String rawAddress = dropMatch.group(1)?.trim() ?? '';
      final metadataLines = <String>[];
      rawAddress = rawAddress.split('\n').where((line) {
        if (line.contains('Ph#') || line.contains('Ref')) {
          metadataLines.add(line.trim());
          return false;
        }
        return true;
      }).join(', ');
      
      result['endLocation'] = rawAddress.trim();
      if (metadataLines.isNotEmpty) {
        result['endMetadata'] = metadataLines;
      }
    }

    // Extract Date/Time from Pick #1 section - Handle MM/DD/YYYY or similar
    final pickDateMatch = RegExp(
      r'Pick #1.*?Date\s+(\d{1,2}/\d{1,2}/(?:\d{2}|\d{4}))\s+Time\s+([^\n]+)',
      dotAll: true,
    ).firstMatch(text);

    if (pickDateMatch != null) {
      try {
        final dateStr = pickDateMatch.group(1)!;
        // Take start time if range is provided (7AM - 4PM -> 7AM)
        final timeRaw = pickDateMatch.group(2)!;
        final timeStr = timeRaw.split('-')[0].split('to')[0].trim();

        String normalizedTime = timeStr;
        // Normalize 7AM -> 7:00 AM
        if (!timeStr.contains(':')) {
          normalizedTime = timeStr.replaceAllMapped(
            RegExp(r'(\d+)\s*([AP]M)', caseSensitive: false),
            (m) => '${m[1]}:00 ${m[2]!.toUpperCase()}',
          );
        }

        result['date'] = '$dateStr $normalizedTime';
      } catch (e) {
        // Ignore parsing errors
      }
    }

    // Extract all Notes and merge with metadata
    final allNotes = <String>[];

    // Find all "Notes" sections
    final notesPattern = RegExp(
      r'Notes\s+(.+?)(?=\n(?:Pick|Drop|Truck|Trip|P/Up|$))',
      dotAll: true,
      caseSensitive: false,
    );
    final notesMatches = notesPattern.allMatches(text);

    for (final match in notesMatches) {
      final noteText = match.group(1)?.trim();
      if (noteText != null && noteText.isNotEmpty) {
        allNotes.add(noteText);
      }
    }

    // Add metadata collected from address blocks
    if (result['startMetadata'] != null) {
      allNotes.addAll(List<String>.from(result['startMetadata']));
    }
    if (result['endMetadata'] != null) {
      allNotes.addAll(List<String>.from(result['endMetadata']));
    }

    // Generic check for P/Up Ref outside notes block
    final refPattern = RegExp(r'P/Up Ref\s+(.+)');
    final refMatches = refPattern.allMatches(text);
    for (final match in refMatches) {
      final ref = match.group(1)?.trim();
      if (ref != null && !allNotes.contains('P/Up Ref $ref')) {
        allNotes.add('P/Up Ref $ref');
      }
    }

    if (allNotes.isNotEmpty) {
      result['notes'] = allNotes.join('\n');
    }

    return result;
  }
}
