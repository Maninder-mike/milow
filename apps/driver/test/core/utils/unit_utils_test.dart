import 'package:flutter_test/flutter_test.dart';
import 'package:milow/core/utils/unit_utils.dart';

void main() {
  group('UnitUtils Conversion Tests', () {
    test('kilometers to miles conversion', () {
      expect(UnitUtils.kmToMiles(1.0), closeTo(0.621371, 0.000001));
      expect(UnitUtils.kmToMiles(100.0), closeTo(62.1371, 0.0001));
      expect(UnitUtils.kmToMiles(0.0), 0.0);
    });

    test('miles to kilometers conversion', () {
      expect(UnitUtils.milesToKm(1.0), closeTo(1.60934, 0.0001));
      expect(UnitUtils.milesToKm(62.1371), closeTo(100.0, 0.001));
      expect(UnitUtils.milesToKm(0.0), 0.0);
    });

    test('liters to gallons conversion', () {
      expect(UnitUtils.litersToGallons(1.0), closeTo(0.264172, 0.000001));
      expect(UnitUtils.litersToGallons(3.78541), closeTo(1.0, 0.0001));
      expect(UnitUtils.litersToGallons(0.0), 0.0);
    });

    test('gallons to liters conversion', () {
      expect(UnitUtils.gallonsToLiters(1.0), closeTo(3.78541, 0.0001));
      expect(UnitUtils.gallonsToLiters(0.264172), closeTo(1.0, 0.0001));
      expect(UnitUtils.gallonsToLiters(0.0), 0.0);
    });

    test('kilograms to pounds conversion', () {
      expect(UnitUtils.kgToLbs(1.0), closeTo(2.20462, 0.00001));
      expect(UnitUtils.kgToLbs(100.0), closeTo(220.462, 0.001));
      expect(UnitUtils.kgToLbs(0.0), 0.0);
    });

    test('pounds to kilograms conversion', () {
      expect(UnitUtils.lbsToKg(1.0), closeTo(0.453592, 0.0001));
      expect(UnitUtils.lbsToKg(220.462), closeTo(100.0, 0.001));
      expect(UnitUtils.lbsToKg(0.0), 0.0);
    });
  });

  group('UnitUtils Unit Determination Tests', () {
    test('returns correct units for USA', () {
      expect(UnitUtils.getDistanceUnit('USA'), 'mi');
      expect(UnitUtils.getVolumeUnit('USA'), 'gal');
      expect(UnitUtils.getWeightUnit('USA'), 'lb');
      expect(UnitUtils.getCurrency('USA'), 'USD');
    });

    test('returns correct units for Canada', () {
      expect(UnitUtils.getDistanceUnit('Canada'), 'km');
      expect(UnitUtils.getVolumeUnit('Canada'), 'L');
      expect(UnitUtils.getWeightUnit('Canada'), 'kg');
      expect(UnitUtils.getCurrency('Canada'), 'CAD');
    });

    test('returns metric as fallback', () {
      expect(UnitUtils.getDistanceUnit('Germany'), 'km');
      expect(UnitUtils.getVolumeUnit('Germany'), 'L');
      expect(UnitUtils.getWeightUnit('Germany'), 'kg');
      expect(UnitUtils.getCurrency('Germany'), 'EUR');
    });
  });
}
