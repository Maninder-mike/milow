import 'package:shared_preferences/shared_preferences.dart';
import 'package:milow/core/utils/unit_utils.dart';

enum UnitSystem { metric, imperial }

class PreferencesService {
  static const String _unitSystemKey = 'unit_system';
  static const String _hiddenTripsKey = 'hidden_trips';

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

  // Hidden Trips
  static Future<List<String>> getHiddenTripIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_hiddenTripsKey) ?? [];
  }

  static Future<void> addHiddenTripId(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    final hidden = prefs.getStringList(_hiddenTripsKey) ?? [];
    if (!hidden.contains(tripId)) {
      hidden.add(tripId);
      await prefs.setStringList(_hiddenTripsKey, hidden);
    }
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

  // ================= CONVERSION HELPERS =================

  /// Convert value from User Pref to Metric (for Saving)
  static Future<double> standardizeDistance(double val) async {
    return (await getUnitSystem()) == UnitSystem.imperial
        ? UnitUtils.milesToKm(val)
        : val;
  }

  static Future<double> standardizeVolume(double val) async {
    return (await getUnitSystem()) == UnitSystem.imperial
        ? UnitUtils.gallonsToLiters(val)
        : val;
  }

  static Future<double> standardizeWeight(double val) async {
    return (await getUnitSystem()) == UnitSystem.imperial
        ? UnitUtils.lbsToKg(val)
        : val;
  }

  /// Convert value from Metric to User Pref (for Loading/Display)
  static Future<double> localizeDistance(double val) async {
    return (await getUnitSystem()) == UnitSystem.imperial
        ? UnitUtils.kmToMiles(val)
        : val;
  }

  static Future<double> localizeVolume(double val) async {
    return (await getUnitSystem()) == UnitSystem.imperial
        ? UnitUtils.litersToGallons(val)
        : val;
  }

  static Future<double> localizeWeight(double val) async {
    return (await getUnitSystem()) == UnitSystem.imperial
        ? UnitUtils.kgToLbs(val)
        : val;
  }

  // Weather display preference

  // PDF Export Column Order preferences
  static const String _tripColumnsKey = 'pdf_trip_columns';
  static const String _fuelColumnsKey = 'pdf_fuel_columns';

  static Future<List<String>> getTripColumns() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_tripColumnsKey) ?? [];
  }

  static Future<void> setTripColumns(List<String> columns) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_tripColumnsKey, columns);
  }

  static Future<List<String>> getFuelColumns() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_fuelColumnsKey) ?? [];
  }

  static Future<void> setFuelColumns(List<String> columns) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_fuelColumnsKey, columns);
  }
}
