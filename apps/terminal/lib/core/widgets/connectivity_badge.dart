import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/connectivity_provider.dart';

class ConnectivityBadge extends ConsumerWidget {
  const ConnectivityBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityAsync = ref.watch(connectivityProvider);
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return connectivityAsync.when(
      data: (results) {
        // Determine status
        // Prioritize: Ethernet > WiFi > Mobile > None
        String label = 'Offline';
        IconData icon = FluentIcons.cloud_download; // Default offline
        Color statusColor = Colors.grey;

        if (results.contains(ConnectivityResult.ethernet)) {
          label = 'Online: Ethernet';
          icon = FluentIcons.plug_connected;
          statusColor = Colors.green;
        } else if (results.contains(ConnectivityResult.wifi)) {
          label = 'Online: Stable (WiFi)';
          icon = FluentIcons.wifi;
          statusColor = Colors.green;
        } else if (results.contains(ConnectivityResult.mobile)) {
          label = 'Online: Stable (5G)'; // Generic 5G as requested
          icon = FluentIcons.cell_phone;
          statusColor = Colors.green;
        } else if (results.contains(ConnectivityResult.none)) {
          label = 'Offline';
          icon = FluentIcons.error_badge;
          statusColor = Colors.red;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.resources.cardBackgroundFillColorDefault,
            borderRadius: BorderRadius.circular(100), // Pill shape
            border: Border.all(
              color: theme.resources.dividerStrokeColorDefault,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.05 : 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: statusColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.resources.textFillColorPrimary,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}
