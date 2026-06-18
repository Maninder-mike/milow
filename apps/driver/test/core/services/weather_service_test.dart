import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:milow/core/services/weather_service.dart';

void main() {
  group('WeatherService Tests', () {
    test('fetchWeather returns correct WeatherInfo on success (Imperial)', () async {
      final mockResponse = {
        'current_weather': {
          'temperature': 72.5,
          'windspeed': 15.0,
          'weathercode': 1,
        }
      };

      final client = MockClient((request) async {
        expect(request.url.queryParameters['latitude'], '37.7749');
        expect(request.url.queryParameters['longitude'], '-122.4194');
        expect(request.url.queryParameters['temperature_unit'], 'fahrenheit');
        expect(request.url.queryParameters['windspeed_unit'], 'mph');
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final result = await WeatherService.instance.fetchWeather(
        37.7749,
        -122.4194,
        true,
        client: client,
      );

      expect(result, isNotNull);
      expect(result!.temperature, 72.5);
      expect(result.windSpeed, 15.0);
      expect(result.weatherCode, 1);
      expect(result.isHighWindWarning, false);
      expect(result.description, 'Partly Cloudy');
    });

    test('fetchWeather sets high wind warning correctly (Imperial > 20mph)', () async {
      final mockResponse = {
        'current_weather': {
          'temperature': 50.0,
          'windspeed': 22.5,
          'weathercode': 3,
        }
      };

      final client = MockClient((request) async {
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final result = await WeatherService.instance.fetchWeather(
        37.7749,
        -122.4194,
        true,
        client: client,
      );

      expect(result, isNotNull);
      expect(result!.windSpeed, 22.5);
      expect(result.isHighWindWarning, true);
    });

    test('fetchWeather sets high wind warning correctly (Metric > 32kmh)', () async {
      final mockResponse = {
        'current_weather': {
          'temperature': 10.0,
          'windspeed': 35.0,
          'weathercode': 3,
        }
      };

      final client = MockClient((request) async {
        expect(request.url.queryParameters['temperature_unit'], 'celsius');
        expect(request.url.queryParameters['windspeed_unit'], 'kmh');
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final result = await WeatherService.instance.fetchWeather(
        37.7749,
        -122.4194,
        false,
        client: client,
      );

      expect(result, isNotNull);
      expect(result!.windSpeed, 35.0);
      expect(result.isHighWindWarning, true);
    });

    test('fetchWeather returns null on non-200 response', () async {
      final client = MockClient((request) async {
        return http.Response('Error', 400);
      });

      final result = await WeatherService.instance.fetchWeather(
        37.7749,
        -122.4194,
        true,
        client: client,
      );

      expect(result, isNull);
    });

    test('fetchWeather returns null on timeout/error', () async {
      final client = MockClient((request) async {
        throw Exception('Timeout');
      });

      final result = await WeatherService.instance.fetchWeather(
        37.7749,
        -122.4194,
        true,
        client: client,
      );

      expect(result, isNull);
    });
  });
}
