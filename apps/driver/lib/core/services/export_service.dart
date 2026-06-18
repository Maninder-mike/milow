import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:milow/core/utils/address_utils.dart';
import 'package:milow/core/utils/unit_utils.dart';
import 'package:milow/core/services/preferences_service.dart';
import 'package:milow_core/milow_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ExportService {
  static Future<String> generateCSV({
    required List<Map<String, dynamic>> records,
    required String distanceUnit,
    required String fuelUnit,
  }) async {
    // Prepare CSV data
    final List<List<dynamic>> rows = [];

    // Add Header
    rows.add([
      'Date',
      'Type',
      'ID/Truck',
      'Description/Location',
      'Distance/Quantity',
      'Unit',
      'Cost',
      'Notes',
      'From',
      'To',
      'Odometer',
    ]);

    // Add Rows
    for (var record in records) {
      final date = DateFormat('yyyy-MM-dd').format(record['rawDate']);
      final type = record['type'] == 'trip' ? 'Trip' : 'Fuel';
      final data = record['data'];

      if (record['type'] == 'trip') {
        final trip = data as Trip;
        double distanceVal = trip.totalDistance ?? 0;
        if (trip.distanceUnit != distanceUnit) {
          distanceVal = distanceUnit == 'km'
              ? UnitUtils.milesToKm(distanceVal)
              : UnitUtils.kmToMiles(distanceVal);
        }
        final distance =
            trip.totalDistance != null ? distanceVal.toStringAsFixed(1) : '';
        final unit = distanceUnit;
        final from = trip.pickupLocations.isNotEmpty
            ? AddressUtils.formatForPdf(trip.pickupLocations.first)
            : '';
        final to = trip.deliveryLocations.isNotEmpty
            ? AddressUtils.formatForPdf(trip.deliveryLocations.last)
            : '';

        rows.add([
          date,
          type,
          'Trip #${trip.tripNumber}',
          trip.notes ?? '',
          distance,
          unit,
          '', // Cost
          trip.notes ?? '',
          from,
          to,
          '', // Odometer
        ]);
      } else {
        final fuel = data as FuelEntry;
        double qty = fuel.fuelQuantity;
        if (fuel.fuelUnit != fuelUnit) {
          qty = fuelUnit == 'L'
              ? UnitUtils.gallonsToLiters(qty)
              : UnitUtils.litersToGallons(qty);
        }
        final quantity = qty.toStringAsFixed(1);
        final unit = fuelUnit;
        final cost = fuel.totalCost.toStringAsFixed(2);
        final truck = fuel.isTruckFuel
            ? (fuel.truckNumber ?? 'Truck')
            : (fuel.reeferNumber ?? 'Reefer');
        final location = AddressUtils.formatForPdf(fuel.location ?? '');
        final odometer = fuel.odometerReading?.toStringAsFixed(0) ??
            (fuel.reeferHours?.toStringAsFixed(1) ?? '');

        rows.add([
          date,
          type,
          truck,
          location,
          quantity,
          unit,
          cost,
          '', // Notes
          '', // From
          '', // To
          odometer,
        ]);
      }
    }

    final String csvContent = rows.map((row) {
      return row.map((e) {
        final String cell = e.toString().replaceAll('"', '""');
        if (cell.contains(',') || cell.contains('\n') || cell.contains('"')) {
          return '"$cell"';
        }
        return cell;
      }).join(',');
    }).join('\n');

    Directory? milowDocumentsDir;

    try {
      final externalStorage = await getExternalStorageDirectory();

      if (externalStorage != null) {
        String basePath;
        final externalPath = externalStorage.path;

        if (externalPath.contains('/Android/data/')) {
          basePath = externalPath.split('/Android/data/')[0];
        } else if (externalPath.contains('/Android/')) {
          basePath = externalPath.split('/Android/')[0];
        } else {
          basePath = '/storage/emulated/0';
        }

        milowDocumentsDir = Directory('$basePath/Download/Milow Documents');
      } else {
        final documentsDirectory = await getApplicationDocumentsDirectory();
        milowDocumentsDir = Directory(
          '${documentsDirectory.path}/Milow Documents',
        );
      }
    } catch (e) {
      debugPrint('Error getting external storage: $e');
      final documentsDirectory = await getApplicationDocumentsDirectory();
      milowDocumentsDir = Directory(
        '${documentsDirectory.path}/Milow Documents',
      );
    }

    if (!await milowDocumentsDir.exists()) {
      await milowDocumentsDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'milow_records_$timestamp.csv';
    final filePath = '${milowDocumentsDir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsString(csvContent);

    return filePath;
  }

  static Future<String> generatePDF({
    required List<Map<String, dynamic>> records,
    required String filter,
    required String distanceUnit, required String fuelUnit, required UnitSystem unitSystem, required String userName, required String userPhone, required List<String> selectedTripColumns, required List<String> selectedFuelColumns, required Map<String, String> tripColumnLabels, required Map<String, String> fuelColumnLabels, DateTimeRange? dateRange,
    bool includeSummaryBanner = true,
  }) async {
    final pdf = pw.Document();

    final tripRecords = records.where((r) => r['type'] == 'trip').toList()
      ..sort((a, b) {
        final dateA = a['rawDate'] as DateTime?;
        final dateB = b['rawDate'] as DateTime?;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      });

    final fuelRecords = records.where((r) => r['type'] == 'fuel').toList()
      ..sort((a, b) {
        final dateA = a['rawDate'] as DateTime?;
        final dateB = b['rawDate'] as DateTime?;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      });

    final unitSystemLabel =
        unitSystem == UnitSystem.metric ? 'Metric (km, L)' : 'Imperial (mi, gal)';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      userName,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey900,
                      ),
                    ),
                    if (userPhone.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        userPhone,
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'MILOW - Trip & Fuel Records',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Generated: ${_formatDate(DateTime.now())}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      if (dateRange != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${_formatDate(dateRange.start)} - ${_formatDate(dateRange.end)}',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                      if (filter != 'All') ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Filter: $filter',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Units: $unitSystemLabel',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(color: PdfColors.grey300, thickness: 1),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey300, thickness: 0.5),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '© ${DateTime.now().year} Milow - Trucker\'s Companion',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey500,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '>> Download Milow app for truckers & companies - Track trips, fuel & expenses effortlessly!',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue600,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ],
        ),
        build: (context) => [
          if (includeSummaryBanner) ...[
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 12,
              ),
              decoration: pw.BoxDecoration(
                gradient: const pw.LinearGradient(
                  colors: [PdfColors.blue50, PdfColors.white],
                ),
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: PdfColors.blue100),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPdfSummaryCard(
                    'Total Records',
                    '${records.length}',
                    PdfColors.blue700,
                  ),
                  _buildPdfSummaryDivider(),
                  _buildPdfSummaryCard(
                    'Trips',
                    '${tripRecords.length}',
                    PdfColors.blue600,
                  ),
                  _buildPdfSummaryDivider(),
                  _buildPdfSummaryCard(
                    'Fuel Entries',
                    '${fuelRecords.length}',
                    PdfColors.orange600,
                  ),
                  _buildPdfSummaryDivider(),
                  _buildPdfSummaryCard(
                    'Total $distanceUnit',
                    tripRecords
                        .fold<double>(0, (sum, r) {
                          final trip = r['data'] as Trip;
                          double d = trip.totalDistance ?? 0;
                          if (trip.distanceUnit != distanceUnit) {
                            d = distanceUnit == 'km'
                                ? UnitUtils.milesToKm(d)
                                : UnitUtils.kmToMiles(d);
                          }
                          return sum + d;
                        })
                        .toStringAsFixed(0),
                    PdfColors.green700,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
          ],
          if (tripRecords.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 12,
              ),
              decoration: const pw.BoxDecoration(
                color: PdfColors.blue700,
                borderRadius: pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(8),
                  topRight: pw.Radius.circular(8),
                ),
              ),
              child: pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      'T',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'TRIP RECORDS',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  pw.Spacer(),
                  pw.Text(
                    '${tripRecords.length} trips',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: _buildTripColumnWidths(selectedTripColumns),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                  children: _buildTripHeaderCells(selectedTripColumns, tripColumnLabels),
                ),
                ...tripRecords.asMap().entries.map((entry) {
                  final index = entry.key;
                  final record = entry.value;
                  final trip = record['data'] as Trip;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: index % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                    ),
                    children: _buildTripDataCells(trip, selectedTripColumns),
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 24),
          ],
          if (fuelRecords.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 12,
              ),
              decoration: const pw.BoxDecoration(
                color: PdfColors.orange700,
                borderRadius: pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(8),
                  topRight: pw.Radius.circular(8),
                ),
              ),
              child: pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      'F',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.orange700,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'FUEL RECORDS',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  pw.Spacer(),
                  pw.Text(
                    '${fuelRecords.length} entries',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: _buildFuelColumnWidths(selectedFuelColumns),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.orange50),
                  children: _buildFuelHeaderCells(selectedFuelColumns, fuelColumnLabels),
                ),
                ...fuelRecords.asMap().entries.map((entry) {
                  final index = entry.key;
                  final record = entry.value;
                  final fuel = record['data'] as FuelEntry;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: index % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                    ),
                    children: _buildFuelDataCells(fuel, selectedFuelColumns, distanceUnit, '\$'),
                  );
                }),
              ],
            ),
          ],
        ],
      ),
    );

    Directory? milowDocumentsDir;

    try {
      final externalStorage = await getExternalStorageDirectory();

      if (externalStorage != null) {
        String basePath;
        final externalPath = externalStorage.path;

        if (externalPath.contains('/Android/data/')) {
          basePath = externalPath.split('/Android/data/')[0];
        } else if (externalPath.contains('/Android/')) {
          basePath = externalPath.split('/Android/')[0];
        } else {
          basePath = '/storage/emulated/0';
        }

        milowDocumentsDir = Directory('$basePath/Download/Milow Documents');
      } else {
        final documentsDirectory = await getApplicationDocumentsDirectory();
        milowDocumentsDir = Directory(
          '${documentsDirectory.path}/Milow Documents',
        );
      }
    } catch (e) {
      debugPrint('Error getting external storage: $e');
      final documentsDirectory = await getApplicationDocumentsDirectory();
      milowDocumentsDir = Directory(
        '${documentsDirectory.path}/Milow Documents',
      );
    }

    if (!await milowDocumentsDir.exists()) {
      await milowDocumentsDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'milow_records_$timestamp.pdf';
    final filePath = '${milowDocumentsDir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    return filePath;
  }

  static pw.Widget _buildPdfSummaryCard(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ],
    );
  }

  static pw.Widget _buildPdfSummaryDivider() {
    return pw.Container(height: 40, width: 1, color: PdfColors.grey300);
  }

  static pw.Widget _buildPdfTableHeaderCell(String text, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 6,
          fontWeight: pw.FontWeight.bold,
          color: color ?? PdfColors.blue900,
        ),
        softWrap: true,
      ),
    );
  }

  static pw.Widget _buildPdfTableDataCell(
    String text, {
    PdfColor? color,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 6,
          fontWeight: bold ? pw.FontWeight.bold : null,
          color: color ?? PdfColors.grey800,
        ),
        softWrap: true,
        maxLines: 5,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  static Map<int, pw.TableColumnWidth> _buildTripColumnWidths(List<String> selectedColumns) {
    final Map<int, pw.TableColumnWidth> widths = {};
    for (int i = 0; i < selectedColumns.length; i++) {
      switch (selectedColumns[i]) {
        case 'tripNumber': widths[i] = const pw.FlexColumnWidth(1.0); break;
        case 'date': widths[i] = const pw.FlexColumnWidth(1.2); break;
        case 'truck': widths[i] = const pw.FlexColumnWidth(0.8); break;
        case 'trailer': widths[i] = const pw.FlexColumnWidth(0.8); break;
        case 'borderCrossing': widths[i] = const pw.FlexColumnWidth(1.2); break;
        case 'from': widths[i] = const pw.FlexColumnWidth(2.5); break;
        case 'to': widths[i] = const pw.FlexColumnWidth(2.5); break;
        case 'miles': widths[i] = const pw.FlexColumnWidth(0.8); break;
        case 'notes': widths[i] = const pw.FlexColumnWidth(1.5); break;
        case 'officialUse': widths[i] = const pw.FlexColumnWidth(1.2); break;
      }
    }
    return widths;
  }

  static List<pw.Widget> _buildTripHeaderCells(List<String> selectedColumns, Map<String, String> labels) {
    return selectedColumns.map((col) => _buildPdfTableHeaderCell(labels[col] ?? col)).toList();
  }

  static List<pw.Widget> _buildTripDataCells(Trip trip, List<String> selectedColumns) {
    return selectedColumns.map((col) {
      switch (col) {
        case 'tripNumber':
          return _buildPdfTableDataCell(trip.tripNumber, bold: true, color: PdfColors.blue800);
        case 'date':
          return _buildPdfTableDataCell(DateFormat('MMM d, yyyy').format(trip.tripDate));
        case 'truck':
          return _buildPdfTableDataCell(trip.truckNumber);
        case 'trailer':
          return _buildPdfTableDataCell(trip.trailers.isNotEmpty ? trip.trailers.join(', ') : '-');
        case 'borderCrossing':
          return _buildPdfTableDataCell(trip.borderCrossing ?? '-');
        case 'from':
          return _buildPdfTableDataCell(
            trip.pickupLocations.isNotEmpty ? trip.pickupLocations.map((l) => AddressUtils.formatForPdf(l)).join('\n') : '-',
          );
        case 'to':
          return _buildPdfTableDataCell(
            trip.deliveryLocations.isNotEmpty ? trip.deliveryLocations.map((l) => AddressUtils.formatForPdf(l)).join('\n') : '-',
          );
        case 'miles':
          final miles = trip.totalDistance?.toStringAsFixed(0) ?? '-';
          return _buildPdfTableDataCell('$miles ${trip.distanceUnitLabel}', bold: true, color: PdfColors.green700);
        case 'notes':
          return _buildPdfTableDataCell(trip.notes ?? '-');
        case 'officialUse':
          return _buildPdfTableDataCell('');
        default:
          return _buildPdfTableDataCell('-');
      }
    }).toList();
  }

  static Map<int, pw.TableColumnWidth> _buildFuelColumnWidths(List<String> selectedColumns) {
    final Map<int, pw.TableColumnWidth> widths = {};
    for (int i = 0; i < selectedColumns.length; i++) {
      switch (selectedColumns[i]) {
        case 'date': widths[i] = const pw.FlexColumnWidth(1.2); break;
        case 'type': widths[i] = const pw.FlexColumnWidth(0.8); break;
        case 'truck': widths[i] = const pw.FlexColumnWidth(1.0); break;
        case 'location': widths[i] = const pw.FlexColumnWidth(1.8); break;
        case 'quantity': widths[i] = const pw.FlexColumnWidth(1.0); break;
        case 'odometer': widths[i] = const pw.FlexColumnWidth(1.0); break;
        case 'cost': widths[i] = const pw.FlexColumnWidth(1.0); break;
      }
    }
    return widths;
  }

  static List<pw.Widget> _buildFuelHeaderCells(List<String> selectedColumns, Map<String, String> labels) {
    return selectedColumns.map((col) => _buildPdfTableHeaderCell(labels[col] ?? col, color: PdfColors.orange900)).toList();
  }

  static List<pw.Widget> _buildFuelDataCells(FuelEntry fuel, List<String> selectedColumns, String odometerUnit, String currency) {
    return selectedColumns.map((col) {
      switch (col) {
        case 'date':
          return _buildPdfTableDataCell(DateFormat('MMM d, yyyy').format(fuel.fuelDate));
        case 'type':
          return _buildPdfTableDataCell(fuel.isReeferFuel ? 'Reefer' : 'Truck', bold: true, color: fuel.isReeferFuel ? PdfColors.cyan700 : PdfColors.orange700);
        case 'truck':
          return _buildPdfTableDataCell(fuel.isReeferFuel ? (fuel.reeferNumber ?? '-') : (fuel.truckNumber ?? '-'));
        case 'location':
          return _buildPdfTableDataCell(AddressUtils.formatForPdf(fuel.location ?? ''));
        case 'quantity':
          return _buildPdfTableDataCell('${fuel.fuelQuantity.toStringAsFixed(1)} ${fuel.fuelUnitLabel}');
        case 'odometer':
          if (fuel.isReeferFuel) {
            return _buildPdfTableDataCell(fuel.reeferHours != null ? '${fuel.reeferHours!.toStringAsFixed(1)} hrs' : '-');
          } else {
            return _buildPdfTableDataCell(fuel.odometerReading != null ? '${fuel.odometerReading!.toStringAsFixed(0)} $odometerUnit' : '-');
          }
        case 'cost':
          return _buildPdfTableDataCell('$currency${fuel.totalCost.toStringAsFixed(2)}', bold: true, color: PdfColors.green700);
        default:
          return _buildPdfTableDataCell('-');
      }
    }).toList();
  }

  static String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }
}
