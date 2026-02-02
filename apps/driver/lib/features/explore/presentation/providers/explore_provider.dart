import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/services/fuel_service.dart';
import 'package:milow/core/services/trip_service.dart';
import 'package:milow/core/services/data_prefetch_service.dart';
import 'package:milow/core/services/geo_service.dart';
import 'package:milow/features/explore/presentation/utils/explore_utils.dart';
import 'package:milow/features/explore/presentation/utils/explore_map_helper.dart';

class ExploreProvider with ChangeNotifier {
  List<Trip> _allTrips = [];
  List<FuelEntry> _allFuelEntries = [];
  List<ExploreMapMarker> _mapMarkers = [];
  Set<String> _visitedStates = {};

  bool _isLoading = true;
  bool _isMapLoading = true;
  String _selectedCategory = 'All Routes';

  double _statsTotalMiles = 0;
  double _statsFuelCost = 0;
  int _statsTripCount = 0;

  // Getters
  List<Trip> get allTrips => _allTrips;
  List<FuelEntry> get allFuelEntries => _allFuelEntries;
  List<ExploreMapMarker> get mapMarkers => _mapMarkers;
  Set<String> get visitedStates => _visitedStates;
  bool get isLoading => _isLoading;
  bool get isMapLoading => _isMapLoading;
  String get selectedCategory => _selectedCategory;
  double get statsTotalMiles => _statsTotalMiles;
  double get statsFuelCost => _statsFuelCost;
  int get statsTripCount => _statsTripCount;

  static const Set<String> _usStateCodes = {
    'AL',
    'AK',
    'AZ',
    'AR',
    'CA',
    'CO',
    'CT',
    'DE',
    'DC',
    'FL',
    'GA',
    'HI',
    'ID',
    'IL',
    'IN',
    'IA',
    'KS',
    'KY',
    'LA',
    'ME',
    'MD',
    'MA',
    'MI',
    'MN',
    'MS',
    'MO',
    'MT',
    'NE',
    'NV',
    'NH',
    'NJ',
    'NM',
    'NY',
    'NC',
    'ND',
    'OH',
    'OK',
    'OR',
    'PA',
    'RI',
    'SC',
    'SD',
    'TN',
    'TX',
    'UT',
    'VT',
    'VA',
    'WA',
    'WV',
    'WI',
    'WY',
  };

  /// Initialize and load data
  Future<void> loadData({bool forceRefresh = false}) async {
    if (forceRefresh) {
      DataPrefetchService.instance.invalidateCache();
    }

    _isLoading = true;
    notifyListeners();

    try {
      final prefetch = DataPrefetchService.instance;
      List<Trip> trips;
      List<FuelEntry> fuelEntries;

      if (!forceRefresh &&
          prefetch.isPrefetchComplete &&
          prefetch.cachedTrips != null &&
          prefetch.cachedFuelEntries != null) {
        trips = prefetch.cachedTrips!;
        fuelEntries = prefetch.cachedFuelEntries!;
      } else {
        // Fetch concurrently
        final results = await Future.wait([
          TripService.getTrips(),
          FuelService.getFuelEntries(),
        ]);
        trips = results[0] as List<Trip>;
        fuelEntries = results[1] as List<FuelEntry>;
      }

      _allTrips = trips;
      _allFuelEntries = fuelEntries;
      _isLoading = false;

      // Initial stats calculation
      _calculateStats();
      notifyListeners();

      // Generate map markers in background
      await _generateMapMarkers();
    } catch (e) {
      debugPrint('Error loading explore data: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _generateMapMarkers() async {
    _isMapLoading = true;
    notifyListeners();

    final markers = <ExploreMapMarker>[];
    final states = <String>{};

    // Process all trips for markers and states
    for (final trip in _allTrips) {
      // Collect all states from pickup and delivery
      for (final loc in [...trip.pickupLocations, ...trip.deliveryLocations]) {
        final state = ExploreUtils.extractStateCode(loc);
        if (state != null && _usStateCodes.contains(state)) states.add(state);
      }

      // Add marker for the last delivery location
      if (trip.deliveryLocations.isNotEmpty) {
        final loc = trip.deliveryLocations.last;
        final displayLoc = ExploreUtils.extractCityState(loc);

        // Use a cache-friendly approach if GeoService supports it
        final latLng = await GeoService.getCoordinates(displayLoc);
        if (latLng != null) {
          markers.add(
            ExploreMapMarker(
              id:
                  trip.id ??
                  'trip_${trip.tripNumber}_${trip.tripDate.millisecondsSinceEpoch}',
              type: MapMarkerType.trip,
              point: latLng,
              title: 'Trip ${trip.tripNumber}',
              subtitle: displayLoc,
              date: trip.createdAt ?? trip.tripDate,
              data: trip,
            ),
          );
        }
      }
    }

    // Process fuel entries
    for (final fuel in _allFuelEntries) {
      if (fuel.location != null) {
        final state = ExploreUtils.extractStateCode(fuel.location!);
        if (state != null && _usStateCodes.contains(state)) states.add(state);

        final displayLoc = ExploreUtils.extractCityState(fuel.location!);
        final latLng = await GeoService.getCoordinates(displayLoc);
        if (latLng != null) {
          markers.add(
            ExploreMapMarker(
              id: fuel.id ?? 'fuel_${fuel.fuelDate.millisecondsSinceEpoch}',
              type: MapMarkerType.fuel,
              point: latLng,
              title: fuel.isTruckFuel ? 'Truck Fuel' : 'Reefer Fuel',
              subtitle:
                  '${fuel.fuelQuantity.toStringAsFixed(1)} ${fuel.fuelUnitLabel} @ $displayLoc',
              date: fuel.createdAt ?? fuel.fuelDate,
              data: fuel,
            ),
          );
        }
      }
    }

    _mapMarkers = markers;
    _visitedStates = states;
    _isMapLoading = false;
    notifyListeners();
  }

  void _calculateStats() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final monthTrips = _allTrips
        .where((t) => t.tripDate.isAfter(startOfMonth))
        .toList();

    _statsTotalMiles = monthTrips.fold(
      0.0,
      (sum, t) => sum + (t.totalDistance ?? 0),
    );
    _statsTripCount = monthTrips.length;

    final monthFuel = _allFuelEntries
        .where((f) => f.fuelDate.isAfter(startOfMonth))
        .toList();
    _statsFuelCost = monthFuel.fold(0.0, (sum, f) => sum + f.totalCost);
  }

  void setSelectedCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    notifyListeners();
  }

  List<Trip> get filteredTrips {
    switch (_selectedCategory) {
      case 'Long Haul':
        return _allTrips.where((t) => (t.totalDistance ?? 0) > 500).toList();
      case 'Regional':
        return _allTrips
            .where(
              (t) =>
                  (t.totalDistance ?? 0) >= 200 &&
                  (t.totalDistance ?? 0) <= 500,
            )
            .toList();
      case 'Local':
        return _allTrips
            .where(
              (t) => (t.totalDistance ?? 0) < 200 && (t.totalDistance ?? 0) > 0,
            )
            .toList();
      default:
        return _allTrips;
    }
  }

  List<Map<String, dynamic>> get filteredDestinations {
    final trips = filteredTrips;
    final cityData = <String, Map<String, dynamic>>{};

    for (final trip in trips) {
      final uniqueCitiesInTrip = <String>{};
      for (final loc in [...trip.pickupLocations, ...trip.deliveryLocations]) {
        final city = ExploreUtils.extractCityState(loc);
        if (city.isNotEmpty) {
          uniqueCitiesInTrip.add(city);
        }
      }

      for (final city in uniqueCitiesInTrip) {
        if (!cityData.containsKey(city)) {
          cityData[city] = {
            'city': city,
            'count': 0,
            'trips': <Trip>[],
            'totalMiles': 0.0,
          };
        }
        cityData[city]!['count'] = (cityData[city]!['count'] as int) + 1;
        final tripsList = cityData[city]!['trips'] as List<Trip>;
        tripsList.add(trip);
        if (trip.totalDistance != null) {
          cityData[city]!['totalMiles'] =
              (cityData[city]!['totalMiles'] as double) + trip.totalDistance!;
        }
      }
    }

    final sortedCities = cityData.values.toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    return sortedCities.take(5).map((e) {
      final count = e['count'] as int;
      return {
        'city': e['city'],
        'count': count,
        'description': '$count ${count == 1 ? 'trip' : 'trips'}',
        'trips': e['trips'],
        'totalMiles': e['totalMiles'],
      };
    }).toList();
  }

  List<Map<String, dynamic>> get filteredActivity {
    final trips = filteredTrips;
    final List<Map<String, dynamic>> activity = [];

    for (final trip in trips.take(5)) {
      final route =
          trip.pickupLocations.isNotEmpty && trip.deliveryLocations.isNotEmpty
          ? '${ExploreUtils.extractCityState(trip.pickupLocations.first)} → ${ExploreUtils.extractCityState(trip.deliveryLocations.last)}'
          : 'Trip ${trip.tripNumber}';
      activity.add({
        'type': 'trip',
        'title': 'Trip ${trip.tripNumber}',
        'subtitle': route,
        'date': trip.createdAt ?? trip.tripDate,
        'icon': Icons.local_shipping,
        'trip': trip,
      });
    }

    if (_selectedCategory == 'All Routes') {
      for (final fuel in _allFuelEntries.take(5)) {
        final location = fuel.location != null
            ? ExploreUtils.extractCityState(fuel.location!)
            : 'Unknown location';
        activity.add({
          'type': 'fuel',
          'title': fuel.isTruckFuel ? 'Truck Fuel' : 'Reefer Fuel',
          'subtitle':
              '$location • ${fuel.fuelQuantity.toStringAsFixed(1)} ${fuel.fuelUnitLabel}',
          'date': fuel.createdAt ?? fuel.fuelDate,
          'icon': Icons.local_gas_station,
          'fuel': fuel,
        });
      }
    }

    activity.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );
    return activity.take(5).toList();
  }
}
