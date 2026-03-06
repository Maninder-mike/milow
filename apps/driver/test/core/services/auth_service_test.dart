import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:milow/core/services/auth_service.dart';
import 'package:milow/core/services/local_profile_store.dart';

class FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String path;
  FakePathProvider(this.path);
  @override
  Future<String?> getTemporaryPath() async => path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class MockSession extends Mock implements Session {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder<T> extends Mock
    implements PostgrestFilterBuilder<T> {
  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) {
    Future<U> future;
    if (T == typeOf<List<Map<String, dynamic>>>()) {
      future = Future<T>.value(<Map<String, dynamic>>[] as T).then(onValue);
    } else {
      future = Future<T>.value(null as T).then(onValue);
    }

    if (onError != null) {
      return future.catchError(onError);
    }
    return future;
  }
}

Type typeOf<X>() => X;

void main() {
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late MockSession mockSession;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('auth_service_test_');
    PathProviderPlatform.instance = FakePathProvider(tempDir.path);
    await Hive.initFlutter(tempDir.path);
    await LocalProfileStore.init();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    mockSupabaseClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    mockSession = MockSession();

    when(() => mockSupabaseClient.auth).thenReturn(mockAuth);

    // Clear SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // Clear Hive
    await Hive.box<String>('profiles').clear();
  });

  group('AuthService Tests', () {
    test(
      'isBiometricEnabled and setBiometricEnabled work with SharedPreferences',
      () async {
        // Default is false
        var isEnabled = await AuthService.isBiometricEnabled();
        expect(isEnabled, false);

        // Set to true
        await AuthService.setBiometricEnabled(true);
        isEnabled = await AuthService.isBiometricEnabled();
        expect(isEnabled, true);

        // Set to false
        await AuthService.setBiometricEnabled(false);
        isEnabled = await AuthService.isBiometricEnabled();
        expect(isEnabled, false);
      },
    );

    test('hasValidSession returns true when session exists', () async {
      when(() => mockAuth.currentSession).thenReturn(mockSession);

      final hasSession = await AuthService.hasValidSession(
        supabaseClient: mockSupabaseClient,
      );
      expect(hasSession, true);
    });

    test('hasValidSession returns false when session is null', () async {
      when(() => mockAuth.currentSession).thenReturn(null);

      final hasSession = await AuthService.hasValidSession(
        supabaseClient: mockSupabaseClient,
      );
      expect(hasSession, false);
    });

    test('getCurrentUserEmail returns email', () {
      when(() => mockUser.email).thenReturn('test@example.com');
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      final email = AuthService.getCurrentUserEmail(
        supabaseClient: mockSupabaseClient,
      );
      expect(email, 'test@example.com');
    });

    test('getCurrentUserName returns full_name from metadata', () {
      when(() => mockUser.userMetadata).thenReturn({'full_name': 'John Doe'});
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      final name = AuthService.getCurrentUserName(
        supabaseClient: mockSupabaseClient,
      );
      expect(name, 'John Doe');
    });

    test('signOut clears token, local profile, and signs out', () async {
      final uid = 'test-uid';
      when(() => mockUser.id).thenReturn(uid);
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockFilterBuilder =
          MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();

      when(
        () => mockSupabaseClient.from('profiles'),
      ).thenAnswer((_) => mockQueryBuilder);
      when(
        () => mockQueryBuilder.update({'fcm_token': null}),
      ).thenAnswer((_) => mockFilterBuilder);
      when(
        () => mockFilterBuilder.eq('id', uid),
      ).thenAnswer((_) => mockFilterBuilder);

      // Put dummy profile in Hive to test deletion
      final box = Hive.box<String>('profiles');
      await box.put(uid, '{"id": "$uid", "name": "John Doe"}');

      expect(box.containsKey(uid), true);

      await AuthService.signOut(supabaseClient: mockSupabaseClient);

      // Verify FCM token clear was called
      verify(() => mockSupabaseClient.from('profiles')).called(1);
      verify(() => mockQueryBuilder.update({'fcm_token': null})).called(1);
      verify(() => mockFilterBuilder.eq('id', uid)).called(1);

      // Verify local caching deleted
      expect(box.containsKey(uid), false);

      // Verify sign out
      verify(() => mockAuth.signOut()).called(1);
    });
  });
}
