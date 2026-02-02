import 'package:flutter/widgets.dart';
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
class PerformanceService with WidgetsBindingObserver {
  static final PerformanceService instance = PerformanceService._internal();
  factory PerformanceService() => instance;
  PerformanceService._internal();

  final FirebasePerformance _performance = FirebasePerformance.instance;
  bool _initialized = false;

  /// Initialize performance monitoring
  Future<void> init() async {
    if (_initialized) return;

    // Register observer for memory pressure events
    WidgetsBinding.instance.addObserver(this);

    // Disable in debug mode for cleaner logs
    await _performance.setPerformanceCollectionEnabled(!kDebugMode);
    _initialized = true;
    debugPrint('[Performance] Initialized');
  }

  @override
  void didHaveMemoryPressure() {
    debugPrint(
      '[Performance] Memory pressure detected. Clearing image caches.',
    );
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (e) {
      debugPrint('[Performance] Failed to clear image cache: $e');
    }
  }

  // ==================== STARTUP METRICS ====================

  Trace? _coldStartTrace;

  /// Start tracing app cold start time.
  /// Should be called as early as possible in main().
  Future<void> startColdStartTrace() async {
    if (!kReleaseMode) return; // Only trace in release mode to avoid noise
    try {
      _coldStartTrace = await startTrace('cold_start');
      debugPrint('[Performance] Cold start trace started');
    } catch (e) {
      debugPrint('[Performance] Failed to start cold start trace: $e');
    }
  }

  /// Stop cold start trace.
  /// Should be called when the first frame is rendered or home screen is ready.
  Future<void> stopColdStartTrace() async {
    if (_coldStartTrace != null) {
      await _coldStartTrace!.stop();
      _coldStartTrace = null;
      debugPrint('[Performance] Cold start trace completed');
    }
  }

  /// Log a specific milestone during startup
  void logStartupMilestone(String milestone, {int? durationMs}) {
    debugPrint(
      '[Performance] Startup Milestone: $milestone ${durationMs != null ? "(${durationMs}ms)" : ""}',
    );
    _coldStartTrace?.putAttribute(
      'milestone_${DateTime.now().millisecondsSinceEpoch}',
      milestone,
    );
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
