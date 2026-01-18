import 'package:flutter/services.dart';

/// Centralized haptic feedback service with M3 Expressive tactile patterns
///
/// Provides consistent haptic feedback across the app, following Material 3
/// design guidelines for tactile feedback.
///
/// Usage:
/// ```dart
/// HapticService.light();    // Toggles, selections
/// HapticService.medium();   // Confirmations, navigation
/// HapticService.heavy();    // Warnings, destructive actions
/// HapticService.success();  // Completion patterns
/// HapticService.error();    // Failure patterns
/// ```
class HapticService {
  HapticService._();

  // ============= BASIC HAPTICS =============

  /// Light haptic for subtle interactions
  /// Use for: Toggles, checkboxes, radio buttons, list selections
  static Future<void> light() async {
    await HapticFeedback.lightImpact();
  }

  /// Medium haptic for confirmations
  /// Use for: Button presses, form submissions, navigation actions
  static Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }

  /// Heavy haptic for significant actions
  /// Use for: Warnings, destructive actions, important confirmations
  static Future<void> heavy() async {
    await HapticFeedback.heavyImpact();
  }

  /// Selection changed haptic
  /// Use for: Picker changes, segment control changes, slider movements
  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }

  // ============= PATTERN HAPTICS =============

  /// Success haptic pattern (double light tap)
  /// Use for: Successful form submissions, completed actions
  static Future<void> success() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }

  /// Error haptic pattern (heavy + vibrate)
  /// Use for: Failed actions, validation errors
  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.vibrate();
  }

  /// Warning haptic pattern (medium + pause + medium)
  /// Use for: Warnings, destructive action confirmations
  static Future<void> warning() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    await HapticFeedback.mediumImpact();
  }

  /// Notification haptic
  /// Use for: New messages, alerts, notifications
  static Future<void> notification() async {
    await HapticFeedback.vibrate();
  }

  // ============= CONTEXT-SPECIFIC HAPTICS =============

  /// Pull-to-refresh haptic (when threshold is reached)
  static Future<void> pullToRefresh() async {
    await HapticFeedback.mediumImpact();
  }

  /// Long press haptic
  static Future<void> longPress() async {
    await HapticFeedback.heavyImpact();
  }

  /// Swipe action haptic
  static Future<void> swipe() async {
    await HapticFeedback.lightImpact();
  }

  /// Delete/destructive action haptic
  static Future<void> destructive() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.heavyImpact();
  }

  /// Tab change haptic
  static Future<void> tabChange() async {
    await HapticFeedback.selectionClick();
  }

  /// Button tap haptic (for important buttons)
  static Future<void> buttonTap() async {
    await HapticFeedback.lightImpact();
  }

  /// Form field focus haptic
  static Future<void> fieldFocus() async {
    await HapticFeedback.selectionClick();
  }
}
