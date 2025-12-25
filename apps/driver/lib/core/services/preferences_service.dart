import 'package:shared_preferences/shared_preferences.dart';

enum UnitSystem { metric, imperial }

class PreferencesService {
  static const String _unitSystemKey = 'unit_system';
  // Unit System preference (Metric/Imperial)
  static Future<UnitSystem> getUnitSystem() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_unitSystemKey);
    if (value == 'imperial') {
      return UnitSystem.imperial;
    }
    return UnitSystem.metric; // Default: metric
  }

  static Future<void> setUnitSystem(UnitSystem system) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _unitSystemKey,
      system == UnitSystem.imperial ? 'imperial' : 'metric',
    );
  }

  // Helper methods for unit conversion
  static Future<String> getDistanceUnit() async {
    final system = await getUnitSystem();
    return system == UnitSystem.imperial ? 'mi' : 'km';
  }

  static Future<String> getWeightUnit() async {
    final system = await getUnitSystem();
    return system == UnitSystem.imperial ? 'lb' : 'kg';
  }

  static Future<String> getVolumeUnit() async {
    final system = await getUnitSystem();
    return system == UnitSystem.imperial ? 'gal' : 'L';
  }

  static Future<double> convertDistance(
    double value, {
    bool toMetric = true,
  }) async {
    final system = await getUnitSystem();
    if (system == UnitSystem.metric && !toMetric) {
      // Convert km to miles
      return value * 0.621371;
    } else if (system == UnitSystem.imperial && toMetric) {
      // Convert miles to km
      return value * 1.60934;
    }
    return value;
  }

  // Weather display preference
}
