// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tab_manager_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TabManager)
const tabManagerProvider = TabManagerProvider._();

final class TabManagerProvider
    extends $NotifierProvider<TabManager, TabManagerState> {
  const TabManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tabManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tabManagerHash();

  @$internal
  @override
  TabManager create() => TabManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TabManagerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TabManagerState>(value),
    );
  }
}

String _$tabManagerHash() => r'b8f3aaea2bb86be2572ecfed40f23bce492beca0';

abstract class _$TabManager extends $Notifier<TabManagerState> {
  TabManagerState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<TabManagerState, TabManagerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TabManagerState, TabManagerState>,
              TabManagerState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
