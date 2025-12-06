import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Centralized utility for displaying user feedback messages.
///
/// **SnackBar**: Ideal for displaying brief, non-intrusive messages that appear
/// temporarily at the bottom of the screen and then automatically disappear.
///
/// **AlertDialog**: Used for critical warnings or situations requiring user
/// acknowledgment or a decision before proceeding. It blocks interaction with
/// the rest of the app until dismissed.
class AppDialogs {
  AppDialogs._();

  // ============================================================================
  // SNACKBAR METHODS - Brief, non-intrusive messages
  // ============================================================================

  /// Show a success snackbar with a green background
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    _showSnackBar(
      context,
      message: message,
      icon: Icons.check_circle_outline,
      backgroundColor: const Color(0xFF10B981),
    );
  }

  /// Show an error snackbar with a red background
  static void showError(BuildContext context, String message) {
    if (!context.mounted) return;
    _showSnackBar(
      context,
      message: message,
      icon: Icons.error_outline,
      backgroundColor: const Color(0xFFEF4444),
      duration: const Duration(seconds: 4),
    );
  }

  /// Show a warning snackbar with an orange/amber background
  static void showWarning(BuildContext context, String message) {
    if (!context.mounted) return;
    _showSnackBar(
      context,
      message: message,
      icon: Icons.warning_amber_rounded,
      backgroundColor: const Color(0xFFF59E0B),
    );
  }

  /// Show an info snackbar with a blue background
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;
    _showSnackBar(
      context,
      message: message,
      icon: Icons.info_outline,
      backgroundColor: const Color(0xFF3B82F6),
    );
  }

  /// Internal method to show a styled snackbar
  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: duration,
        action: action,
      ),
    );
  }

  /// Show a snackbar with a custom action button
  static void showWithAction(
    BuildContext context, {
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    Color backgroundColor = const Color(0xFF3B82F6),
    IconData icon = Icons.info_outline,
  }) {
    if (!context.mounted) return;
    _showSnackBar(
      context,
      message: message,
      icon: icon,
      backgroundColor: backgroundColor,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: actionLabel,
        textColor: Colors.white,
        onPressed: onAction,
      ),
    );
  }

  // ============================================================================
  // ALERT DIALOG METHODS - Critical warnings requiring user acknowledgment
  // ============================================================================

  /// Show a confirmation dialog with Yes/No or custom actions
  /// Returns true if confirmed, false if cancelled, null if dismissed
  static Future<bool?> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color confirmColor = const Color(0xFF007AFF),
    bool isDestructive = false,
    IconData? icon,
  }) async {
    if (!context.mounted) return null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final secondaryTextColor = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF667085);

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: isDestructive ? const Color(0xFFEF4444) : confirmColor,
                size: 24,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: secondaryTextColor,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              cancelText,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: secondaryTextColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              backgroundColor:
                  (isDestructive ? const Color(0xFFEF4444) : confirmColor)
                      .withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              confirmText,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDestructive ? const Color(0xFFEF4444) : confirmColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show an alert dialog for critical information (single OK button)
  static Future<void> showAlert(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'OK',
    IconData? icon,
    Color? iconColor,
  }) async {
    if (!context.mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final secondaryTextColor = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF667085);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: iconColor ?? const Color(0xFF007AFF), size: 24),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: secondaryTextColor,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              buttonText,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF007AFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show a destructive confirmation dialog (for delete operations)
  static Future<bool?> showDestructiveConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Delete',
    String cancelText = 'Cancel',
  }) {
    return showConfirmation(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isDestructive: true,
      icon: Icons.delete_outline,
    );
  }

  /// Show an error alert dialog
  static Future<void> showErrorAlert(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'OK',
  }) {
    return showAlert(
      context,
      title: title,
      message: message,
      buttonText: buttonText,
      icon: Icons.error_outline,
      iconColor: const Color(0xFFEF4444),
    );
  }

  /// Show a warning alert dialog
  static Future<void> showWarningAlert(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'OK',
  }) {
    return showAlert(
      context,
      title: title,
      message: message,
      buttonText: buttonText,
      icon: Icons.warning_amber_rounded,
      iconColor: const Color(0xFFF59E0B),
    );
  }

  /// Show a loading dialog (blocks UI while processing)
  static void showLoading(BuildContext context, {String? message}) {
    if (!context.mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF007AFF),
                strokeWidth: 3.0,
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message,
                  style: GoogleFonts.inter(fontSize: 14, color: textColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Hide the loading dialog
  static void hideLoading(BuildContext context) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  /// Show a custom bottom sheet dialog
  static Future<T?> showBottomSheet<T>(
    BuildContext context, {
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    if (!context.mounted) return Future.value(null);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: backgroundColor,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => child,
    );
  }

  /// Show a picker bottom sheet with options
  static Future<T?> showOptionsPicker<T>(
    BuildContext context, {
    required String title,
    required List<T> options,
    required String Function(T) labelBuilder,
    T? selectedValue,
    IconData Function(T)? iconBuilder,
  }) async {
    if (!context.mounted) return null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final secondaryTextColor = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF667085);
    final borderColor = isDark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFD0D5DD);

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            Divider(height: 1, color: borderColor),
            // Options
            ...options.map((option) {
              final isSelected = option == selectedValue;
              return ListTile(
                leading: iconBuilder != null
                    ? Icon(
                        iconBuilder(option),
                        color: isSelected
                            ? const Color(0xFF007AFF)
                            : secondaryTextColor,
                      )
                    : null,
                title: Text(
                  labelBuilder(option),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? const Color(0xFF007AFF) : textColor,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Color(0xFF007AFF))
                    : null,
                onTap: () => Navigator.of(context).pop(option),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Show update available dialog with download option
  /// If isCritical is true, user cannot dismiss the dialog
  static Future<bool?> showUpdateAvailable(
    BuildContext context, {
    required String currentVersion,
    required String latestVersion,
    required String downloadUrl,
    String? changelog,
    bool isCritical = false,
  }) async {
    if (!context.mounted) return null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final secondaryTextColor = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF667085);

    return showDialog<bool>(
      context: context,
      barrierDismissible: !isCritical,
      builder: (context) => PopScope(
        canPop: !isCritical,
        child: AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                isCritical ? Icons.system_update : Icons.system_update_outlined,
                color: isCritical
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF007AFF),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isCritical ? 'Update Required' : 'Update Available',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCritical
                    ? 'A critical update is required to continue using the app.'
                    : 'A new version of the app is available.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: secondaryTextColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.05,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                        Text(
                          currentVersion,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.arrow_forward,
                      color: secondaryTextColor,
                      size: 20,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Latest',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                        Text(
                          latestVersion,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (changelog != null && changelog.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'What\'s New:',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  changelog,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: secondaryTextColor,
                    height: 1.4,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          actions: [
            if (!isCritical)
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Later',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                  ),
                ),
              ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(true);
                // Open download URL in browser
                final uri = Uri.parse(downloadUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              style: TextButton.styleFrom(
                backgroundColor:
                    (isCritical
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF007AFF))
                        .withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Download',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isCritical
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF007AFF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
