import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherService {
  // Using Open-Meteo API (free, no API key required)
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  Future<Map<String, dynamic>?> getCurrentWeather() async {
    try {
      // Get current location (geolocation first, then IP fallback for web/CORS)
      final coords = await _getCoordinates();
      if (coords == null) return null;

      // Fetch weather data
      final url = Uri.parse(
        '$_baseUrl?latitude=${coords['lat']}&longitude=${coords['lon']}&current=temperature_2m,weather_code,is_day&temperature_unit=celsius',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>;
        return {
          'temperature': current['temperature_2m'],
          'weatherCode': current['weather_code'],
          'isDay': current['is_day'] == 1,
        };
      }
    } catch (e) {
      debugPrint('Error fetching weather: $e');
    }
    return null;
  }

  Future<Map<String, double>?> _getCoordinates() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        // Check permission status without requesting it to avoid startup popups
        final LocationPermission permission =
            await Geolocator.checkPermission();

        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition();
          return {'lat': pos.latitude, 'lon': pos.longitude};
        }
      }

      // Fallback: use IP-based lookup (works on web/https without geolocation)
      final ipCoords = await _getCoordinatesFromIp();
      if (ipCoords != null) return ipCoords;
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
    return null;
  }

  Future<Map<String, double>?> _getCoordinatesFromIp() async {
    try {
      // ipapi has permissive CORS and no key for basic geo info
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final lat = (data['latitude'] as num?)?.toDouble();
        final lon = (data['longitude'] as num?)?.toDouble();
        if (lat != null && lon != null) {
          return {'lat': lat, 'lon': lon};
        }
      }
    } catch (e) {
      debugPrint('IP geolocation failed: $e');
    }
    return null;
  }

  String getWeatherIcon(int code, {bool isDay = true}) {
    // WMO Weather interpretation codes
    if (code == 0) return isDay ? '☀️' : '🌙'; // Clear
    if (code >= 1 && code <= 3) return isDay ? '⛅' : '☁️'; // Partly cloudy
    if (code >= 45 && code <= 48) return '🌫️'; // Fog
    if (code >= 51 && code <= 67) return '🌧️'; // Rain
    if (code >= 71 && code <= 77) return '❄️'; // Snow
    if (code >= 80 && code <= 99) return '⛈️'; // Thunderstorm
    return isDay ? '🌤️' : '🌙'; // Default
  }
}
