import 'package:fluent_ui/fluent_ui.dart';
// import 'package:go_router/go_router.dart'; // Unused
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
      header: title != null
          ? PageHeader(
              title: Text(
                title!,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              commandBar: Row(
                mainAxisSize: MainAxisSize.min,
                children: actions ?? [],
              ),
            )
          : null,
      children: [
        // Content
        child,
      ],
    );
  }
}
