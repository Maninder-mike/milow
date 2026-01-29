import 'package:flutter/widgets.dart';

/// Intent to create a new load/order.
class NewLoadIntent extends Intent {
  const NewLoadIntent();
}

/// Intent to open global search.
class GlobalSearchIntent extends Intent {
  const GlobalSearchIntent();
}

/// Intent to open settings.
class SettingsIntent extends Intent {
  const SettingsIntent();
}

/// Intent to refresh data.
class RefreshDataIntent extends Intent {
  const RefreshDataIntent();
}

/// Intent to switch to a specific tab index.
class SwitchTabIntent extends Intent {
  final int index;
  const SwitchTabIntent(this.index);
}
