import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';

import 'package:milow/core/services/profile_service.dart';

class FakeConnectivity extends Fake
    with MockPlatformInterfaceMixin
    implements ConnectivityPlatform {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [
    ConnectivityResult.wifi,
  ];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Stream.value([ConnectivityResult.wifi]);
}

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

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

Type typeOf<X>() => X;

class MockPostgrestTransformBuilder<T> extends Mock
    implements PostgrestTransformBuilder<T> {
  final Object? mockError;
  final T? mockData;
  MockPostgrestTransformBuilder({this.mockError, this.mockData});

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) {
    Future<U> future;
    if (mockError != null) {
      future = Future<U>.error(mockError!);
    } else if (mockData != null) {
      future = Future<T>.value(mockData as T).then(onValue);
    } else if (T == typeOf<Map<String, dynamic>?>()) {
      future = Future<T>.value(null as T).then(onValue);
    } else {
      future = Future<U>.error(UnimplementedError('No mock data for $T'));
    }

    if (onError != null) {
      return future.catchError(onError);
    }
    return future;
  }
}

class MockPostgrestFilterBuilder<T> extends Mock
    implements PostgrestFilterBuilder<T> {
  final Object? mockError;
  final T? mockData;
  MockPostgrestFilterBuilder({this.mockError, this.mockData});

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) {
    Future<U> future;
    if (mockError != null) {
      future = Future<U>.error(mockError!);
    } else if (mockData != null) {
      future = Future<T>.value(mockData as T).then(onValue);
    } else if (T == typeOf<List<Map<String, dynamic>>>()) {
      future = Future<T>.value(<Map<String, dynamic>>[] as T).then(onValue);
    } else if (T == typeOf<Map<String, dynamic>?>()) {
      future = Future<T>.value(null as T).then(onValue);
    } else {
      future = Future<U>.error(UnimplementedError('No mock data for $T'));
    }

    if (onError != null) {
      return future.catchError(onError);
    }
    return future;
  }
}

class MockSupabaseStorageClient extends Mock implements SupabaseStorageClient {}

class MockStorageFileApi extends Mock implements StorageFileApi {}

void main() {
  late Directory tempDir;
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('profile_test_');
    PathProviderPlatform.instance = FakePathProvider(tempDir.path);
    ConnectivityPlatform.instance = FakeConnectivity();
    await Hive.initFlutter(tempDir.path);

    // CoreNetworkClient uses a box named 'network_cache'
    await Hive.openBox('network_cache');

    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const FileOptions());
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

    when(() => mockUser.id).thenReturn('user123');
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockSupabaseClient.auth).thenReturn(mockAuth);

    await Hive.box('network_cache').clear();
  });

  group('ProfileService Tests', () {
    test('getProfile fetches and flattens driver_profiles', () async {
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockFilterBuilder =
          MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();
      final mockFilterBuilderEq =
          MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();
      final mockMaybeSingleBuilder =
          MockPostgrestTransformBuilder<Map<String, dynamic>?>(
            mockData: {
              'id': 'user123',
              'role': 'driver',
              'driver_profiles': {'city': 'TestCity', 'address': 'TestAddr'},
            },
          );

      when(
        () => mockSupabaseClient.from('profiles'),
      ).thenAnswer((_) => mockQueryBuilder);
      when(
        () => mockQueryBuilder.select(any()),
      ).thenAnswer((_) => mockFilterBuilder);
      when(
        () => mockFilterBuilder.eq('id', 'user123'),
      ).thenAnswer((_) => mockFilterBuilderEq);
      when(
        () => mockFilterBuilderEq.maybeSingle(),
      ).thenAnswer((_) => mockMaybeSingleBuilder);

      final result = await ProfileService.getProfile(
        supabaseClient: mockSupabaseClient,
      );

      expect(result, isNotNull);
      expect(result!['id'], 'user123');
      expect(result['role'], 'driver');
      expect(result['city'], 'TestCity'); // Flattened from driver_profiles
      expect(result['address'], 'TestAddr');
      expect(result.containsKey('driver_profiles'), false);
    });

    test(
      'updateProfile correctly splits fields into driver and base updates',
      () async {
        final mockQueryBuilderProfiles = MockSupabaseQueryBuilder();
        final mockQueryBuilderDriver = MockSupabaseQueryBuilder();

        // Need two separate builders to capture updates correctly
        final mockUpdateFilterProfiles =
            MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();
        final mockUpdateEqProfiles =
            MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();

        final mockUpdateFilterDriver =
            MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();
        final mockUpdateEqDriver =
            MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();

        when(
          () => mockSupabaseClient.from('profiles'),
        ).thenAnswer((_) => mockQueryBuilderProfiles);
        when(
          () => mockSupabaseClient.from('driver_profiles'),
        ).thenAnswer((_) => mockQueryBuilderDriver);

        // profiles update stub
        when(
          () => mockQueryBuilderProfiles.update(any()),
        ).thenAnswer((_) => mockUpdateFilterProfiles);
        when(
          () => mockUpdateFilterProfiles.eq('id', 'user123'),
        ).thenAnswer((_) => mockUpdateEqProfiles);

        // driver_profiles update stub
        when(
          () => mockQueryBuilderDriver.update(any()),
        ).thenAnswer((_) => mockUpdateFilterDriver);
        when(
          () => mockUpdateFilterDriver.eq('id', 'user123'),
        ).thenAnswer((_) => mockUpdateEqDriver);

        await ProfileService.updateProfile({
          'city': 'NewCity', // driverFields
          'full_name': 'John Doe', // sharedFields
          'some_other_flag': true, // baseUpdates only
          'role': 'admin', // Should be removed (sensitive)
        }, supabaseClient: mockSupabaseClient);

        // Verify profiles update
        final profilesVerification = verify(
          () => mockQueryBuilderProfiles.update(captureAny()),
        );
        profilesVerification.called(1);
        final Map<dynamic, dynamic> baseUpdates =
            profilesVerification.captured.first;

        expect(baseUpdates['full_name'], 'John Doe'); // Shared
        expect(baseUpdates['some_other_flag'], true); // Base specific
        expect(baseUpdates.containsKey('role'), false); // Filtered out
        expect(baseUpdates.containsKey('city'), false); // Driver only

        // Verify driver_profiles update
        final driverVerification = verify(
          () => mockQueryBuilderDriver.update(captureAny()),
        );
        driverVerification.called(1);
        final Map<dynamic, dynamic> driverUpdates =
            driverVerification.captured.first;

        expect(driverUpdates['city'], 'NewCity'); // Driver specific
        expect(driverUpdates['full_name'], 'John Doe'); // Shared
        expect(
          driverUpdates.containsKey('some_other_flag'),
          false,
        ); // Base only
      },
    );

    test(
      'updateProfile gracefully catches exceptions and suppresses them',
      () async {
        final mockQueryBuilderProfiles = MockSupabaseQueryBuilder();
        final mockUpdateFilterProfiles =
            MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();
        final mockUpdateEqProfiles =
            MockPostgrestFilterBuilder<List<Map<String, dynamic>>>(
              mockError: const PostgrestException(
                message: 'RLS violated',
                code: '42501',
              ),
            );

        final mockQueryBuilderDriver = MockSupabaseQueryBuilder();
        final mockUpdateFilterDriver =
            MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();
        final mockUpdateEqDriver =
            MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();

        when(
          () => mockSupabaseClient.from('profiles'),
        ).thenAnswer((_) => mockQueryBuilderProfiles);
        when(
          () => mockSupabaseClient.from('driver_profiles'),
        ).thenAnswer((_) => mockQueryBuilderDriver);

        when(
          () => mockQueryBuilderProfiles.update(any()),
        ).thenAnswer((_) => mockUpdateFilterProfiles);
        when(
          () => mockUpdateFilterProfiles.eq('id', 'user123'),
        ).thenAnswer((_) => mockUpdateEqProfiles);

        when(
          () => mockQueryBuilderDriver.update(any()),
        ).thenAnswer((_) => mockUpdateFilterDriver);
        when(
          () => mockUpdateFilterDriver.eq('id', 'user123'),
        ).thenAnswer((_) => mockUpdateEqDriver);

        // We just ensure this doesn't throw. LoggingService handles the error silently.
        await ProfileService.updateProfile({
          'some_other_flag': true,
        }, supabaseClient: mockSupabaseClient);

        // No exception thrown up, it's successful.
      },
    );

    test('revokeCompany clears company_id and company_name', () async {
      final mockQueryBuilderProfiles = MockSupabaseQueryBuilder();
      final mockUpdateFilterProfiles =
          MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();
      final mockUpdateEqProfiles =
          MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();

      when(
        () => mockSupabaseClient.from('profiles'),
      ).thenAnswer((_) => mockQueryBuilderProfiles);
      when(
        () => mockQueryBuilderProfiles.update(any()),
      ).thenAnswer((_) => mockUpdateFilterProfiles);
      when(
        () => mockUpdateFilterProfiles.eq('id', 'user123'),
      ).thenAnswer((_) => mockUpdateEqProfiles);
      when(
        () => mockUpdateFilterProfiles.eq('id', 'user123'),
      ).thenAnswer((_) => mockUpdateEqProfiles);

      await ProfileService.revokeCompany(supabaseClient: mockSupabaseClient);

      final verification = verify(
        () => mockQueryBuilderProfiles.update(captureAny()),
      );
      verification.called(1);
      final Map<dynamic, dynamic> updates = verification.captured.first;

      expect(updates['company_id'], isNull);
      expect(updates['company_name'], isNull);
    });

    test('uploadAvatar uploads binary to storage and updates profile', () async {
      final mockStorage = MockSupabaseStorageClient();
      final mockFileApi = MockStorageFileApi();
      final mockQueryBuilderProfiles = MockSupabaseQueryBuilder();
      final mockUpdateFilterProfiles =
          MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();
      final mockUpdateEqProfiles =
          MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();

      when(() => mockSupabaseClient.storage).thenReturn(mockStorage);
      when(() => mockStorage.from('avatars')).thenReturn(mockFileApi);

      // Upload stub
      when(
        () => mockFileApi.uploadBinary(
          any(),
          any(),
          fileOptions: any(named: 'fileOptions'),
        ),
      ).thenAnswer((_) async => 'user123/avatar.png');

      // Public URL stub
      when(() => mockFileApi.getPublicUrl(any())).thenReturn(
        'https://mock.supabase.co/storage/v1/object/public/avatars/user123/avatar.png',
      );

      final mockQueryBuilderDriver = MockSupabaseQueryBuilder();
      final mockUpdateFilterDriver =
          MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();
      final mockUpdateEqDriver =
          MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();

      // Update stub for avatar URL
      when(
        () => mockSupabaseClient.from('profiles'),
      ).thenAnswer((_) => mockQueryBuilderProfiles);
      when(
        () => mockSupabaseClient.from('driver_profiles'),
      ).thenAnswer((_) => mockQueryBuilderDriver);

      when(
        () => mockQueryBuilderProfiles.update(any()),
      ).thenAnswer((_) => mockUpdateFilterProfiles);
      when(
        () => mockUpdateFilterProfiles.eq('id', 'user123'),
      ).thenAnswer((_) => mockUpdateEqProfiles);

      when(
        () => mockQueryBuilderDriver.update(any()),
      ).thenAnswer((_) => mockUpdateFilterDriver);
      when(
        () => mockUpdateFilterDriver.eq('id', 'user123'),
      ).thenAnswer((_) => mockUpdateEqDriver);

      final dummyBytes = Uint8List.fromList([1, 2, 3]);
      final url = await ProfileService.uploadAvatar(
        bytes: dummyBytes,
        filename: 'avatar.png',
        supabaseClient: mockSupabaseClient,
      );

      expect(
        url,
        'https://mock.supabase.co/storage/v1/object/public/avatars/user123/avatar.png',
      );

      verify(
        () => mockFileApi.uploadBinary(
          'user123/avatar.png',
          dummyBytes,
          fileOptions: any(named: 'fileOptions'),
        ),
      ).called(1);

      // Verify avatar_url was updated correctly in base_profile since it's a shared field
      final verification = verify(
        () => mockQueryBuilderProfiles.update(captureAny()),
      );
      verification.called(1);
      final Map<dynamic, dynamic> updates = verification.captured.first;
      expect(
        updates['avatar_url'],
        'https://mock.supabase.co/storage/v1/object/public/avatars/user123/avatar.png',
      );
    });
  });
}
