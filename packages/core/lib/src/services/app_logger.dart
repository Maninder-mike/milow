import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../utils/failure.dart';

/// Severity of a log message.
enum LogLevel { debug, info, warning, error, fatal }

/// A centralized logger for the Milow application.
///
/// Replaces `debugPrint` with structured logging.
/// - In debug mode: logs to console.
/// - In release mode: logs errors/fatals to Firebase Crashlytics.
///
/// Usage:
/// ```dart
/// AppLogger.info('User logged in', context: {'userId': user.id});
/// AppLogger.error('Failed to fetch loads', error: e, stackTrace: st);
/// ```
class AppLogger {
  AppLogger._();

  static String? _userId;
  static String? _appVersion;

  /// Initialize the logger with context that will be attached to all log entries.
  static void initialize({String? userId, String? appVersion}) {
    _userId = userId;
    _appVersion = appVersion;
    if (userId != null) {
      FirebaseCrashlytics.instance.setUserIdentifier(userId);
    }
    if (appVersion != null) {
      FirebaseCrashlytics.instance.setCustomKey('app_version', appVersion);
    }
  }

  /// Update user context (e.g., after login).
  static void setUser(String userId) {
    _userId = userId;
    FirebaseCrashlytics.instance.setUserIdentifier(userId);
  }

  /// Log a debug message. Only logged in debug mode.
  static void debug(String message, {Map<String, dynamic>? context}) {
    _log(LogLevel.debug, message, context: context);
  }

  /// Log an informational message.
  static void info(String message, {Map<String, dynamic>? context}) {
    _log(LogLevel.info, message, context: context);
  }

  /// Log a warning message.
  static void warning(String message, {Map<String, dynamic>? context}) {
    _log(LogLevel.warning, message, context: context);
  }

  /// Log an error. This will be sent to Crashlytics in release mode.
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    _log(
      LogLevel.error,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Log a fatal error. This will always be sent to Crashlytics.
  static void fatal(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    _log(
      LogLevel.fatal,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  static void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final logContext = {
      if (_userId != null) 'userId': _userId,
      if (_appVersion != null) 'appVersion': _appVersion,
      ...?context,
    };

    final formattedMessage =
        '[$timestamp] [${level.name.toUpperCase()}] $message';
    final contextString = logContext.isNotEmpty
        ? ' | Context: $logContext'
        : '';

    // Always log to console in debug mode
    if (kDebugMode) {
      debugPrint('$formattedMessage$contextString');
      if (error != null) {
        if (error is Failure) {
          debugPrint('  ErrorType: ${error.runtimeType}');
          debugPrint('  Error: ${error.message}');
        } else {
          debugPrint('  Error: $error');
        }
      }

      final st = stackTrace ?? (error is Failure ? error.stackTrace : null);
      if (st != null) {
        debugPrint('  StackTrace: $st');
      }
    }

    // In release mode, send errors and fatals to Crashlytics
    if (!kDebugMode) {
      // Log breadcrumbs for info/warning
      if (level == LogLevel.info || level == LogLevel.warning) {
        FirebaseCrashlytics.instance.log(formattedMessage);
      }

      // Record errors for error/fatal levels
      if (level == LogLevel.error || level == LogLevel.fatal) {
        FirebaseCrashlytics.instance.recordError(
          error ?? Exception(message),
          stackTrace ?? StackTrace.current,
          reason: message,
          fatal: level == LogLevel.fatal,
        );
      }
    }
  }
}
