import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow_core/milow_core.dart';

import '../../../drivers/presentation/providers/driver_selection_provider.dart';
import '../providers/company_drivers_provider.dart';

class DriverSelectorCombo extends ConsumerWidget {
  const DriverSelectorCombo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driversAsync = ref.watch(companyDriversProvider);
    final selectedDriver = ref.watch(selectedDriverProvider);

    return SizedBox(
      width: 320,
      child: driversAsync.when(
        data: (drivers) {
          // Verify selectedDriver exists in the list to avoid ComboBox assert errors
          final value =
              (selectedDriver != null &&
                  drivers.any((d) => d.id == selectedDriver.id))
              ? selectedDriver
              : null;

          return ComboBox<UserProfile>(
            placeholder: const Text('Select a driver...'),
            value: value,
            isExpanded: true,
            items: drivers.map((driver) {
              return ComboBoxItem<UserProfile>(
                value: driver,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAvatarPlaceholder(context, driver, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      driver.fullName ?? 'Unknown Driver',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (UserProfile? newDriver) {
              if (newDriver != null) {
                ref.read(selectedDriverProvider.notifier).select(newDriver);
              }
            },
          );
        },
        loading: () => const ComboBox<UserProfile>(
          placeholder: Text('Loading drivers...'),
          items: [],
          onChanged: null,
        ),
        error: (err, _) => ComboBox<UserProfile>(
          placeholder: Text('Error: $err'),
          items: const [],
          onChanged: null,
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(
    BuildContext context,
    UserProfile driver, {
    double size = 24,
  }) {
    final theme = FluentTheme.of(context);
    String initials = '?';
    if (driver.fullName?.isNotEmpty ?? false) {
      final parts = driver.fullName!.trim().split(' ');
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty) {
        initials = parts[0][0].toUpperCase();
      }
    }

    Widget fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.accentColor.defaultBrushFor(theme.brightness),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    if (driver.avatarUrl?.isNotEmpty == true) {
      return ClipOval(
        child: Image.network(
          driver.avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      );
    }

    return fallback;
  }
}
