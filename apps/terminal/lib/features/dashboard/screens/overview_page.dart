import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/choreographed_entrance.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: Text(
          'Dashboard',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      content: ChoreographedEntrance(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FluentIcons.vehicle_truck_profile_24_regular,
                size: 64,
                color: FluentTheme.of(context).resources.textFillColorSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome to Milow Terminal',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a module from the sidebar to get started.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: FluentTheme.of(
                    context,
                  ).resources.textFillColorSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
