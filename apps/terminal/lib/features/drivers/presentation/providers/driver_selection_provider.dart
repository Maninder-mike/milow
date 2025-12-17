import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:milow_core/milow_core.dart';

final selectedDriverProvider =
    NotifierProvider<SelectedDriverNotifier, UserProfile?>(
      SelectedDriverNotifier.new,
    );

class SelectedDriverNotifier extends Notifier<UserProfile?> {
  @override
  UserProfile? build() => null;

  void select(UserProfile? driver) {
    state = driver;
  }
}
