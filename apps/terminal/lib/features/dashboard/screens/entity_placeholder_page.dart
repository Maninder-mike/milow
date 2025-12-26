import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';

class EntityPlaceholderPage extends StatelessWidget {
  final String title;

  const EntityPlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: Text(
          title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      content: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FluentIcons.document_text_48_regular,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              '$title Page',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Content coming soon...'),
          ],
        ),
      ),
    );
  }
}
