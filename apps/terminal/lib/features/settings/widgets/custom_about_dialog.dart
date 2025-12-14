import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomAboutDialog extends StatelessWidget {
  const CustomAboutDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: ProgressBar());
        }

        final info = snapshot.data!;
        final theme = FluentTheme.of(context);

        return ContentDialog(
          constraints: const BoxConstraints(maxWidth: 400),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo Area
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.accentColor,
                      theme.accentColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  FluentIcons.robot,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // App Name
              Text(
                'Milow Terminal',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.typography.title?.color,
                ),
              ),
              const SizedBox(height: 8),

              // Version Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.accentColor.withOpacity(0.2)),
                ),
                child: Text(
                  'v${info.version} (Build ${info.buildNumber})',
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    color: theme.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Description
              Text(
                'Advanced terminal management system for modern logistics operations.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.typography.body?.color?.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 24),

              // Copyright
              Text(
                '© ${DateTime.now().year} Maninder-mike.\nAll rights reserved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.typography.caption?.color?.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),

              // Links
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HyperlinkButton(
                    child: const Text('Privacy Policy'),
                    onPressed: () {
                      launchUrl(
                        Uri.parse(
                          'https://www.maninder.co.in/milow/privacypolicy',
                        ),
                      );
                    },
                  ),
                  const Text('•'),
                  HyperlinkButton(
                    child: const Text('Terms'),
                    onPressed: () {
                      launchUrl(
                        Uri.parse('https://maninder.co.in/milow/terms'),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

void showCustomAboutDialog(BuildContext context) {
  showDialog(context: context, builder: (context) => const CustomAboutDialog());
}
