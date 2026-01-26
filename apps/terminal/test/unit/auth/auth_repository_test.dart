import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:terminal/features/auth/data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/mocks.mocks.dart';

void main() {
  late AuthRepository repository;
  late MockCoreNetworkClient mockClient;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;

  setUp(() {
    mockClient = MockCoreNetworkClient();
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();

    // Chain mocks
    when(mockClient.supabase).thenReturn(mockSupabase);
    when(mockSupabase.auth).thenReturn(mockAuth);

    repository = AuthRepository(mockClient);
  });

  group('AuthRepository', () {
    test('signInWithPassword calls GoTrueClient.signInWithPassword', () async {
      // Arrange
      const email = 'test@example.com';
      const password = 'password';
      when(
        mockAuth.signInWithPassword(email: email, password: password),
      ).thenAnswer((_) async => AuthResponse(session: null, user: null));

      // Act
      final result = await repository.signInWithPassword(email, password);

      // Assert
      verify(
        mockAuth.signInWithPassword(email: email, password: password),
      ).called(1);

      result.fold(
        (failure) => fail('Expected success but got failure: $failure'),
        (_) => null,
      );
    });

    test('signOut calls GoTrueClient.signOut', () async {
      // Arrange
      when(mockAuth.signOut()).thenAnswer((_) async {});

      // Act
      await repository.signOut();

      // Assert
      verify(mockAuth.signOut()).called(1);
    });

    test('currentUser returns correct user', () {
      // Arrange
      final user = User(
        id: '123',
        appMetadata: {},
        userMetadata: {},
        aud: 'aud',
        createdAt: '2023-01-01',
      );
      when(mockAuth.currentUser).thenReturn(user);

      // Act
      final result = repository.currentUser;

      // Assert
      expect(result, user);
      verify(mockAuth.currentUser).called(1);
    });
  });
}
