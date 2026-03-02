import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milow_core/milow_core.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@GenerateMocks([SupabaseClient])
import 'core_network_client_coalescing_test.mocks.dart';

class FakeConnectivity extends Fake implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [
    ConnectivityResult.wifi,
  ];
}

void main() {
  late MockSupabaseClient mockSupabase;
  late FakeConnectivity fakeConnectivity;
  late CoreNetworkClient client;
  late NetworkCoalescer coalescer;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    fakeConnectivity = FakeConnectivity();
    coalescer = NetworkCoalescer();
    client = CoreNetworkClient(
      mockSupabase,
      coalescer: coalescer,
      connectivity: fakeConnectivity,
    );
  });

  group('CoreNetworkClient Coalescing', () {
    test('should coalesce identical requests when key is provided', () async {
      int callCount = 0;
      final completer = Completer<String>();

      Future<String> delayedOperation() async {
        callCount++;
        return completer.future;
      }

      // Launch two requests in parallel with the same key
      final future1 = client.query(delayedOperation, coalesceKey: 'test-key');
      final future2 = client.query(delayedOperation, coalesceKey: 'test-key');

      // Yield to allow async connection check and coalescing logic to start
      await Future.delayed(Duration.zero);

      // Verify only one operation started
      expect(callCount, 1);
      expect(coalescer.inflightCount, 1);

      // Complete the operation
      completer.complete('success');

      final result1 = await future1;
      final result2 = await future2;

      // Verify both received the same result
      expect(result1.isRight(), true);
      expect(result2.isRight(), true);
      expect(result1, result2);

      // Verify cleanup
      expect(coalescer.inflightCount, 0);
    });

    test('should NOT coalesce requests with different keys', () async {
      int callCount = 0;

      Future<String> operation() async {
        callCount++;
        return 'success';
      }

      await Future.wait([
        client.query(operation, coalesceKey: 'key1'),
        client.query(operation, coalesceKey: 'key2'),
      ]);

      expect(callCount, 2);
    });

    test('should NOT coalesce requests without key', () async {
      int callCount = 0;

      Future<String> operation() async {
        callCount++;
        return 'success';
      }

      await Future.wait([client.query(operation), client.query(operation)]);

      expect(callCount, 2);
    });
  });
}
