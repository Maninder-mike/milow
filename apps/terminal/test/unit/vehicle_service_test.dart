import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:terminal/features/dashboard/services/vehicle_service.dart';

import '../helpers/mocks.mocks.dart';

void main() {
  late VehicleService service;
  late MockSupabaseClient mockClient;
  late MockSupabaseStorageClient mockStorage;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late MockPostgrestFilterBuilder mockFilterBuilder;
  late MockStorageFileApi mockFileApi;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockStorage = MockSupabaseStorageClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    mockFilterBuilder = MockPostgrestFilterBuilder();
    mockFileApi = MockStorageFileApi();

    // 1. Setup Storage Mocks
    when(mockClient.storage).thenReturn(mockStorage);
    when(mockStorage.from(any)).thenReturn(mockFileApi);
    when(mockFileApi.remove(any)).thenAnswer((_) async => []);

    // 2. Setup DB Mocks
    when(mockClient.from(any)).thenAnswer((_) => mockQueryBuilder);
    // PostgrestFilterBuilder is awaitable, so we use thenAnswer to avoid "thenReturn should not return a Future" error
    when(mockQueryBuilder.delete()).thenAnswer((_) => mockFilterBuilder);
    when(mockFilterBuilder.eq(any, any)).thenAnswer((_) => mockFilterBuilder);

    // Stub 'then' to support awaiting the builder
    when(mockFilterBuilder.then(any, onError: anyNamed('onError'))).thenAnswer((
      invocation,
    ) {
      final onValue = invocation.positionalArguments[0];
      return Future.value(onValue(null));
    });

    service = VehicleService(mockClient);
  });

  test(
    'deleteDocument removes file from storage and record from db and logs deleted files',
    () async {
      const docId = 'doc-123';
      const filePath = 'some/path/file.pdf';

      await service.deleteDocument(docId, filePath);

      // Verify Storage Deletion
      final storageCaptor = verify(mockFileApi.remove(captureAny)).captured;
      debugPrint('Deleted file paths: ${storageCaptor.first}');
      expect(storageCaptor.first, equals([filePath]));

      // Verify DB Deletion
      verify(mockClient.from('vehicle_documents')).called(1);
      verify(mockQueryBuilder.delete()).called(1);
      verify(mockFilterBuilder.eq('id', docId)).called(1);
    },
  );
}
