import 'package:milow/core/services/data_prefetch_service.dart';

class PredictionService {
  // Singleton instance
  static final PredictionService _instance = PredictionService._internal();
  static PredictionService get instance => _instance;

  PredictionService._internal();

  /// Get suggested truck numbers based on history
  Future<List<String>> getTruckSuggestions(String query) async {
    final prefetch = DataPrefetchService.instance;
    final trips = prefetch.cachedTrips ?? [];
    final fuelEntries = prefetch.cachedFuelEntries ?? [];

    final frequencyMap = <String, int>{};

    for (final trip in trips) {
      _addToFrequency(frequencyMap, trip.truckNumber);
    }
    for (final entry in fuelEntries) {
      if (entry.truckNumber != null) {
        _addToFrequency(frequencyMap, entry.truckNumber!);
      }
      if (entry.reeferNumber != null) {
        _addToFrequency(frequencyMap, entry.reeferNumber!);
      }
    }

    return _getTopMatches(frequencyMap, query);
  }

  /// Get suggested trailer numbers
  Future<List<String>> getTrailerSuggestions(String query) async {
    final trips = DataPrefetchService.instance.cachedTrips ?? [];
    final frequencyMap = <String, int>{};

    for (final trip in trips) {
      for (final trailer in trip.trailers) {
        _addToFrequency(frequencyMap, trailer);
      }
    }

    return _getTopMatches(frequencyMap, query);
  }

  /// Get suggested locations (Pickup/Delivery/Fuel)
  Future<List<String>> getLocationSuggestions(String query) async {
    final prefetch = DataPrefetchService.instance;
    final trips = prefetch.cachedTrips ?? [];
    final fuelEntries = prefetch.cachedFuelEntries ?? [];

    final frequencyMap = <String, int>{};

    for (final trip in trips) {
      for (final loc in trip.pickupLocations) {
        _addToFrequency(frequencyMap, loc);
      }
      for (final loc in trip.deliveryLocations) {
        _addToFrequency(frequencyMap, loc);
      }
    }
    for (final entry in fuelEntries) {
      if (entry.location != null) {
        _addToFrequency(frequencyMap, entry.location!);
      }
    }

    return _getTopMatches(frequencyMap, query);
  }

  void _addToFrequency(Map<String, int> map, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    map[trimmed] = (map[trimmed] ?? 0) + 1;
  }

  List<String> _getTopMatches(Map<String, int> frequencyMap, String query) {
    if (query.isEmpty) return [];

    final normalizedQuery = query.toLowerCase();

    // Filter keys that contain the query
    final matches = frequencyMap.keys
        .where((key) => key.toLowerCase().contains(normalizedQuery))
        .toList();

    // Sort by frequency (descending)
    matches.sort((a, b) {
      final freqA = frequencyMap[a]!;
      final freqB = frequencyMap[b]!;
      return freqB.compareTo(freqA);
    });

    // Return top 5
    return matches.take(5).toList();
  }
}
