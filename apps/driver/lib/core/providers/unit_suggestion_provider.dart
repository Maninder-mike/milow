import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:milow/core/services/preferences_service.dart';
import 'package:milow/core/utils/unit_utils.dart';

class UnitSuggestionProvider extends ChangeNotifier {
  final PreferencesService _prefs;
  StreamSubscription<Position>? _positionSubscription;
  
  String? _suggestedCountry;
  bool _isChecking = false;

  UnitSuggestionProvider(this._prefs) {
    _init();
  }

  String? get suggestedCountry => _suggestedCountry;

  void _init() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 5000, // Check every 5km
      ),
    ).listen(_handlePositionUpdate);
  }

  Future<void> _handlePositionUpdate(Position position) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final countryCode = placemarks.first.isoCountryCode;
        if (countryCode != null) {
          await _processCountryDetection(countryCode);
        }
      }
    } catch (e) {
      debugPrint('UnitSuggestionProvider: Geocoding failed: $e');
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _processCountryDetection(String countryCode) async {
    final currentSystem = _prefs.getUnitSystem();
    final countrySystem = UnitUtils.isImperial(countryCode)
        ? UnitSystem.imperial
        : UnitSystem.metric;

    // If systems already match, clear any pending suggestions
    if (currentSystem == countrySystem) {
      _suggestedCountry = null;
      await _prefs.clearDetectedCountry();
      notifyListeners();
      return;
    }

    // Step 1: Record detection in Preferences (handles hysteresis)
    await _prefs.setLastDetectedCountry(countryCode);

    // Step 2: Check if 1 minute has passed (Hysteresis)
    final detectedAt = _prefs.getCountryDetectedAt();
    if (detectedAt != null) {
      final difference = DateTime.now().difference(detectedAt);
      if (difference.inMinutes >= 1) {
        // Hysteresis met! Show suggestion
        if (_suggestedCountry != countryCode) {
          _suggestedCountry = countryCode;
          notifyListeners();
        }
      } else {
        // Still in the 1-minute waiting period
        // We don't update _suggestedCountry yet, but we keep the detection active
        if (_suggestedCountry != null) {
          _suggestedCountry = null;
          notifyListeners();
        }
      }
    }
  }

  Future<void> acceptSuggestion() async {
    if (_suggestedCountry != null) {
      await _prefs.updateFromCountry(_suggestedCountry!);
      _suggestedCountry = null;
      await _prefs.clearDetectedCountry();
      notifyListeners();
    }
  }

  void dismissSuggestion() {
    _suggestedCountry = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}
