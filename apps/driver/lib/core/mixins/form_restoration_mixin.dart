import 'package:flutter/material.dart';

/// Mixin to handle state restoration for forms.
///
/// Usage:
/// ```dart
/// class _MyFormState extends State<MyForm> with RestorationMixin, FormRestorationMixin {
///   @override
///   String get restorationId => 'my_form';
///
///   @override
///   void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
///     registerForRestoration(myController, 'my_controller');
///   }
/// }
/// ```
mixin FormRestorationMixin<T extends StatefulWidget>
    on State<T>, RestorationMixin<T> {
  // Helper for registering text controllers easily
  // In standard RestorationMixin, you typically use RestorableTextEditingController.
  // This mixin can provide wrappers or standard patterns if needed.
  // For now, it serves as a semantic marker and potential extension point.

  /// Register a list of RestorableProperties
  void registerProperties(Map<String, RestorableProperty> properties) {
    for (final entry in properties.entries) {
      registerForRestoration(entry.value, entry.key);
    }
  }
}
