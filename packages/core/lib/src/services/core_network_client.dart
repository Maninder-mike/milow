import 'dart:async';
import 'dart:math';

import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/failure.dart';
import 'app_logger.dart';
import 'network_coalescer.dart';

/// Configuration for the [CoreNetworkClient].
class NetworkClientConfig {
  /// Maximum number of retry attempts.
  final int maxRetries;

  /// Initial delay for exponential backoff.
  final Duration initialDelay;

  /// Maximum delay between retries.
  final Duration maxDelay;

  /// Number of consecutive failures to trip the circuit breaker.
  final int circuitBreakerThreshold;

  /// Duration for which the circuit remains open before allowing a retry.
  final Duration circuitBreakerResetDuration;

  const NetworkClientConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 16),
    this.circuitBreakerThreshold = 5,
    this.circuitBreakerResetDuration = const Duration(seconds: 30),
  });
}

/// State of the circuit breaker.
enum CircuitState { closed, open, halfOpen }

/// A resilient network client with retry logic and circuit breaker pattern.
///
/// Usage:
/// ```dart
/// final client = CoreNetworkClient(Supabase.instance.client);
/// final result = await client.query(() => supabase.from('loads').select());
/// result.fold(
///   (failure) => handleError(failure),
///   (data) => handleSuccess(data),
/// );
/// ```
class CoreNetworkClient {
  final SupabaseClient _supabase;
  final NetworkClientConfig config;
  final NetworkCoalescer _coalescer;

  // Circuit breaker state
  CircuitState _circuitState = CircuitState.closed;
  int _consecutiveFailures = 0;
  DateTime? _circuitOpenedAt;

  CoreNetworkClient(
    this._supabase, {
    this.config = const NetworkClientConfig(),
    NetworkCoalescer? coalescer,
  }) : _coalescer = coalescer ?? networkCoalescer;

  /// Access the underlying Supabase client (for advanced use cases).
  SupabaseClient get supabase => _supabase;

  /// Current state of the circuit breaker.
  CircuitState get circuitState => _circuitState;

  /// Execute a query with retry logic and circuit breaker.
  ///
  /// [operation] is a function that performs the Supabase query.
  /// [operationName] is used for logging purposes.
  Future<Result<T>> query<T>(
    Future<T> Function() operation, {
    String operationName = 'query',
    String? coalesceKey,
  }) async {
    // If a coalesce key is provided, wrap the operation
    if (coalesceKey != null) {
      return _coalescer.coalesce<Result<T>>(
        coalesceKey,
        () => _executeWithRetry(operation, operationName),
      );
    }
    return _executeWithRetry(operation, operationName);
  }

  Future<Result<T>> _executeWithRetry<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    // Check circuit breaker
    if (_circuitState == CircuitState.open) {
      if (_shouldAttemptReset()) {
        _circuitState = CircuitState.halfOpen;
        AppLogger.info('Circuit breaker half-open, attempting reset probe.');
      } else {
        AppLogger.warning(
          'Circuit breaker is open, rejecting request.',
          context: {'operation': operationName},
        );
        return left(
          const ServerFailure(
            'Service temporarily unavailable. Please try again later.',
          ),
        );
      }
    }

    // Retry logic with exponential backoff
    int attempt = 0;
    Duration delay = config.initialDelay;

    while (attempt < config.maxRetries) {
      try {
        AppLogger.debug(
          'Executing $operationName (attempt ${attempt + 1}/${config.maxRetries})',
        );
        final result = await operation();

        // Success: reset circuit breaker state
        _onSuccess();
        return right(result);
      } catch (e, stackTrace) {
        attempt++;
        final failure = _mapException(e, stackTrace);

        AppLogger.warning(
          'Attempt $attempt failed for $operationName',
          context: {'error': e.toString()},
        );

        // Non-retryable errors
        if (!_isRetryable(failure)) {
          _onFailure();
          AppLogger.error(
            'Non-retryable error for $operationName',
            error: e,
            stackTrace: stackTrace,
          );
          return left(failure);
        }

        // Max retries reached
        if (attempt >= config.maxRetries) {
          _onFailure();
          AppLogger.error(
            'Max retries ($attempt) reached for $operationName',
            error: e,
            stackTrace: stackTrace,
          );
          return left(failure);
        }

        // Wait before next retry (exponential backoff with jitter)
        final jitter = Duration(milliseconds: Random().nextInt(500));
        final waitDuration = delay + jitter;
        AppLogger.debug(
          'Waiting ${waitDuration.inMilliseconds}ms before retry...',
        );
        await Future.delayed(waitDuration);

        // Increase delay for next attempt
        delay = Duration(
          milliseconds: min(
            delay.inMilliseconds * 2,
            config.maxDelay.inMilliseconds,
          ),
        );
      }
    }

    // Should not reach here, but return failure just in case
    return left(const UnexpectedFailure('Retry loop exited unexpectedly.'));
  }

  /// Map exceptions to typed Failure objects.
  Failure _mapException(Object e, StackTrace stackTrace) {
    if (e is PostgrestException) {
      final code = e.code;
      final message = e.message;

      if (code == '401' || code == 'PGRST301') {
        return UnauthorizedFailure(message, stackTrace);
      }
      if (code == '403') {
        return ForbiddenFailure(message, stackTrace);
      }
      if (code == '404' || code == 'PGRST116') {
        return NotFoundFailure(message, stackTrace);
      }
      // Server errors (5xx style)
      if (code != null && code.startsWith('5')) {
        return ServerFailure(
          message,
          statusCode: int.tryParse(code),
          stackTrace: stackTrace,
        );
      }
      return ServerFailure(message, stackTrace: stackTrace);
    }

    if (e is AuthException) {
      return UnauthorizedFailure(e.message, stackTrace);
    }

    if (e is TimeoutException) {
      return TimeoutFailure('Request timed out.', stackTrace);
    }

    // Generic network/socket errors often manifest as Exception or Error
    final errorString = e.toString().toLowerCase();
    if (errorString.contains('socketexception') ||
        errorString.contains('connection refused') ||
        errorString.contains('no internet') ||
        errorString.contains('network is unreachable')) {
      return NetworkFailure('Network connectivity issue.', stackTrace);
    }

    return UnexpectedFailure(
      e.toString(),
      originalError: e,
      stackTrace: stackTrace,
    );
  }

  /// Determine if a failure is retryable.
  bool _isRetryable(Failure failure) {
    // Network issues and server errors are retryable
    // Auth errors and not found are not retryable
    return switch (failure) {
      NetworkFailure() => true,
      TimeoutFailure() => true,
      ServerFailure() => true,
      UnauthorizedFailure() => false,
      ForbiddenFailure() => false,
      NotFoundFailure() => false,
      ParsingFailure() => false,
      ValidationFailure() => false,
      CacheFailure() => false,
      UnexpectedFailure() => false,
    };
  }

  void _onSuccess() {
    _consecutiveFailures = 0;
    if (_circuitState == CircuitState.halfOpen) {
      _circuitState = CircuitState.closed;
      AppLogger.info('Circuit breaker closed after successful request.');
    }
  }

  void _onFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= config.circuitBreakerThreshold) {
      _circuitState = CircuitState.open;
      _circuitOpenedAt = DateTime.now();
      AppLogger.warning(
        'Circuit breaker opened after $_consecutiveFailures consecutive failures.',
      );
    }
  }

  bool _shouldAttemptReset() {
    if (_circuitOpenedAt == null) return true;
    return DateTime.now().difference(_circuitOpenedAt!) >=
        config.circuitBreakerResetDuration;
  }
}
