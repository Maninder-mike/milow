import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'app_intents.dart';

/// Default application shortcuts map.
class AppShortcuts {
  static final Map<ShortcutActivator, Intent> defaults = {
    // Cmd+N / Ctrl+N -> New Load
    SingleActivator(
      LogicalKeyboardKey.keyN,
      meta: Platform.isMacOS,
      control: !Platform.isMacOS,
    ): const NewLoadIntent(),

    // Cmd+F / Ctrl+F -> Search
    SingleActivator(
      LogicalKeyboardKey.keyF,
      meta: Platform.isMacOS,
      control: !Platform.isMacOS,
    ): const GlobalSearchIntent(),

    // Cmd+, / Ctrl+, -> Settings
    SingleActivator(
      LogicalKeyboardKey.comma,
      meta: Platform.isMacOS,
      control: !Platform.isMacOS,
    ): const SettingsIntent(),

    // Cmd+R / Ctrl+R -> Refresh
    SingleActivator(
      LogicalKeyboardKey.keyR,
      meta: Platform.isMacOS,
      control: !Platform.isMacOS,
    ): const RefreshDataIntent(),
  };
}
