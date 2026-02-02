import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Service for tracking user events and journeys.
///
/// Provides an abstraction over Firebase Analytics to track key user actions.
/// Never call Firebase directly - always use this service.
class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._internal();
  factory AnalyticsService() => instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  bool _initialized = false;

  /// Initialize analytics
  Future<void> init() async {
    if (_initialized) return;

    // Enable analytics collection (can be disabled for debug builds)
    await _analytics.setAnalyticsCollectionEnabled(!kDebugMode);
    _initialized = true;
    debugPrint('[Analytics] Initialized');
  }

  /// Set user ID for cross-session tracking
  Future<void> setUserId(String? userId) async {
    await _analytics.setUserId(id: userId);
  }

  /// Set user properties
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    await _analytics.setUserProperty(name: name, value: value);
  }

  // ==================== AUTHENTICATION ====================

  Future<void> logLogin({String? method}) async {
    await _analytics.logLogin(loginMethod: method);
  }

  Future<void> logSignUp({String? method}) async {
    await _analytics.logSignUp(signUpMethod: method ?? 'email');
  }

  Future<void> logLogout() async {
    await _analytics.logEvent(name: 'logout');
  }

  // ==================== TRIPS ====================

  Future<void> logTripCreated({
    required String tripNumber,
    int? pickupCount,
    int? deliveryCount,
  }) async {
    final params = <String, Object>{'trip_number': tripNumber};
    if (pickupCount != null) params['pickup_count'] = pickupCount;
    if (deliveryCount != null) params['delivery_count'] = deliveryCount;
    await _analytics.logEvent(name: 'trip_created', parameters: params);
  }

  Future<void> logTripCompleted({
    required String tripNumber,
    double? totalMiles,
  }) async {
    final params = <String, Object>{'trip_number': tripNumber};
    if (totalMiles != null) params['total_miles'] = totalMiles;
    await _analytics.logEvent(name: 'trip_completed', parameters: params);
  }

  // ==================== FUEL ENTRIES ====================

  Future<void> logFuelEntryAdded({
    double? gallons,
    double? totalCost,
    String? currency,
  }) async {
    final params = <String, Object>{};
    if (gallons != null) params['gallons'] = gallons;
    if (totalCost != null) params['total_cost'] = totalCost;
    if (currency != null) params['currency'] = currency;
    await _analytics.logEvent(name: 'fuel_entry_added', parameters: params);
  }

  // ==================== EXPENSES ====================

  Future<void> logExpenseAdded({
    required String category,
    double? amount,
    String? currency,
  }) async {
    final params = <String, Object>{'category': category};
    if (amount != null) params['amount'] = amount;
    if (currency != null) params['currency'] = currency;
    await _analytics.logEvent(name: 'expense_added', parameters: params);
  }

  // ==================== DOCUMENTS ====================

  Future<void> logDocumentScanned({required String documentType}) async {
    await _analytics.logEvent(
      name: 'document_scanned',
      parameters: {'document_type': documentType},
    );
  }

  Future<void> logDocumentExported({
    required String format,
    int? recordCount,
  }) async {
    final params = <String, Object>{'format': format};
    if (recordCount != null) params['record_count'] = recordCount;
    await _analytics.logEvent(name: 'document_exported', parameters: params);
  }

  // ==================== SCREENS ====================

  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    // Analytics
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );

    // Crashlytics Context
    if (!kDebugMode) {
      unawaited(
        FirebaseCrashlytics.instance.setCustomKey('last_screen', screenName),
      );
      unawaited(FirebaseCrashlytics.instance.log('Screen View: $screenName'));
    }
  }

  // ==================== FEATURES ====================

  Future<void> logFeatureUsed({
    required String featureName,
    Map<String, Object>? parameters,
  }) async {
    await _analytics.logEvent(
      name: 'feature_used',
      parameters: {'feature_name': featureName, ...?parameters},
    );
  }

  // ==================== FUNNELS & JOURNEYS ====================

  /// Log a step in a multi-step funnel
  Future<void> logFunnelStep({
    required String funnelName,
    required int step,
    required String stepName,
  }) async {
    await _analytics.logEvent(
      name: 'funnel_step',
      parameters: {
        'funnel_name': funnelName,
        'step_number': step,
        'step_name': stepName,
      },
    );
  }

  /// Start a user journey (marker event)
  Future<void> logUserJourneyStart(String journeyName) async {
    await _analytics.logEvent(
      name: 'journey_start',
      parameters: {'journey_name': journeyName},
    );
  }

  /// Complete a user journey with duration
  Future<void> logUserJourneyComplete({
    required String journeyName,
    Duration? duration,
    bool success = true,
  }) async {
    final params = <String, Object>{
      'journey_name': journeyName,
      'success': success,
    };
    if (duration != null) {
      params['duration_ms'] = duration.inMilliseconds;
    }
    await _analytics.logEvent(name: 'journey_complete', parameters: params);
  }

  // ==================== GENERIC ====================

  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }
}

/// Global instance
final analyticsService = AnalyticsService.instance;
