import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Log levels for categorizing log messages
enum LogLevel { debug, info, warning, error, critical }

/// A logging service that records all app activities to help resolve errors
class LoggingService {
  static LoggingService? _instance;
  static LoggingService get instance => _instance ??= LoggingService._();

  LoggingService._();

  File? _logFile;
  bool _isInitialized = false;
  final List<String> _memoryLogs = [];
  static const int _maxMemoryLogs = 500;
  static const int _maxLogFileSizeBytes = 5 * 1024 * 1024; // 5MB

  /// Initialize the logging service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');

      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _logFile = File('${logDir.path}/milow_$today.log');

      // Create file if it doesn't exist
      if (!await _logFile!.exists()) {
        await _logFile!.create();
        await _writeToFile('=== Milow App Log Started ===');
      }

      // Check file size and rotate if needed
      await _rotateLogIfNeeded();

      _isInitialized = true;
      await log(LogLevel.info, 'LoggingService', 'Logging service initialized');
    } catch (e) {
      debugPrint('Failed to initialize logging service: $e');
    }
  }

  /// Rotate log file if it exceeds max size
  Future<void> _rotateLogIfNeeded() async {
    if (_logFile == null) return;

    try {
      final stat = await _logFile!.stat();
      if (stat.size > _maxLogFileSizeBytes) {
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final backupPath = _logFile!.path.replaceAll('.log', '_$timestamp.log');
        await _logFile!.rename(backupPath);
        _logFile = File(_logFile!.path);
        await _logFile!.create();
        await _writeToFile('=== Log rotated from previous file ===');
      }
    } catch (e) {
      debugPrint('Failed to rotate log: $e');
    }
  }

  /// Clean up old log files (older than 7 days)
  Future<void> cleanOldLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');

      if (!await logDir.exists()) return;

      final files = await logDir.list().toList();
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));

      for (final file in files) {
        if (file is File && file.path.endsWith('.log')) {
          final stat = await file.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await file.delete();
            debugPrint('Deleted old log file: ${file.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to clean old logs: $e');
    }
  }

  /// Main logging method
  Future<void> log(
    LogLevel level,
    String tag,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
  }) async {
    final timestamp = DateFormat(
      'yyyy-MM-dd HH:mm:ss.SSS',
    ).format(DateTime.now());
    final levelStr = level.name.toUpperCase().padRight(8);

    var logEntry = '[$timestamp] [$levelStr] [$tag] $message';

    if (extras != null && extras.isNotEmpty) {
      logEntry += '\n  Extras: $extras';
    }

    if (error != null) {
      logEntry += '\n  Error: $error';
    }

    if (stackTrace != null) {
      logEntry +=
          '\n  StackTrace:\n${stackTrace.toString().split('\n').map((l) => '    $l').join('\n')}';
    }

    // Add to memory logs
    _memoryLogs.add(logEntry);
    if (_memoryLogs.length > _maxMemoryLogs) {
      _memoryLogs.removeAt(0);
    }

    // Print to debug console
    if (kDebugMode) {
      debugPrint(logEntry);
    }

    // Write to file
    await _writeToFile(logEntry);

    // Integrate with Crashlytics for remote monitoring
    try {
      // Use FirebaseCrashlytics.log() for all log entries as breadcrumbs
      unawaited(FirebaseCrashlytics.instance.log(logEntry));

      // Record high-priority errors to Crashlytics as non-fatal
      if (level == LogLevel.error || level == LogLevel.critical) {
        unawaited(
          FirebaseCrashlytics.instance.recordError(
            error ?? message,
            stackTrace,
            reason: '[$tag] $message',
            information: extras != null ? [extras.toString()] : [],
            fatal: level == LogLevel.critical,
          ),
        );
      }
    } catch (e) {
      // Silently fail if Crashlytics is not ready/configured
      if (kDebugMode) {
        debugPrint('Crashlytics logging failed: $e');
      }
    }
  }

  Future<void> _writeToFile(String content) async {
    if (_logFile == null) return;

    try {
      await _logFile!.writeAsString('$content\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('Failed to write to log file: $e');
    }
  }

  // Convenience methods for different log levels

  /// Log debug information
  Future<void> debug(
    String tag,
    String message, {
    Map<String, dynamic>? extras,
  }) async {
    await log(LogLevel.debug, tag, message, extras: extras);
  }

  /// Log general information
  Future<void> info(
    String tag,
    String message, {
    Map<String, dynamic>? extras,
  }) async {
    await log(LogLevel.info, tag, message, extras: extras);
  }

  /// Log warnings
  Future<void> warning(
    String tag,
    String message, {
    Map<String, dynamic>? extras,
  }) async {
    await log(LogLevel.warning, tag, message, extras: extras);
  }

  /// Log errors with optional error object and stack trace
  Future<void> error(
    String tag,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
  }) async {
    await log(
      LogLevel.error,
      tag,
      message,
      error: error,
      stackTrace: stackTrace,
      extras: extras,
    );
  }

  /// Log critical errors
  Future<void> critical(
    String tag,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
  }) async {
    await log(
      LogLevel.critical,
      tag,
      message,
      error: error,
      stackTrace: stackTrace,
      extras: extras,
    );
  }

  // Activity-specific logging methods

  /// Log user navigation events
  Future<void> logNavigation(String from, String to) async {
    await info('Navigation', 'Navigated from $from to $to');
  }

  /// Log user actions (button taps, form submissions, etc.)
  Future<void> logUserAction(
    String action, {
    Map<String, dynamic>? details,
  }) async {
    await info('UserAction', action, extras: details);
  }

  /// Log API calls
  Future<void> logApiCall(
    String endpoint, {
    String method = 'GET',
    int? statusCode,
    String? responseMessage,
    Duration? duration,
  }) async {
    await info(
      'API',
      '$method $endpoint',
      extras: {
        if (statusCode != null) 'statusCode': statusCode,
        if (responseMessage != null) 'response': responseMessage,
        if (duration != null) 'duration': '${duration.inMilliseconds}ms',
      },
    );
  }

  /// Log authentication events
  Future<void> logAuth(
    String event, {
    bool success = true,
    String? userId,
  }) async {
    await info(
      'Auth',
      event,
      extras: {'success': success, if (userId != null) 'userId': userId},
    );
  }

  /// Log data operations (CRUD)
  Future<void> logDataOperation(
    String operation,
    String entity, {
    String? id,
    bool success = true,
  }) async {
    await info(
      'Data',
      '$operation $entity',
      extras: {if (id != null) 'id': id, 'success': success},
    );
  }

  /// Log app lifecycle events
  Future<void> logLifecycle(String event) async {
    await info('Lifecycle', event);
  }

  /// Log performance metrics
  Future<void> logPerformance(String operation, Duration duration) async {
    await debug(
      'Performance',
      '$operation completed',
      extras: {'duration': '${duration.inMilliseconds}ms'},
    );
  }

  /// Get recent logs from memory
  List<String> getRecentLogs({int count = 50}) {
    final start = _memoryLogs.length > count ? _memoryLogs.length - count : 0;
    return _memoryLogs.sublist(start);
  }

  /// Get all logs from current log file
  Future<String> getLogFileContents() async {
    if (_logFile == null || !await _logFile!.exists()) {
      return 'No log file available';
    }

    try {
      return await _logFile!.readAsString();
    } catch (e) {
      return 'Failed to read log file: $e';
    }
  }

  /// Get log file path
  Future<String?> getLogFilePath() async {
    return _logFile?.path;
  }

  /// Get all log files
  Future<List<File>> getAllLogFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');

      if (!await logDir.exists()) return [];

      final files = await logDir.list().toList();
      return files
          .whereType<File>()
          .where((f) => f.path.endsWith('.log'))
          .toList();
    } catch (e) {
      debugPrint('Failed to get log files: $e');
      return [];
    }
  }

  /// Export logs for sharing/debugging
  Future<String> exportLogs() async {
    final buffer = StringBuffer();
    buffer.writeln('=== Milow App Logs Export ===');
    buffer.writeln('Exported at: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');

    // Add current session memory logs
    buffer.writeln('--- Current Session Logs ---');
    for (final log in _memoryLogs) {
      buffer.writeln(log);
    }

    // Add file logs
    buffer.writeln('');
    buffer.writeln('--- File Logs ---');
    buffer.writeln(await getLogFileContents());

    return buffer.toString();
  }

  /// Clear all logs
  Future<void> clearLogs() async {
    _memoryLogs.clear();

    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');

      if (await logDir.exists()) {
        await logDir.delete(recursive: true);
        await logDir.create();
      }

      _isInitialized = false;
      await init();

      await info('LoggingService', 'All logs cleared');
    } catch (e) {
      debugPrint('Failed to clear logs: $e');
    }
  }
}

/// Global logging shortcut
LoggingService get logger => LoggingService.instance;
