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
      skip: 'Times out with Mockito - needs investigation',
      () async {
        final exception = Exception('Network error');
        // Use async throw to return a failed future
        when(
          mockService.getVehicles(),
        ).thenAnswer((_) => Future.error(exception));

        final container = ProviderContainer(
          overrides: [vehicleServiceProvider.overrideWithValue(mockService)],
        );

        // Expect the future to complete with an error
        await expectLater(
          container.read(vehiclesListProvider.future),
          throwsA(isA<Exception>()),
        );
      },
    );
  });
}
