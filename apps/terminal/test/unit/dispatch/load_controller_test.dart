import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/mockito.dart';
import 'package:terminal/features/dispatch/presentation/providers/load_providers.dart';
import 'package:terminal/features/dispatch/domain/models/load.dart';
import 'package:milow_core/milow_core.dart';

import '../../helpers/mocks.mocks.dart';

void main() {
  late MockLoadRepository mockRepository;
  late ProviderContainer container;

  setUp(() {
    mockRepository = MockLoadRepository();
    container = ProviderContainer(
      overrides: [loadRepositoryProvider.overrideWithValue(mockRepository)],
    );

    // Provide dummy value for Result types (Either<Failure, void>)
    provideDummy<Either<Failure, void>>(right(null));

    // Mock repository methods to return successful Result types
    when(mockRepository.createLoad(any)).thenAnswer((_) async => right(null));
    when(mockRepository.updateLoad(any)).thenAnswer((_) async => right(null));
    when(mockRepository.deleteLoad(any)).thenAnswer((_) async => right(null));
  });

  tearDown(() {
    container.dispose();
  });

  group('LoadController', () {
    test('createLoad calls repository.createLoad', () async {
      // Arrange
      final load = Load.empty().copyWith(brokerName: 'Test Broker');

      // Act
      await container.read(loadControllerProvider.notifier).createLoad(load);

      // Assert
      verify(mockRepository.createLoad(load)).called(1);
    });

    test('updateLoad calls repository.updateLoad', () async {
      // Arrange
      final load = Load.empty().copyWith(
        id: '123',
        brokerName: 'Updated Broker',
      );

      // Act
      await container.read(loadControllerProvider.notifier).updateLoad(load);

      // Assert
      verify(mockRepository.updateLoad(load)).called(1);
    });

    test('deleteLoad calls repository.deleteLoad', () async {
      // Arrange
      const loadId = '123';

      // Act
      await container.read(loadControllerProvider.notifier).deleteLoad(loadId);

      // Assert
      verify(mockRepository.deleteLoad(loadId)).called(1);
    });
  });
}
