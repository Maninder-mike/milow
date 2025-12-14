import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      color: const Color(0xFF007ACC), // VS Code Blue
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const Spacer(),
          // Right items
          _buildItem(FluentIcons.ringer, '', marginRight: 8), // Bell
        ],
      ),
    );
  }

  Widget _buildItem(IconData icon, String text, {double marginRight = 0}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white),
        if (text.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white),
          ),
        ],
        if (marginRight > 0) SizedBox(width: marginRight),
      ],
    );
  }
}
