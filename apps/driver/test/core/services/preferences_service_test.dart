import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:milow/core/services/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreferencesService Unit Tests', () {
    late PreferencesService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      service = PreferencesService(prefs);
    });

    test('defaults to metric system', () async {
      expect(service.getUnitSystem(), UnitSystem.metric);
      expect(service.getDistanceUnit(), 'km');
      expect(service.getVolumeUnit(), 'L');
      expect(service.getWeightUnit(), 'kg');
    });

    test('switches to imperial system', () async {
      await service.setUnitSystem(UnitSystem.imperial);
      expect(service.getUnitSystem(), UnitSystem.imperial);
      expect(service.getDistanceUnit(), 'mi');
      expect(service.getVolumeUnit(), 'gal');
      expect(service.getWeightUnit(), 'lb');
    });

    group('Standardization (User Input -> Metric Storage)', () {
      test('standardizes distance correctly', () async {
        // Metric (no change)
        await service.setUnitSystem(UnitSystem.metric);
        expect(service.standardizeDistance(100.0), 100.0);

        // Imperial (converted to km)
        await service.setUnitSystem(UnitSystem.imperial);
        // 100 miles * 1.60934 = 160.934 km
        expect(service.standardizeDistance(100.0), closeTo(160.934, 0.001));
      });

      test('standardizes volume correctly', () async {
        // Metric (no change)
        await service.setUnitSystem(UnitSystem.metric);
        expect(service.standardizeVolume(100.0), 100.0);

        // Imperial (converted to liters)
        await service.setUnitSystem(UnitSystem.imperial);
        // 100 gallons * 3.78541 = 378.541 liters
        expect(service.standardizeVolume(100.0), closeTo(378.541, 0.001));
      });

      test('standardizes weight correctly', () async {
        // Metric (no change)
        await service.setUnitSystem(UnitSystem.metric);
        expect(service.standardizeWeight(100.0), 100.0);

        // Imperial (converted to kilograms)
        await service.setUnitSystem(UnitSystem.imperial);
        // 100 lbs * 0.453592 = 45.3592 kg
        expect(service.standardizeWeight(100.0), closeTo(45.3592, 0.001));
      });
    });

    group('Localization (Metric Storage -> User Display)', () {
      test('localizes distance correctly', () async {
        // Metric (no change)
        await service.setUnitSystem(UnitSystem.metric);
        expect(service.localizeDistance(160.934), 160.934);

        // Imperial (converted to miles)
        await service.setUnitSystem(UnitSystem.imperial);
        expect(service.localizeDistance(160.934), closeTo(100.0, 0.001));
      });

      test('localizes volume correctly', () async {
        // Metric (no change)
        await service.setUnitSystem(UnitSystem.metric);
        expect(service.localizeVolume(378.541), 378.541);

        // Imperial (converted to gallons)
        await service.setUnitSystem(UnitSystem.imperial);
        expect(service.localizeVolume(378.541), closeTo(100.0, 0.001));
      });

      test('localizes weight correctly', () async {
        // Metric (no change)
        await service.setUnitSystem(UnitSystem.metric);
        expect(service.localizeWeight(45.3592), 45.3592);

        // Imperial (converted to lbs)
        await service.setUnitSystem(UnitSystem.imperial);
        expect(service.localizeWeight(45.3592), closeTo(100.0, 0.001));
      });
    });
  });
}
