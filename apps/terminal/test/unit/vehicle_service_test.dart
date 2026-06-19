import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:terminal/features/dashboard/services/vehicle_service.dart';
import '../helpers/mock_vehicle_service.dart';

void main() {
  group('vehiclesListProvider', () {
    late MockVehicleService mockService;

    setUp(() {
      mockService = MockVehicleService();
    });

    test('returns list of vehicles when service fetching succeeds', () async {
      final vehicles = [
        {'id': '1', 'truck_number': '101', 'status': 'Active'},
        {'id': '2', 'truck_number': '102', 'status': 'Maintenance'},
      ];

      when(mockService.getVehicles()).thenAnswer((_) async => vehicles);

      final container = ProviderContainer(
        overrides: [vehicleServiceProvider.overrideWithValue(mockService)],
      );

      final result = await container.read(vehiclesListProvider.future);

      expect(result, equals(vehicles));
      expect(result.length, 2);
      expect(result.first['truck_number'], '101');
    });

    test('returns empty list when service returns no vehicles', () async {
      when(mockService.getVehicles()).thenAnswer((_) async => []);

      final container = ProviderContainer(
        overrides: [vehicleServiceProvider.overrideWithValue(mockService)],
      );

      final result = await container.read(vehiclesListProvider.future);

      expect(result, isEmpty);
    });

    test(
      'throws exception when service fails',
      () async {
        final failingService = _FailingVehicleService();

        final container = ProviderContainer(
          overrides: [vehicleServiceProvider.overrideWithValue(failingService)],
        );
        addTearDown(container.dispose);

        final sub = container.listen(vehiclesListProvider, (previous, next) {}, fireImmediately: true);

        await Future.delayed(const Duration(milliseconds: 50));

        final finalValue = container.read(vehiclesListProvider);
        expect(finalValue.hasError, isTrue);
        expect(finalValue.error.toString(), contains('Network error'));
        sub.close();
      },
    );
  });
}

// Fully manual implementation to avoid any Mockito magic/handlers
class _FailingVehicleService implements VehicleService {
  @override
  Future<List<Map<String, dynamic>>> getVehicles() {
    return Future.error(Exception('Network error'));
  }

  @override
  Future<void> deleteDocument(String id, String path) async {
    throw UnimplementedError();
  }

  @override
  List<Map<String, dynamic>> getDummyVehicles() {
    throw UnimplementedError();
  }
}
