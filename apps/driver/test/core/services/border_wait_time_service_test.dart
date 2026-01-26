import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:milow/core/services/border_wait_time_service.dart';
import 'package:milow/core/models/border_wait_time.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BorderWaitTimeService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await BorderWaitTimeService.clearCache();
    });

    test('getSavedBorderCrossings returns empty by default', () async {
      final saved = await BorderWaitTimeService.getSavedBorderCrossings();
      expect(saved, isEmpty);
    });

    test('can save and retrieve border crossings', () async {
      final bwt = BorderWaitTime(
        portNumber: 1234,
        border: 'Ambassador Bridge',
        portName: 'Detroit',
        crossingName: 'Bridge',
        hours: '24/7',
        portStatus: 'Open',
        commercialLanesOpen: 2,
        commercialDelay: 10,
        maxLanes: 5,
        operationalStatus: 'Open',
        fastLanesOpen: 0,
        fastLanesDelay: 0,
        fastMaxLanes: 0,
        fastOperationalStatus: 'Closed',
        updateTime: '10:00 AM',
        lanesOpen: 2,
      );

      final added = await BorderWaitTimeService.addBorderCrossing(bwt);
      expect(added, isTrue);

      final saved = await BorderWaitTimeService.getSavedBorderCrossings();
      expect(saved.length, 1);
      expect(saved.first.portNumber, 1234);
      expect(saved.first.crossingName, 'Bridge');
    });

    test('fetchAllWaitTimes returns parsed data from API', () async {
      final mockData = [
        {
          'port_number': '380104',
          'border': 'Ambassador Bridge',
          'port_name': 'Detroit',
          'crossing_name': 'Bridge',
          'hours': '24 hrs/7 days',
          'date': '2026-01-26',
          'time': '12:00',
          'port_status': 'Open',
          'commercial_vehicle_lanes': {
            'maximum_lanes': 14,
            'standard_lanes': {
              'lanes_open': 10,
              'delay_minutes': 15,
              'operational_status': 'Open',
              'update_time': '12:00',
            },
            'FAST_lanes': {
              'maximum_lanes': 4,
              'lanes_open': 2,
              'delay_minutes': 5,
              'operational_status': 'Open',
            },
          },
          'passenger_vehicle_lanes': {
            'maximum_lanes': 20,
            'standard_lanes': {
              'lanes_open': 5,
              'delay_minutes': 0,
              'operational_status': 'Open',
              'update_time': '12:00',
            },
            'NEXUS_SENTRI_lanes': {
              'maximum_lanes': 0,
              'lanes_open': 0,
              'delay_minutes': 0,
              'operational_status': 'N/A',
            },
            'ready_lanes': {
              'maximum_lanes': 0,
              'lanes_open': 0,
              'delay_minutes': 0,
              'operational_status': 'N/A',
            },
          },
          'pedestrian_lanes': {
            'maximum_lanes': 0,
            'standard_lanes': {
              'lanes_open': 0,
              'delay_minutes': 0,
              'operational_status': 'N/A',
              'update_time': '12:00',
            },
            'ready_lanes': {
              'maximum_lanes': 0,
              'lanes_open': 0,
              'delay_minutes': 0,
              'operational_status': 'N/A',
            },
          },
          'construction_notice': 'None',
        },
      ];

      final client = MockClient((request) async {
        return http.Response(jsonEncode(mockData), 200);
      });

      final results = await BorderWaitTimeService.fetchAllWaitTimes(
        forceRefresh: true,
        client: client,
      );

      expect(results, isNotEmpty);
      expect(results.first.portName, 'Detroit');
      expect(results.first.commercialDelay, 15);
      expect(results.first.fastLanesDelay, 5);
    });

    test('fetchAllWaitTimes saves to cache', () async {
      final mockData = [
        {
          'port_number': '380104',
          'border': 'Ambassador Bridge',
          'port_name': 'Detroit',
          'crossing_name': 'Bridge',
          'hours': '24 hrs/7 days',
          'date': '2026-01-26',
          'time': '12:00',
          'port_status': 'Open',
          'commercial_vehicle_lanes': {
            'maximum_lanes': 14,
            'standard_lanes': {
              'lanes_open': 10,
              'delay_minutes': 15,
              'operational_status': 'Open',
              'update_time': '12:00',
            },
            'FAST_lanes': {
              'maximum_lanes': 4,
              'lanes_open': 2,
              'delay_minutes': 5,
              'operational_status': 'Open',
            },
          },
          'passenger_vehicle_lanes': {
            'maximum_lanes': 20,
            'standard_lanes': {
              'lanes_open': 5,
              'delay_minutes': 0,
              'operational_status': 'Open',
              'update_time': '12:00',
            },
            'NEXUS_SENTRI_lanes': {
              'maximum_lanes': 0,
              'lanes_open': 0,
              'delay_minutes': 0,
              'operational_status': 'N/A',
            },
            'ready_lanes': {
              'maximum_lanes': 0,
              'lanes_open': 0,
              'delay_minutes': 0,
              'operational_status': 'N/A',
            },
          },
          'pedestrian_lanes': {
            'maximum_lanes': 0,
            'standard_lanes': {
              'lanes_open': 0,
              'delay_minutes': 0,
              'operational_status': 'N/A',
              'update_time': '12:00',
            },
            'ready_lanes': {
              'maximum_lanes': 0,
              'lanes_open': 0,
              'delay_minutes': 0,
              'operational_status': 'N/A',
            },
          },
          'construction_notice': 'None',
        },
      ];

      final client = MockClient((request) async {
        return http.Response(jsonEncode(mockData), 200);
      });

      await BorderWaitTimeService.fetchAllWaitTimes(
        forceRefresh: true,
        client: client,
      );

      // Should handle cache
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('border_wait_times_cache_v2'), isNotNull);
    });
  });
}
