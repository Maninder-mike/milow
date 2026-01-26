import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:milow/core/models/border_wait_time.dart';

class BorderWaitTimeService {
  static const String _apiUrl = 'https://bwt.cbp.gov/api/waittimes';

  static const String _cacheKey =
      'border_wait_times_cache_v2'; // Updated to v2 for new format
  static const String _cacheTimeKey = 'border_wait_times_cache_time_v2';
  static const String _savedBordersKey = 'saved_border_crossings';
  static const int _cacheMinutes = 5;
  static const int _maxSavedBorders = 5;

  static List<BorderWaitTime>? _cachedData;
  static DateTime? _lastFetchTime;

  /// Fetch all border wait times from CBP API
  /// Returns cached data if less than 5 minutes old
  static Future<List<BorderWaitTime>> fetchAllWaitTimes({
    bool forceRefresh = false,
    http.Client? client,
  }) async {
    // Check in-memory cache first
    if (!forceRefresh && _cachedData != null && _lastFetchTime != null) {
      final diff = DateTime.now().difference(_lastFetchTime!);
      if (diff.inMinutes < _cacheMinutes) {
        return _cachedData!;
      }
    }

    // Check disk cache
    if (!forceRefresh) {
      final diskCache = await _loadFromDiskCache();
      if (diskCache != null) {
        _cachedData = diskCache;
        return diskCache;
      }
    }

    // Fetch from API
    try {
      final uri = Uri.parse(_apiUrl);

      final response = client != null
          ? await client.get(uri)
          : await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final waitTimes = jsonList
            .map(
              (item) => BorderWaitTime.fromJson(item as Map<String, dynamic>),
            )
            .where((bwt) => bwt.portName.isNotEmpty)
            .toList();

        // Sort by port name
        waitTimes.sort((a, b) => a.portName.compareTo(b.portName));

        // Cache results
        _cachedData = waitTimes;
        _lastFetchTime = DateTime.now();
        await _saveToDiskCache(waitTimes);

        return waitTimes;
      } else {
        debugPrint('[BWT] API returned status: ${response.statusCode}');
        // Return cached data if available
        return _cachedData ?? [];
      }
    } catch (e) {
      debugPrint('[BWT] Error fetching wait times: $e');
      // Return cached data if available
      return _cachedData ?? [];
    }
  }

  /// Get wait times for user's saved border crossings
  static Future<List<BorderWaitTime>> getSavedBorderWaitTimes() async {
    final saved = await getSavedBorderCrossings();
    if (saved.isEmpty) return [];

    final allTimes = await fetchAllWaitTimes();
    final savedIds = saved.map((s) => s.uniqueId).toSet();

    return allTimes.where((bwt) => savedIds.contains(bwt.uniqueId)).toList();
  }

  /// Get list of unique port names for selection
  static Future<List<BorderWaitTime>> getAvailablePorts() async {
    final allTimes = await fetchAllWaitTimes();
    // Group by port and crossing to avoid duplicates
    final Map<String, BorderWaitTime> unique = {};
    for (final bwt in allTimes) {
      unique[bwt.uniqueId] = bwt;
    }
    return unique.values.toList()
      ..sort((a, b) => a.portName.compareTo(b.portName));
  }

  /// Save user's selected border crossings (max 5)
  static Future<void> saveBorderCrossings(
    List<SavedBorderCrossing> crossings,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final limited = crossings.take(_maxSavedBorders).toList();
    final jsonList = limited.map((c) => json.encode(c.toJson())).toList();
    await prefs.setStringList(_savedBordersKey, jsonList);
  }

  /// Get user's saved border crossings
  static Future<List<SavedBorderCrossing>> getSavedBorderCrossings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_savedBordersKey) ?? [];
    return jsonList
        .map(
          (s) => SavedBorderCrossing.fromJson(
            json.decode(s) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  /// Add a border crossing to saved list
  static Future<bool> addBorderCrossing(BorderWaitTime bwt) async {
    final current = await getSavedBorderCrossings();
    if (current.length >= _maxSavedBorders) {
      return false; // Max reached
    }
    // Check if already saved
    if (current.any((c) => c.uniqueId == bwt.uniqueId)) {
      return true; // Already exists
    }
    current.add(
      SavedBorderCrossing(
        portNumber: bwt.portNumber,
        crossingName: bwt.crossingName,
        portName: bwt.portName,
      ),
    );
    await saveBorderCrossings(current);
    return true;
  }

  /// Remove a border crossing from saved list
  static Future<void> removeBorderCrossing(String uniqueId) async {
    final current = await getSavedBorderCrossings();
    current.removeWhere((c) => c.uniqueId == uniqueId);
    await saveBorderCrossings(current);
  }

  /// Check if a border crossing is saved
  static Future<bool> isBorderCrossingSaved(String uniqueId) async {
    final current = await getSavedBorderCrossings();
    return current.any((c) => c.uniqueId == uniqueId);
  }

  // Disk cache helpers
  static Future<List<BorderWaitTime>?> _loadFromDiskCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTime = prefs.getInt(_cacheTimeKey);
      if (cacheTime == null) return null;

      final cachedAt = DateTime.fromMillisecondsSinceEpoch(cacheTime);
      final diff = DateTime.now().difference(cachedAt);
      if (diff.inMinutes >= _cacheMinutes) return null;

      final cacheData = prefs.getString(_cacheKey);
      if (cacheData == null) return null;

      final List<dynamic> jsonList = json.decode(cacheData);
      _lastFetchTime = cachedAt;
      return jsonList
          .map((item) => BorderWaitTime.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[BWT] Error loading disk cache: $e');
      return null;
    }
  }

  static Future<void> _saveToDiskCache(List<BorderWaitTime> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Re-serialize to match API format with nested structure
      final jsonList = data
          .map(
            (bwt) => {
              'port_number': bwt.portNumber,
              'port_name': bwt.portName,
              'crossing_name': bwt.crossingName,
              'port_status': bwt.portStatus,
              'commercial_vehicle_lanes': {
                'maximum_lanes': bwt.maxLanes,
                'standard_lanes': {
                  'lanes_open': bwt.commercialLanesOpen,
                  'delay_minutes': bwt.commercialDelay,
                  'update_time': bwt.updateTime,
                  'operational_status': bwt.operationalStatus,
                },
                'FAST_lanes': {
                  'maximum_lanes': bwt.fastMaxLanes,
                  'lanes_open': bwt.fastLanesOpen,
                  'delay_minutes': bwt.fastLanesDelay,
                  'operational_status': bwt.fastOperationalStatus,
                },
              },
              'hours': bwt.hours,
              'border': bwt.border,
              'time': bwt.time,
              'construction_notice': bwt.constructionNotice,
            },
          )
          .toList();

      await prefs.setString(_cacheKey, json.encode(jsonList));
      await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[BWT] Error saving disk cache: $e');
    }
  }

  /// Clear all cached data
  static Future<void> clearCache() async {
    _cachedData = null;
    _lastFetchTime = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimeKey);
  }
}
