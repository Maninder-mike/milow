import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:milow/core/services/export_service.dart';
import 'package:milow_core/milow_core.dart';

class FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String path;
  FakePathProvider(this.path);
  @override
  Future<String?> getTemporaryPath() async => path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getExternalStoragePath() async => null;
  @override
  Future<String?> getDownloadsPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('export_service_test_');
  });

  setUp(() async {
    PathProviderPlatform.instance = FakePathProvider(tempDir.path);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  group('ExportService', () {
    test('generateCSV creates correct CSV content for mixed records', () async {
      final mockTrip = Trip(
        id: '1',
        userId: 'user1',
        tripNumber: 'T1001',
        truckNumber: 'TRK-01',
        tripDate: DateTime(2026, 5, 1),
        pickupLocations: const ['New York, NY'],
        deliveryLocations: const ['Boston, MA'],
        startOdometer: 0.0,
        endOdometer: 215.5,
        distanceUnit: 'mi',
      );

      final mockFuel = FuelEntry(
        id: '2',
        userId: 'user1',
        fuelDate: DateTime(2026, 5, 2),
        fuelType: 'truck',
        fuelQuantity: 50.0,
        pricePerUnit: 3.0,
        fuelUnit: 'gal',
        truckNumber: 'TRK-01',
      );

      final records = [
        {'type': 'trip', 'rawDate': mockTrip.tripDate, 'data': mockTrip},
        {'type': 'fuel', 'rawDate': mockFuel.fuelDate, 'data': mockFuel},
      ];

      final csvFilePath = await ExportService.generateCSV(
        records: records,
        distanceUnit: 'mi',
        fuelUnit: 'gal',
      );

      final csvContent = await File(csvFilePath).readAsString();

      // Verify headers
      expect(
        csvContent.contains('Date,Type,ID/Truck,Description/Location,Distance/Quantity,Unit,Cost,Notes,From,To,Odometer'),
        isTrue,
      );

      // Verify trip data is present
      expect(csvContent.contains('2026-05-01'), isTrue);
      expect(csvContent.contains('Trip #T1001'), isTrue);
      expect(csvContent.contains('215.5'), isTrue);
      expect(csvContent.contains('New York, NY'), isTrue);
      expect(csvContent.contains('Boston, MA'), isTrue);

      // Verify fuel data is present
      expect(csvContent.contains('2026-05-02'), isTrue);
      expect(csvContent.contains('TRK-01'), isTrue);
      expect(csvContent.contains('50.0'), isTrue);
      expect(csvContent.contains('150.00'), isTrue);
    });

    test('generateCSV converts units correctly based on preferences', () async {
      final mockTrip = Trip(
        id: '1',
        userId: 'user1',
        tripNumber: 'T1002',
        truckNumber: 'TRK-01',
        tripDate: DateTime(2026, 5, 1),
        pickupLocations: const [],
        deliveryLocations: const [],
        startOdometer: 0.0,
        endOdometer: 100.0,
        distanceUnit: 'km',
      );

      final records = [
        {'type': 'trip', 'rawDate': mockTrip.tripDate, 'data': mockTrip},
      ];

      final csvFilePath = await ExportService.generateCSV(
        records: records,
        distanceUnit: 'mi', // User preference is miles
        fuelUnit: 'gal',
      );

      final csvContent = await File(csvFilePath).readAsString();

      // 100 km is approx 62.1 miles
      expect(csvContent.contains('62.1'), isTrue);
      expect(csvContent.contains(',mi,'), isTrue); // Unit column should show mi
    });
  });
}
