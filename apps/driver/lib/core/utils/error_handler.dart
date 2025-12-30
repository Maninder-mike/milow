import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow/core/services/logging_service.dart';
import 'package:milow/core/constants/design_tokens.dart';

/// Utility class for handling errors and displaying user-friendly messages
class ErrorHandler {
  /// Get a user-friendly error message from any error type
  static String getErrorMessage(dynamic error) {
    // Handle Supabase AuthException
    if (error is AuthException) {
      return _getAuthErrorMessage(error);
    }

    // Handle PostgrestException (Supabase database errors)
    if (error is PostgrestException) {
      return _getDatabaseErrorMessage(error);
    }

    // Handle SocketException (network errors)
    if (error is SocketException) {
      return 'No internet connection. Please check your network.';
    }

    // Handle TimeoutException
    if (error.toString().toLowerCase().contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    final errorStr = error.toString().toLowerCase();

    // ClientException (often from http package used by Supabase)
    if (errorStr.contains('clientexception')) {
      return 'Network error. Please check your connection.';
    }

    // Network-related errors
    if (errorStr.contains('socketexception') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('network is unreachable') ||
        errorStr.contains('no internet') ||
        errorStr.contains('xmlhttprequest error') || // Web specific
        errorStr.contains('connection closed')) {
      return 'No internet connection. Please check your network.';
    }

    // Permission errors
    if (errorStr.contains('permission') || errorStr.contains('denied')) {
      return 'Permission denied. Please grant the required permissions.';
    }

    // Server errors
    if (errorStr.contains('500') ||
        errorStr.contains('502') ||
        errorStr.contains('503') ||
        errorStr.contains('internal server')) {
      return 'Server is temporarily unavailable. Please try again later.';
    }

    // Not found errors
    if (errorStr.contains('404') || errorStr.contains('not found')) {
      return 'The requested data was not found.';
    }

    // Authentication errors
    if (errorStr.contains('unauthorized') || errorStr.contains('401')) {
      return 'Your session has expired. Please sign in again.';
    }

    // Rate limiting
    if (errorStr.contains('429') || errorStr.contains('too many requests')) {
      return 'Too many requests. Please wait a moment and try again.';
    }

    // File/Storage errors
    if (errorStr.contains('file') && errorStr.contains('large')) {
      return 'File is too large. Please choose a smaller file.';
    }

    if (errorStr.contains('storage') || errorStr.contains('upload')) {
      return 'Failed to upload file. Please try again.';
    }

    // Location errors
    if (errorStr.contains('location')) {
      return 'Unable to get your location. Please check location settings.';
    }

    // Handle generic Exception objects by extracting their message
    if (error is Exception) {
      final msg = error.toString();
      // "Exception: actual message" -> "actual message"
      if (msg.startsWith('Exception: ')) {
        return msg.substring(11);
      }
    }

    // Generic fallback - if we can't identify it, it's better to show something descriptive
    // than just "Something went wrong" if the error string is reasonably short.
    if (error.toString().length < 100) {
      return error.toString();
    }

    return 'Something went wrong. Please try again.';
  }

  /// Get user-friendly message for Supabase auth errors
  static String _getAuthErrorMessage(AuthException error) {
    final message = error.message.toLowerCase();

    if (message.contains('invalid login credentials') ||
        message.contains('invalid email or password')) {
      return 'Invalid email or password. Please try again.';
    }

    if (message.contains('email not confirmed')) {
      return 'Please verify your email before signing in.';
    }

    if (message.contains('user already registered') ||
        message.contains('already exists')) {
      return 'An account with this email already exists.';
    }

    if (message.contains('password')) {
      if (message.contains('weak') || message.contains('short')) {
        return 'Password is too weak. Use at least 8 characters with numbers and symbols.';
      }
      return 'Invalid password. Please check and try again.';
    }

    if (message.contains('email')) {
      return 'Invalid email address. Please check and try again.';
    }

    if (message.contains('rate limit') || message.contains('too many')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }

    if (message.contains('network') || message.contains('connection')) {
      return 'No internet connection. Please check your network.';
    }

    // Return the original message if it's user-friendly enough
    if (error.message.length < 100 && !message.contains('exception')) {
      return error.message;
    }

    return 'Authentication failed. Please try again.';
  }

  /// Get user-friendly message for Supabase database errors
  static String _getDatabaseErrorMessage(PostgrestException error) {
    final message = error.message.toLowerCase();

    if (message.contains('duplicate') || message.contains('unique')) {
      return 'This record already exists.';
    }

    if (message.contains('foreign key') || message.contains('reference')) {
      return 'Cannot complete this action due to related data.';
    }

    if (message.contains('permission') || message.contains('policy')) {
      return 'You don\'t have permission to perform this action.';
    }

    if (message.contains('not found') || message.contains('no rows')) {
      return 'The requested data was not found.';
    }

    return 'Database error. Please try again.';
  }

  /// Show a SnackBar with an error message
  static void showError(BuildContext context, dynamic error, {String? tag}) {
    if (!context.mounted) return;

    final message = getErrorMessage(error);

    // Log the error
    logger.error(
      tag ?? 'ErrorHandler',
      message,
      error: error,
      stackTrace: error is Error ? error.stackTrace : null,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show a SnackBar with a success message
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: context.tokens.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show a SnackBar with an info/warning message
  static void showWarning(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: context.tokens.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
