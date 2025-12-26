import 'package:mockito/mockito.dart';
import '../../lib/features/dashboard/services/vehicle_service.dart';

class MockVehicleService extends Mock implements VehicleService {
  @override
  Future<List<Map<String, dynamic>>> getVehicles() {
    return super.noSuchMethod(
          Invocation.method(#getVehicles, []),
          returnValue: Future.value(<Map<String, dynamic>>[]),
          returnValueForMissingStub: Future.value(<Map<String, dynamic>>[]),
        )
        as Future<List<Map<String, dynamic>>>;
  }
}
