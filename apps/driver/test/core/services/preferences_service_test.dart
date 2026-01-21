import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:milow/core/services/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreferencesService Unit Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to metric system', () async {
      expect(await PreferencesService.getUnitSystem(), UnitSystem.metric);
      expect(await PreferencesService.getDistanceUnit(), 'km');
      expect(await PreferencesService.getVolumeUnit(), 'L');
      expect(await PreferencesService.getWeightUnit(), 'kg');
    });

    test('switches to imperial system', () async {
      await PreferencesService.setUnitSystem(UnitSystem.imperial);
      expect(await PreferencesService.getUnitSystem(), UnitSystem.imperial);
      expect(await PreferencesService.getDistanceUnit(), 'mi');
      expect(await PreferencesService.getVolumeUnit(), 'gal');
      expect(await PreferencesService.getWeightUnit(), 'lb');
    });

    group('Standardization (User Input -> Metric Storage)', () {
      test('standardizes distance correctly', () async {
        // Metric (no change)
        await PreferencesService.setUnitSystem(UnitSystem.metric);
        expect(await PreferencesService.standardizeDistance(100.0), 100.0);

        // Imperial (converted to km)
        await PreferencesService.setUnitSystem(UnitSystem.imperial);
        // 100 miles * 1.60934 = 160.934 km
        expect(
          await PreferencesService.standardizeDistance(100.0),
          closeTo(160.934, 0.001),
        );
      });

      test('standardizes volume correctly', () async {
        // Metric (no change)
        await PreferencesService.setUnitSystem(UnitSystem.metric);
        expect(await PreferencesService.standardizeVolume(100.0), 100.0);

        // Imperial (converted to liters)
        await PreferencesService.setUnitSystem(UnitSystem.imperial);
        // 100 gallons * 3.78541 = 378.541 liters
        expect(
          await PreferencesService.standardizeVolume(100.0),
          closeTo(378.541, 0.001),
        );
      });

      test('standardizes weight correctly', () async {
        // Metric (no change)
        await PreferencesService.setUnitSystem(UnitSystem.metric);
        expect(await PreferencesService.standardizeWeight(100.0), 100.0);

        // Imperial (converted to kilograms)
        await PreferencesService.setUnitSystem(UnitSystem.imperial);
        // 100 lbs * 0.453592 = 45.3592 kg
        expect(
          await PreferencesService.standardizeWeight(100.0),
          closeTo(45.3592, 0.001),
        );
      });
    });

    group('Localization (Metric Storage -> User Display)', () {
      test('localizes distance correctly', () async {
        // Metric (no change)
        await PreferencesService.setUnitSystem(UnitSystem.metric);
        expect(await PreferencesService.localizeDistance(160.934), 160.934);

        // Imperial (converted to miles)
        await PreferencesService.setUnitSystem(UnitSystem.imperial);
        expect(
          await PreferencesService.localizeDistance(160.934),
          closeTo(100.0, 0.001),
        );
      });

      test('localizes volume correctly', () async {
        // Metric (no change)
        await PreferencesService.setUnitSystem(UnitSystem.metric);
        expect(await PreferencesService.localizeVolume(378.541), 378.541);

        // Imperial (converted to gallons)
        await PreferencesService.setUnitSystem(UnitSystem.imperial);
        expect(
          await PreferencesService.localizeVolume(378.541),
          closeTo(100.0, 0.001),
        );
      });

      test('localizes weight correctly', () async {
        // Metric (no change)
        await PreferencesService.setUnitSystem(UnitSystem.metric);
        expect(await PreferencesService.localizeWeight(45.3592), 45.3592);

        // Imperial (converted to lbs)
        await PreferencesService.setUnitSystem(UnitSystem.imperial);
        expect(
          await PreferencesService.localizeWeight(45.3592),
          closeTo(100.0, 0.001),
        );
      });
    });
  });
}
