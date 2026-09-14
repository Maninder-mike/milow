import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:milow_data/milow_data.dart';

/// Pure Dart client-side Rate Confirmation PDF generator ($0 external API cost).
class RateConGenerator {
  const RateConGenerator();

  /// Builds a PDF byte buffer for the provided [load].
  static Future<Uint8List> generatePdf({
    required LoadModel load,
    String brokerName = 'Milow Freight Logistics',
    String carrierName = 'Independent Carrier',
    String terms = 'Standard 30-day payment terms. Driver signature required upon delivery.',
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Banner
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        brokerName,
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text('Rate Confirmation & Tender',
                          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Load #: ${load.loadNumber}',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: ${DateTime.now().toString().split(' ')[0]}',
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5),
              pw.SizedBox(height: 12),

              // Carrier & Rate Summary
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Container(
                    width: 250,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('CARRIER INFORMATION',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('Name: $carrierName', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Status: ${load.status.toUpperCase()}',
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  pw.Container(
                    width: 250,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      border: pw.Border.all(color: PdfColors.blue300),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('AGREED RATE PAYOUT',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '\$${(load.rate ?? 0.0).toStringAsFixed(2)} USD',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Stop Itinerary Table
              pw.Text('STOP ITINERARY & SCHEDULE',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['Seq', 'Type', 'Location', 'Address', 'City, State'],
                data: load.stops.map((stop) {
                  return [
                    '#${stop.sequenceId}',
                    stop.stopType.toUpperCase(),
                    stop.locationName,
                    stop.address,
                    '${stop.city ?? ''}, ${stop.state ?? ''}',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellHeight: 24,
                cellStyle: const pw.TextStyle(fontSize: 9),
              ),
              pw.Spacer(),

              // Terms & Signature Line
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('TERMS & CONDITIONS',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text(terms, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(width: 200, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 4),
                      pw.Text('Authorized Dispatcher Signature',
                          style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(width: 200, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 4),
                      pw.Text('Carrier Driver Acceptance Signature',
                          style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
