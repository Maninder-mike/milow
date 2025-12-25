// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcement_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(announcementRepository)
const announcementRepositoryProvider = AnnouncementRepositoryProvider._();

final class AnnouncementRepositoryProvider
    extends
        $FunctionalProvider<
          AnnouncementRepository,
          AnnouncementRepository,
          AnnouncementRepository
        >
    with $Provider<AnnouncementRepository> {
  const AnnouncementRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'announcementRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$announcementRepositoryHash();

  @$internal
  @override
  $ProviderElement<AnnouncementRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AnnouncementRepository create(Ref ref) {
    return announcementRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnnouncementRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnnouncementRepository>(value),
    );
  }
}

String _$announcementRepositoryHash() =>
    r'884e4d7b95308d2f719a3f7acc2446e8782bcad5';

@ProviderFor(announcements)
const announcementsProvider = AnnouncementsProvider._();

final class AnnouncementsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Map<String, dynamic>>>,
          List<Map<String, dynamic>>,
          Stream<List<Map<String, dynamic>>>
        >
    with
        $FutureModifier<List<Map<String, dynamic>>>,
        $StreamProvider<List<Map<String, dynamic>>> {
  const AnnouncementsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'announcementsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$announcementsHash();

  @$internal
  @override
  $StreamProviderElement<List<Map<String, dynamic>>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Map<String, dynamic>>> create(Ref ref) {
    return announcements(ref);
  }
}

String _$announcementsHash() => r'9aa05fa4edea5fde4bd05129434304a482b009be';
