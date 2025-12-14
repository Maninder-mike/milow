import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ScannedFuelData {
  final DateTime? date;
  final double? totalCost;
  final double? volume;
  final String? vendor;

  ScannedFuelData({this.date, this.totalCost, this.volume, this.vendor});

  @override
  String toString() {
    return 'ScannedFuelData(date: $date, total: $totalCost, vol: $volume, vendor: $vendor)';
  }
}

class ReceiptScannerService {
  static final ReceiptScannerService _instance =
      ReceiptScannerService._internal();
  static ReceiptScannerService get instance => _instance;

  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  ReceiptScannerService._internal();

  /// Scans a receipt image and extracts fuel data
  Future<ScannedFuelData> scanReceipt(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return _parseRecognizedText(recognizedText);
    } catch (e) {
      debugPrint('Error scanning receipt: $e');
      rethrow;
    }
  }

  ScannedFuelData _parseRecognizedText(RecognizedText recognizedText) {
    DateTime? date;
    double? totalCost;
    double? volume;
    String? vendor;

    // Sort blocks by vertical position to help identify vendor (usually at top)
    final blocks = recognizedText.blocks;
    blocks.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    // 1. Vendor Heuristic: Top 3 lines usually contain vendor name.
    // Avoid generic headers like "Welcome" or "Receipt".
    if (blocks.isNotEmpty) {
      for (int i = 0; i < blocks.length && i < 3; i++) {
        final text = blocks[i].text.trim();
        if (_isValidVendorCandidate(text)) {
          vendor = text.split('\n').first; // Take the first line of the block
          break;
        }
      }
    }

    // 2. Parse all lines for data
    final allTextLines = <String>[];
    for (var block in blocks) {
      for (var line in block.lines) {
        allTextLines.add(line.text);
      }
    }

    for (final line in allTextLines) {
      // Date Parsing
      date ??= _parseDate(line);

      // Volume (Gallons/Liters)
      // Look for keywords: Gal, Gallons, L, Liter
      if (volume == null && _isVolumeLine(line)) {
        volume = _extractDouble(line);
      }

      // Total Cost
      // Look for keywords: Total, Amount, USD, $
      // But act carefully, as Price/Gal also looks like money.
      // Usually "Total" is explicit.
      if (totalCost == null && _isTotalLine(line)) {
        totalCost = _extractDouble(line);
      }
    }

    // Fallback: If total found but no volume, try to find the biggest other number?
    // Or if checking "Pump" or "Price".
    // For now, keep it simple. If we missed strict keywords, we might try looser matches later.

    return ScannedFuelData(
      date: date,
      totalCost: totalCost,
      volume: volume,
      vendor: vendor,
    );
  }

  bool _isValidVendorCandidate(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('welcome')) return false;
    if (lower.contains('receipt')) return false;
    if (lower.length < 3) return false;
    // Check if it's just digits
    if (RegExp(r'^\d+$').hasMatch(text)) return false;
    return true;
  }

  DateTime? _parseDate(String line) {
    // Regex for:
    // MM/DD/YYYY or MM-DD-YYYY or YYYY-MM-DD
    // Also simplified: 12/05/2025
    try {
      final dateRegex = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})');
      final match = dateRegex.firstMatch(line);
      if (match != null) {
        final int p1 = int.parse(match.group(1)!);
        final int p2 = int.parse(match.group(2)!);
        final int p3 = int.parse(match.group(3)!);

        // Ambiguity check: US format usually Month first.
        // If p1 > 12, it's day (or year if p1 is large).
        // Standardize on assuming Month/Day/Year or Month-Day-Year if ambiguous.
        // If year is p3 (2 or 4 digits):
        int year = p3;
        int month = p1;
        int day = p2;

        if (year < 100) year += 2000; // Assume 21st century

        // Validation
        if (month > 12 && day <= 12) {
          // Swap
          final temp = month;
          month = day;
          day = temp;
        }

        return DateTime(year, month, day);
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  bool _isVolumeLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('gal') ||
        lower.contains('liter') ||
        lower.contains('vol');
  }

  bool _isTotalLine(String line) {
    final lower = line.toLowerCase();
    // Exclude "Subtotal" if we want final total, but usually total is fine.
    // Exclude "Price" (price per gallon).
    if (lower.contains('price') && !lower.contains('total')) return false;
    return lower.contains('total') ||
        lower.contains('amount') ||
        lower.contains('final');
  }

  double? _extractDouble(String line) {
    // Extract something looking like 123.45
    // Handle $ symbol
    try {
      final regex = RegExp(r'\d+\.\d{2,3}');
      final match = regex.firstMatch(line);
      if (match != null) {
        return double.parse(match.group(0)!);
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
