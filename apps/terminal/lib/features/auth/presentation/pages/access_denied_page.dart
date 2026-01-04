import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:terminal/core/providers/supabase_provider.dart';
import '../theme/auth_theme.dart';

class AccessDeniedPage extends ConsumerWidget {
  const AccessDeniedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AuthTheme.getRandom();

    // Helper for button text color
    Color buttonTextCol(Color bg) {
      return bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    }

    return Container(
      decoration: BoxDecoration(gradient: theme.gradient),
      child: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: theme.glassColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.glassBorderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FluentIcons.prohibited_24_regular,
                size: 64,
                color: theme.primaryContentColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Access Denied',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryContentColor,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Drivers must use the mobile app. Access to the Terminal is restricted.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: theme.secondaryContentColor,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () async {
                    await ref.read(supabaseClientProvider).auth.signOut();
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                      theme.primaryContentColor,
                    ),
                    foregroundColor: WidgetStateProperty.all(
                      buttonTextCol(theme.primaryContentColor),
                    ),
                  ),
                  child: Text(
                    'Back to Login',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
