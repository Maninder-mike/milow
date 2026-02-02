import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow/core/services/auth_resilience_service.dart';
import 'package:milow/core/services/connectivity_service.dart';

import 'auth_resilience_service_test.mocks.dart';

@GenerateMocks([SupabaseClient, GoTrueClient, ConnectivityService])
void main() {
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockAuthClient;
  late MockConnectivityService mockConnectivityService;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockAuthClient = MockGoTrueClient();
    mockConnectivityService = MockConnectivityService();

    when(mockSupabaseClient.auth).thenReturn(mockAuthClient);
    when(
      mockAuthClient.onAuthStateChange,
    ).thenAnswer((_) => const Stream.empty());
    when(mockAuthClient.currentSession).thenReturn(null);
    when(
      mockConnectivityService.onConnectivityChanged,
    ).thenAnswer((_) => const Stream.empty());
  });

  group('AuthResilienceService', () {
    test('can be initialized with mocks', () {
      final service = AuthResilienceService.instance;
      service.init(
        supabaseClient: mockSupabaseClient,
        connectivityService: mockConnectivityService,
      );
      expect(service, isNotNull);
    });
  });
}
