import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';

class TripEntryScaffold extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;

  const TripEntryScaffold({
    super.key,
    required this.child,
    this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      padding: EdgeInsets.zero,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title!,
                  style: GoogleFonts.outfit(
                    fontSize: 24, // Match typical PageHeader title size
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (actions != null)
                  Row(mainAxisSize: MainAxisSize.min, children: actions!),
              ],
            ),
          ),
        // Content
        child,
      ],
    );
  }
}
