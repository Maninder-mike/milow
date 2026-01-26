import 'package:fpdart/fpdart.dart';

/// Type alias for a Result. A Result is either a [Failure] (Left) or successful
/// data [T] (Right).
/// Usage:
/// ```dart
/// final Result<User> result = await authRepository.signIn(email, password);
/// result.fold(
///   (failure) => handleFailure(failure),
///   (user) => handleSuccess(user),
/// );
/// ```
typedef Result<T> = Either<Failure, T>;

/// Base class for all failures in the application.
/// Extend this sealed class to create specific failure types.
sealed class Failure {
  final String message;
  final StackTrace? stackTrace;

  const Failure(this.message, [this.stackTrace]);

  @override
  String toString() => message;
}

// --- Network Failures ---

/// Represents a failure due to no internet connectivity.
final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'No internet connection.',
    super.stackTrace,
  ]);
}

/// Represents a failure due to a request timeout.
final class TimeoutFailure extends Failure {
  const TimeoutFailure([
    super.message = 'The request timed out.',
    super.stackTrace,
  ]);
}

// --- Server Failures ---

/// Represents a failure from the server (e.g., 5xx status codes).
final class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(String message, {this.statusCode, StackTrace? stackTrace})
    : super(message, stackTrace);
}

/// Represents a failure due to an unauthorized request (401).
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([
    super.message = 'Unauthorized. Please log in again.',
    super.stackTrace,
  ]);
}

/// Represents a failure due to a forbidden request (403).
final class ForbiddenFailure extends Failure {
  const ForbiddenFailure([super.message = 'Access denied.', super.stackTrace]);
}

/// Represents a failure when a resource is not found (404).
final class NotFoundFailure extends Failure {
  const NotFoundFailure([
    super.message = 'Resource not found.',
    super.stackTrace,
  ]);
}

// --- Data Failures ---

/// Represents a failure during parsing or data transformation.
final class ParsingFailure extends Failure {
  const ParsingFailure(super.message, [super.stackTrace]);
}

/// Represents a failure due to invalid input or validation.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, [super.stackTrace]);
}

// --- Cache Failures ---

/// Represents a failure when reading from or writing to local cache.
final class CacheFailure extends Failure {
  const CacheFailure([
    super.message = 'Failed to access local storage.',
    super.stackTrace,
  ]);
}

// --- Unexpected Failures ---

/// Represents an unexpected or unknown failure.
final class UnexpectedFailure extends Failure {
  final Object? originalError;
  const UnexpectedFailure(
    String message, {
    this.originalError,
    StackTrace? stackTrace,
  }) : super(message, stackTrace);
}
