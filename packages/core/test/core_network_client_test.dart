import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:milow_core/milow_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@GenerateMocks([SupabaseClient])
import 'core_network_client_test.mocks.dart';

class FakeConnectivity extends Fake implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [
    ConnectivityResult.wifi,
  ];
}

void main() {
  late MockSupabaseClient mockSupabaseClient;
  late FakeConnectivity fakeConnectivity;
  late CoreNetworkClient client;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    fakeConnectivity = FakeConnectivity();
    client = CoreNetworkClient(
      mockSupabaseClient,
      connectivity: fakeConnectivity,
    );
  });

  group('CoreNetworkClient', () {
    test('query returns data on success', () async {
      final result = await client.query(
        () async => 'Success',
        operationName: 'success_test',
      );

      result.fold(
        (failure) => fail('Should succeed'),
        (data) => expect(data, 'Success'),
      );
    });

    test('query maps SocketException to NetworkFailure', () async {
      // RetryOptions(maxAttempts: 3) means 3 total attempts.
      int calls = 0;
      final result = await client.query(() async {
        calls++;
        throw const SocketException('No Internet');
      }, operationName: 'network_fail_test');

      expect(calls, 3, reason: 'Should retry 3 times total');
      expect(result.fold((l) => l, (r) => null), isA<NetworkFailure>());
    });

    test('query maps PostgrestException to ServerFailure', () async {
      final result = await client.query(
        () async => throw const PostgrestException(message: 'Error'),
        operationName: 'server_fail_test',
      );

      expect(result.fold((l) => l, (r) => null), isA<ServerFailure>());
    });
  });
}
