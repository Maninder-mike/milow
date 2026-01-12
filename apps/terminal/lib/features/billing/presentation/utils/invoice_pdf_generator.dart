import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:milow_core/milow_core.dart';
import '../../domain/models/invoice.dart';

/// Professional trucking invoice PDF generator
class InvoicePdfGenerator {
  static final currencyFormat = NumberFormat.currency(symbol: r'$');
  static final dateFormat = DateFormat('MMMM dd, yyyy');
  static final shortDateFormat = DateFormat('MM/dd/yyyy');

  // Brand colors
  static const primaryColor = PdfColor.fromInt(0xFF1a365d); // Dark navy
  static const accentColor = PdfColor.fromInt(0xFF2563eb); // Blue
  static const lightGray = PdfColor.fromInt(0xFFf8fafc);
  static const mediumGray = PdfColor.fromInt(0xFFe2e8f0);
  static const darkGray = PdfColor.fromInt(0xFF475569);

  /// Generate PDF and open it with the system viewer
  static Future<void> printInvoice(Invoice invoice, Company company) async {
    final pdf = _generatePdf(invoice, company);
    final bytes = await pdf.save();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Invoice_${invoice.invoiceNumber}.pdf');
    await file.writeAsBytes(bytes);

    final uri = Uri.file(file.path);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Generate PDF and save to temp directory
  static Future<String> savePdf(Invoice invoice, Company company) async {
    final pdf = _generatePdf(invoice, company);
    final bytes = await pdf.save();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Invoice_${invoice.invoiceNumber}.pdf');
    await file.writeAsBytes(bytes);

    return file.path;
  }

  static pw.Document _generatePdf(Invoice invoice, Company company) {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(0),
        build: (context) {
          return pw.Column(
            children: [
              // Header with navy background
              _buildHeader(invoice, company),

              // Main content with padding
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Invoice details and Bill To section
                      _buildInfoSection(invoice),
                      pw.SizedBox(height: 30),

                      // Shipment Details (if from a load)
                      if (invoice.loadId.isNotEmpty) ...[
                        _buildShipmentInfo(invoice),
                        pw.SizedBox(height: 20),
                      ],

                      // Line Items Table
                      _buildLineItemsTable(invoice),
                      pw.SizedBox(height: 20),

                      // Totals Section
                      _buildTotalsSection(invoice),

                      pw.Spacer(),

                      // Notes Section
                      if (invoice.notes.isNotEmpty) _buildNotesSection(invoice),

                      // Payment Terms
                      _buildPaymentTerms(invoice),
                    ],
                  ),
                ),
              ),

              // Footer
              _buildFooter(invoice, company),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildHeader(Invoice invoice, Company company) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 25),
      decoration: const pw.BoxDecoration(color: primaryColor),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Company Info
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                company.name,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  letterSpacing: 2,
                ),
              ),
              if (company.address != null) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  company.address!,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.white,
                  ),
                ),
              ],
              if (company.city != null &&
                  company.state != null &&
                  company.zipCode != null) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  '${company.city}, ${company.state} ${company.zipCode}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.white,
                  ),
                ),
              ],
              pw.SizedBox(height: 8),
              if (company.mcNumber != null || company.dotNumber != null)
                pw.Text(
                  '${company.mcNumber != null ? 'MC# ${company.mcNumber}' : ''} ${company.mcNumber != null && company.dotNumber != null ? ' | ' : ''} ${company.dotNumber != null ? 'DOT# ${company.dotNumber}' : ''}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey300,
                  ),
                ),
            ],
          ),
          // Invoice Title
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: 3,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                invoice.invoiceNumber,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoSection(Invoice invoice) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Bill To Section
        pw.Expanded(
          flex: 3,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              color: lightGray,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: mediumGray, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BILL TO',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: darkGray,
                    letterSpacing: 1,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  invoice.customerName ?? 'Customer',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                if (invoice.customerAddress != null &&
                    invoice.customerAddress!.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    invoice.customerAddress!,
                    style: const pw.TextStyle(fontSize: 10, color: darkGray),
                  ),
                ],
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 20),
        // Invoice Details
        pw.Expanded(
          flex: 2,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: mediumGray, width: 0.5),
            ),
            child: pw.Column(
              children: [
                _buildDetailRow(
                  'Invoice Date:',
                  shortDateFormat.format(invoice.issueDate),
                ),
                pw.Divider(color: mediumGray, height: 10),
                _buildDetailRow(
                  'Due Date:',
                  shortDateFormat.format(invoice.dueDate),
                ),
                pw.Divider(color: mediumGray, height: 10),
                _buildDetailRow(
                  'Terms:',
                  '${invoice.dueDate.difference(invoice.issueDate).inDays} Days',
                ),
                pw.Divider(color: mediumGray, height: 10),
                _buildDetailRow(
                  'Status:',
                  invoice.status.toUpperCase(),
                  valueColor: invoice.status == 'paid'
                      ? PdfColors.green700
                      : invoice.status == 'overdue'
                      ? PdfColors.red700
                      : accentColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildDetailRow(
    String label,
    String value, {
    PdfColor? valueColor,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: darkGray)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: valueColor ?? primaryColor,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildShipmentInfo(Invoice invoice) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: mediumGray, width: 0.5),
      ),
      child: pw.Column(
        children: [
          // Shipment Header
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const pw.BoxDecoration(
              color: mediumGray,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(3),
                topRight: pw.Radius.circular(3),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'SHIPMENT DETAILS',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.Row(
                  children: [
                    if (invoice.loadReference != null) ...[
                      pw.Text(
                        'Load #: ',
                        style: const pw.TextStyle(fontSize: 8, color: darkGray),
                      ),
                      pw.Text(
                        invoice.loadReference!,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                    if (invoice.poNumber != null &&
                        invoice.poNumber!.isNotEmpty) ...[
                      pw.SizedBox(width: 15),
                      pw.Text(
                        'PO #: ',
                        style: const pw.TextStyle(fontSize: 8, color: darkGray),
                      ),
                      pw.Text(
                        invoice.poNumber!,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Pickup and Delivery Row
          pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Pickup
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: pw.BoxDecoration(
                          color: const PdfColor.fromInt(0xFF059669),
                          borderRadius: pw.BorderRadius.circular(2),
                        ),
                        child: pw.Text(
                          'ORIGIN',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        invoice.pickupCompany ?? 'Unknown Shipper',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        invoice.formattedPickupAddress.isNotEmpty
                            ? invoice.formattedPickupAddress
                            : 'Unknown Address',
                        style: const pw.TextStyle(fontSize: 9, color: darkGray),
                      ),
                      if (invoice.pickupDate != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Pickup: ${shortDateFormat.format(invoice.pickupDate!)}',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: darkGray,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Arrow separator
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 15),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.SizedBox(height: 15),
                      pw.Text(
                        '>>>',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: mediumGray,
                        ),
                      ),
                    ],
                  ),
                ),

                // Delivery
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: pw.BoxDecoration(
                          color: const PdfColor.fromInt(0xFFDC2626),
                          borderRadius: pw.BorderRadius.circular(2),
                        ),
                        child: pw.Text(
                          'DESTINATION',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        invoice.deliveryCompany ?? 'Unknown Receiver',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        invoice.formattedDeliveryAddress.isNotEmpty
                            ? invoice.formattedDeliveryAddress
                            : 'Unknown Address',
                        style: const pw.TextStyle(fontSize: 9, color: darkGray),
                      ),
                      if (invoice.deliveryDate != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Delivery: ${shortDateFormat.format(invoice.deliveryDate!)}',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: darkGray,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Commodity and Weight row
          if (invoice.commodity != null || invoice.weight != null)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: const pw.BoxDecoration(
                color: lightGray,
                borderRadius: pw.BorderRadius.only(
                  bottomLeft: pw.Radius.circular(3),
                  bottomRight: pw.Radius.circular(3),
                ),
              ),
              child: pw.Row(
                children: [
                  if (invoice.commodity != null &&
                      invoice.commodity!.isNotEmpty) ...[
                    pw.Text(
                      'Commodity: ',
                      style: const pw.TextStyle(fontSize: 8, color: darkGray),
                    ),
                    pw.Text(
                      invoice.commodity!,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(width: 20),
                  ],
                  if (invoice.weight != null && invoice.weight! > 0) ...[
                    pw.Text(
                      'Weight: ',
                      style: const pw.TextStyle(fontSize: 8, color: darkGray),
                    ),
                    pw.Text(
                      '${invoice.weight!.toStringAsFixed(0)} ${invoice.weightUnit ?? 'lbs'}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildLineItemsTable(Invoice invoice) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: mediumGray, width: 0.5),
      ),
      child: pw.Column(
        children: [
          // Table Header
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: const pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(3),
                topRight: pw.Radius.circular(3),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Text(
                    'DESCRIPTION',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'RATE',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    'QTY',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'AMOUNT',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Table Rows
          ...invoice.lineItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isEven = index % 2 == 0;

            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: pw.BoxDecoration(
                color: isEven ? PdfColors.white : lightGray,
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          item.description,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (item.type.isNotEmpty)
                          pw.Text(
                            item.type,
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: darkGray,
                            ),
                          ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      currencyFormat.format(item.rate),
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      item.quantity.toStringAsFixed(
                        item.quantity == item.quantity.roundToDouble() ? 0 : 2,
                      ),
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      currencyFormat.format(item.total),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _buildTotalsSection(Invoice invoice) {
    return pw.Row(
      children: [
        pw.Spacer(flex: 3),
        pw.Expanded(
          flex: 2,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: mediumGray, width: 0.5),
            ),
            child: pw.Column(
              children: [
                // Subtotal
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Subtotal',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: darkGray,
                        ),
                      ),
                      pw.Text(
                        currencyFormat.format(invoice.subtotal),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Tax (if applicable)
                if (invoice.taxAmount > 0)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: mediumGray, width: 0.5),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Tax (${invoice.taxRate.toStringAsFixed(1)}%)',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: darkGray,
                          ),
                        ),
                        pw.Text(
                          currencyFormat.format(invoice.taxAmount),
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Total
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: const pw.BoxDecoration(
                    color: primaryColor,
                    borderRadius: pw.BorderRadius.only(
                      bottomLeft: pw.Radius.circular(3),
                      bottomRight: pw.Radius.circular(3),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'TOTAL DUE',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      pw.Text(
                        currencyFormat.format(invoice.totalAmount),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildNotesSection(Invoice invoice) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 15),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFFFBEB), // Light yellow
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFFFCD34D),
          width: 0.5,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'NOTES',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF92400E),
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            invoice.notes,
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromInt(0xFF78350F),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPaymentTerms(Invoice invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: lightGray,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PAYMENT INFORMATION',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: darkGray,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Please remit payment within ${invoice.dueDate.difference(invoice.issueDate).inDays} days.',
                  style: const pw.TextStyle(fontSize: 9, color: darkGray),
                ),
                pw.Text(
                  'Reference invoice ${invoice.invoiceNumber} with your payment.',
                  style: const pw.TextStyle(fontSize: 9, color: darkGray),
                ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: pw.BoxDecoration(
              color: invoice.status == 'paid'
                  ? const PdfColor.fromInt(0xFF059669)
                  : invoice.status == 'overdue'
                  ? const PdfColor.fromInt(0xFFDC2626)
                  : accentColor,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              invoice.status == 'paid'
                  ? 'PAID'
                  : invoice.status == 'overdue'
                  ? 'OVERDUE'
                  : 'PAYMENT DUE',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(Invoice invoice, Company company) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 15),
      decoration: const pw.BoxDecoration(
        color: lightGray,
        border: pw.Border(top: pw.BorderSide(color: mediumGray, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Thank you for your business!',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          if (company.website != null)
            pw.Text(
              company.website!,
              style: const pw.TextStyle(fontSize: 9, color: darkGray),
            ),
        ],
      ),
    );
  }
}
