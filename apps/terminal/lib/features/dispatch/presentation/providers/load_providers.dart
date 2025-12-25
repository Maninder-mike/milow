import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/load.dart';

/// Provider to track if the user is currently in the "New Load" form
final isCreatingLoadProvider = NotifierProvider<IsCreatingLoadNotifier, bool>(
  IsCreatingLoadNotifier.new,
);

class IsCreatingLoadNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle(bool value) => state = value;
}

/// Provider to store the draft load data across navigation
final loadDraftProvider = NotifierProvider<LoadDraftNotifier, Load>(
  LoadDraftNotifier.new,
);

class LoadDraftNotifier extends Notifier<Load> {
  @override
  Load build() => Load.empty();

  void update(Load Function(Load) cb) {
    state = cb(state);
  }

  void reset() => state = Load.empty();
}
