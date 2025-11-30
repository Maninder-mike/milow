import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherService {
  // Using Open-Meteo API (free, no API key required)
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  Future<Map<String, dynamic>?> getCurrentWeather() async {
    try {
      // Get current location
      final position = await _getCurrentLocation();
      if (position == null) return null;

      // Fetch weather data
      final url = Uri.parse(
        '$_baseUrl?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,weather_code&temperature_unit=celsius',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'temperature': data['current']['temperature_2m'],
          'weatherCode': data['current']['weather_code'],
        };
      }
    } catch (e) {
      print('Error fetching weather: $e');
    }
    return null;
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition();
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  String getWeatherIcon(int code) {
    // WMO Weather interpretation codes
    if (code == 0) return '☀️'; // Clear
    if (code >= 1 && code <= 3) return '⛅'; // Partly cloudy
    if (code >= 45 && code <= 48) return '🌫️'; // Fog
    if (code >= 51 && code <= 67) return '🌧️'; // Rain
    if (code >= 71 && code <= 77) return '❄️'; // Snow
    if (code >= 80 && code <= 99) return '⛈️'; // Thunderstorm
    return '🌤️'; // Default
  }
}
