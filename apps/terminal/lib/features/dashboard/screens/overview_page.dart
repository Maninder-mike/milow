import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;

import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/choreographed_entrance.dart';
import '../presentation/widgets/dashboard_map_widget.dart';

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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: const DashboardMapWidget(),
        ),
      ),
    );
  }
}
