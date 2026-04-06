import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:milow/core/utils/unit_utils.dart';

enum UnitSystem { metric, imperial }

class PreferencesService extends ChangeNotifier {
  static const String _unitSystemKey = 'unit_system';
  static const String _distanceUnitKey = 'distance_unit_pref';
  static const String _volumeUnitKey = 'volume_unit_pref';
  static const String _weightUnitKey = 'weight_unit_pref';
  static const String _hiddenTripsKey = 'hidden_trips';
  static const String _autoUpdateUnitsKey = 'auto_update_units';
  static const String _currencyKey = 'currency_pref';

  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static Future<PreferencesService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  // Unit System preference (Metric/Imperial)
  UnitSystem getUnitSystem() {
    final value = _prefs.getString(_unitSystemKey);
    if (value == 'imperial') {
      return UnitSystem.imperial;
    }
    return UnitSystem.metric; // Default: metric
  }

  Future<void> setUnitSystem(UnitSystem system) async {
    await _prefs.setString(
      _unitSystemKey,
      system == UnitSystem.imperial ? 'imperial' : 'metric',
    );
    // When changing global system, also set granular defaults to keep them in sync
    await setDistanceUnit(
      system == UnitSystem.imperial ? 'mi' : 'km',
      notify: false,
    );
    await setVolumeUnit(
      system == UnitSystem.imperial ? 'gal' : 'L',
      notify: false,
    );
    await setWeightUnit(
      system == UnitSystem.imperial ? 'lbs' : 'kg',
      notify: false,
    );

    notifyListeners();
  }

  // Auto-detect setting
  bool getAutoUpdateUnits() {
    return _prefs.getBool(_autoUpdateUnitsKey) ?? false;
  }

  Future<void> setAutoUpdateUnits(bool value) async {
    await _prefs.setBool(_autoUpdateUnitsKey, value);
    notifyListeners();
  }

  // Currency preference
  String getCurrency() {
    return _prefs.getString(_currencyKey) ?? 'USD';
  }

  Future<void> setCurrency(String currency) async {
    await _prefs.setString(_currencyKey, currency);
    notifyListeners();
  }

  /// Update all units and currency based on country string
  Future<void> updateFromCountry(String country) async {
    final system = UnitUtils.isImperial(country)
        ? UnitSystem.imperial
        : UnitSystem.metric;

    // Update global system (which updates granular defaults)
    await setUnitSystem(system);

    // Update currency
    final currency = UnitUtils.getCurrency(country);
    await setCurrency(currency);

    notifyListeners();
  }

  // Granular Unit setters
  Future<void> setDistanceUnit(String unit, {bool notify = true}) async {
    await _prefs.setString(_distanceUnitKey, unit);
    if (notify) notifyListeners();
  }

  Future<void> setVolumeUnit(String unit, {bool notify = true}) async {
    await _prefs.setString(_volumeUnitKey, unit);
    if (notify) notifyListeners();
  }

  Future<void> setWeightUnit(String unit, {bool notify = true}) async {
    // Standardize 'lbs' instead of 'lb' for consistency
    final sanitizedUnit = unit.toLowerCase() == 'lb'
        ? 'lbs'
        : unit.toLowerCase();
    await _prefs.setString(_weightUnitKey, sanitizedUnit);
    if (notify) notifyListeners();
  }

  // Hidden Trips
  List<String> getHiddenTripIds() {
    return _prefs.getStringList(_hiddenTripsKey) ?? [];
  }

  Future<void> addHiddenTripId(String tripId) async {
    final hidden = _prefs.getStringList(_hiddenTripsKey) ?? [];
    if (!hidden.contains(tripId)) {
      hidden.add(tripId);
      await _prefs.setStringList(_hiddenTripsKey, hidden);
      notifyListeners();
    }
  }

  // Helper methods for unit conversion
  String getDistanceUnit() {
    final granular = _prefs.getString(_distanceUnitKey);
    if (granular != null) return granular;

    final system = getUnitSystem();
    return system == UnitSystem.imperial ? 'mi' : 'km';
  }

  String getWeightUnit() {
    final granular = _prefs.getString(_weightUnitKey);
    if (granular != null) {
      // Auto-correct 'lb' to 'lbs' if it exists in storage
      if (granular == 'lb') return 'lbs';
      return granular;
    }

    final system = getUnitSystem();
    return system == UnitSystem.imperial ? 'lbs' : 'kg';
  }

  String getVolumeUnit() {
    final granular = _prefs.getString(_volumeUnitKey);
    if (granular != null) return granular;

    final system = getUnitSystem();
    return system == UnitSystem.imperial ? 'gal' : 'L';
  }

  // ================= CONVERSION HELPERS =================

  /// Convert value from User Pref to Metric (for Saving)
  double standardizeDistance(double val) {
    return getUnitSystem() == UnitSystem.imperial
        ? UnitUtils.milesToKm(val)
        : val;
  }

  double standardizeVolume(double val) {
    return getUnitSystem() == UnitSystem.imperial
        ? UnitUtils.gallonsToLiters(val)
        : val;
  }

  double standardizeWeight(double val) {
    return getUnitSystem() == UnitSystem.imperial
        ? UnitUtils.lbsToKg(val)
        : val;
  }

  /// Convert price per unit from User Pref to Metric (for Saving)
  /// e.g. $/gal to $/L
  double standardizePrice(double val) {
    return getUnitSystem() == UnitSystem.imperial
        ? val * UnitUtils.litersToGallons(1) // (val / 3.785)
        : val;
  }

  /// Convert value from Metric to User Pref (for Loading/Display)
  double localizeDistance(double val) {
    return getUnitSystem() == UnitSystem.imperial
        ? UnitUtils.kmToMiles(val)
        : val;
  }

  double localizeVolume(double val) {
    return getUnitSystem() == UnitSystem.imperial
        ? UnitUtils.litersToGallons(val)
        : val;
  }

  double localizeWeight(double val) {
    return getUnitSystem() == UnitSystem.imperial
        ? UnitUtils.kgToLbs(val)
        : val;
  }

  double localizePrice(double val) {
    return getUnitSystem() == UnitSystem.imperial
        ? val / UnitUtils.litersToGallons(1)
        : val;
  }

  // PDF Export Column Order preferences
  static const String _tripColumnsKey = 'pdf_trip_columns';
  static const String _fuelColumnsKey = 'pdf_fuel_columns';

  List<String> getTripColumns() {
    return _prefs.getStringList(_tripColumnsKey) ?? [];
  }

  Future<void> setTripColumns(List<String> columns) async {
    await _prefs.setStringList(_tripColumnsKey, columns);
    notifyListeners();
  }

  List<String> getFuelColumns() {
    return _prefs.getStringList(_fuelColumnsKey) ?? [];
  }

  Future<void> setFuelColumns(List<String> columns) async {
    await _prefs.setStringList(_fuelColumnsKey, columns);
    notifyListeners();
  }
}
