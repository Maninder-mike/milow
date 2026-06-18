import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherInfo {
  final double temperature;
  final double windSpeed;
  final int weatherCode;
  final String description;
  final bool isHighWindWarning;

  WeatherInfo({
    required this.temperature,
    required this.windSpeed,
    required this.weatherCode,
    required this.description,
    required this.isHighWindWarning,
  });
}

class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  Future<WeatherInfo?> fetchWeather(
    double lat,
    double lon,
    bool isImperial, {
    http.Client? client,
  }) async {
    try {
      final temperatureUnit = isImperial ? 'fahrenheit' : 'celsius';
      final windspeedUnit = isImperial ? 'mph' : 'kmh';
      final url = Uri.parse(
        '$_baseUrl?latitude=$lat&longitude=$lon&current_weather=true'
        '&temperature_unit=$temperatureUnit&windspeed_unit=$windspeedUnit',
      );

      final response = client != null
          ? await client.get(url).timeout(const Duration(seconds: 5))
          : await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final current = data['current_weather'] as Map<String, dynamic>?;
        if (current != null) {
          final temp = (current['temperature'] as num).toDouble();
          final wind = (current['windspeed'] as num).toDouble();
          final code = (current['weathercode'] as num).toInt();

          final isHighWindWarning = isImperial ? (wind > 20.0) : (wind > 32.0);

          return WeatherInfo(
            temperature: temp,
            windSpeed: wind,
            weatherCode: code,
            description: _getWeatherDescription(code),
            isHighWindWarning: isHighWindWarning,
          );
        }
      }
    } catch (_) {
      // Return null on failure or timeout
    }
    return null;
  }

  String _getWeatherDescription(int code) {
    switch (code) {
      case 0:
        return 'Clear Sky';
      case 1:
      case 2:
      case 3:
        return 'Partly Cloudy';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Light Drizzle';
      case 56:
      case 57:
        return 'Freezing Drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rainy';
      case 66:
      case 67:
        return 'Freezing Rain';
      case 71:
      case 73:
      case 75:
        return 'Snowfall';
      case 77:
        return 'Snow Grains';
      case 80:
      case 81:
      case 82:
        return 'Rain Showers';
      case 85:
      case 86:
        return 'Snow Showers';
      case 95:
      case 96:
      case 99:
        return 'Thunderstorm';
      default:
        return 'Cloudy';
    }
  }
}
