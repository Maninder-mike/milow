import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../domain/models/driver_settlement.dart';
import '../domain/models/settlement_item.dart';

class SettlementPdfGenerator {
  static Future<Uint8List> generate(
    DriverSettlement settlement,
    String driverName,
  ) async {
    final pdf = pw.Document();

    final currencyFormat = NumberFormat.currency(symbol: r'$');
    final dateFormat = DateFormat('MM/dd/yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'MILOW SETTLEMENT',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Settlement ID: ${settlement.id.substring(0, 8).toUpperCase()}',
                    ),
                    pw.Text('Date: ${dateFormat.format(DateTime.now())}'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Driver Info and Period
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Driver',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(driverName),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Pay Period',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      '${dateFormat.format(settlement.startDate)} - ${dateFormat.format(settlement.endDate)}',
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Earnings Section
            pw.Text(
              'Earnings',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            _buildItemTable(
              settlement.items.where((i) => i.amount > 0).toList(),
              currencyFormat,
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Total Earnings: ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(currencyFormat.format(settlement.totalEarnings)),
              ],
            ),
            pw.SizedBox(height: 30),

            // Deductions Section
            pw.Text(
              'Deductions',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            _buildItemTable(
              settlement.items.where((i) => i.amount < 0).toList(),
              currencyFormat,
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Total Deductions: ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(currencyFormat.format(settlement.totalDeductions)),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 10),

            // Net Payout
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'NET PAYOUT: ',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  currencyFormat.format(settlement.netPayout),
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildItemTable(
    List<SettlementItem> items,
    NumberFormat currencyFormat,
  ) {
    if (items.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.Text(
          'No items in this section.',
          style: const pw.TextStyle(color: PdfColors.grey),
        ),
      );
    }

    return pw.TableHelper.fromTextArray(
      context: null,
      headers: ['Description', 'Amount'],
      data: items.map((item) {
        return [item.description, currencyFormat.format(item.amount)];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
      },
    );
  }
}
