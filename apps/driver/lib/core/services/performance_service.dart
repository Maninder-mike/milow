import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

/// Service for tracking app performance metrics.
///
/// Automatically tracks:
/// - Network request latency
/// - App startup time
/// - Screen rendering performance
///
/// Custom traces can be added for specific code paths.
class PerformanceService {
  static final PerformanceService instance = PerformanceService._internal();
  factory PerformanceService() => instance;
  PerformanceService._internal();

  final FirebasePerformance _performance = FirebasePerformance.instance;
  bool _initialized = false;

  /// Initialize performance monitoring
  Future<void> init() async {
    if (_initialized) return;

    // Disable in debug mode for cleaner logs
    await _performance.setPerformanceCollectionEnabled(!kDebugMode);
    _initialized = true;
    debugPrint('[Performance] Initialized');
  }

  // ==================== CUSTOM TRACES ====================

  /// Start a custom trace for measuring code performance
  Future<Trace> startTrace(String name) async {
    final trace = _performance.newTrace(name);
    await trace.start();
    return trace;
  }

  /// Create a trace for async operations
  Future<T> traceAsync<T>(String name, Future<T> Function() operation) async {
    final trace = await startTrace(name);
    try {
      final result = await operation();
      await trace.stop();
      return result;
    } catch (e) {
      trace.putAttribute('error', e.toString().substring(0, 100));
      await trace.stop();
      rethrow;
    }
  }

  // ==================== HTTP METRICS ====================

  /// Create HTTP metric for manual network tracking
  HttpMetric newHttpMetric(String url, HttpMethod method) {
    return _performance.newHttpMetric(url, method);
  }

  /// Track an HTTP request
  Future<T> trackHttpRequest<T>({
    required String url,
    required HttpMethod method,
    required Future<T> Function() request,
    int? responseCode,
    int? requestPayloadSize,
    int? responsePayloadSize,
  }) async {
    final metric = newHttpMetric(url, method);
    await metric.start();

    try {
      final result = await request();

      if (requestPayloadSize != null) {
        metric.requestPayloadSize = requestPayloadSize;
      }
      if (responsePayloadSize != null) {
        metric.responsePayloadSize = responsePayloadSize;
      }
      if (responseCode != null) {
        metric.httpResponseCode = responseCode;
      }

      await metric.stop();
      return result;
    } catch (e) {
      metric.httpResponseCode = 0;
      await metric.stop();
      rethrow;
    }
  }

  // ==================== COMMON TRACES ====================

  /// Trace trip creation
  Future<Trace> startTripCreationTrace() => startTrace('trip_creation');

  /// Trace fuel entry submission
  Future<Trace> startFuelSubmitTrace() => startTrace('fuel_submit');

  /// Trace expense submission
  Future<Trace> startExpenseSubmitTrace() => startTrace('expense_submit');

  /// Trace document upload
  Future<Trace> startDocumentUploadTrace() => startTrace('document_upload');

  /// Trace sync operation
  Future<Trace> startSyncTrace() => startTrace('sync_operation');

  /// Trace receipt scanning
  Future<Trace> startReceiptScanTrace() => startTrace('receipt_scan');
}

/// Global instance
final performanceService = PerformanceService.instance;
