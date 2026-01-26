import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';

class ShortcutsReferenceDialog extends StatelessWidget {
  const ShortcutsReferenceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Text(
        'Keyboard Shortcuts',
        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSection(context, 'General', [
              _ShortcutItem('Find / Command Palette', 'Cmd + P'),
              _ShortcutItem('All Commands', 'Cmd + Shift + P'),
              _ShortcutItem('Toggle Full Screen', 'F11'),
              _ShortcutItem('Quit Application', 'Cmd + Q'),
            ]),
            const SizedBox(height: 16),
            _buildSection(context, 'Navigation & Tabs', [
              _ShortcutItem('Close Active Tab', 'Cmd + W'),
              _ShortcutItem('Switch to Tab 1-9', 'Cmd + 1-9'),
              _ShortcutItem('Switch to Dashboard', 'Cmd + 1'),
            ]),
            const SizedBox(height: 16),
            _buildSection(context, 'Editing', [
              _ShortcutItem('Undo', 'Cmd + Z'),
              _ShortcutItem('Redo', 'Cmd + Shift + Z'),
              _ShortcutItem('Cut', 'Cmd + X'),
              _ShortcutItem('Copy', 'Cmd + C'),
              _ShortcutItem('Paste', 'Cmd + V'),
              _ShortcutItem('Select All', 'Cmd + A'),
            ]),
          ],
        ),
      ),
      actions: [
        FilledButton(
          child: const Text('Close'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<_ShortcutItem> items,
  ) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.accentColor,
            ),
          ),
        ),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.label, style: const TextStyle(fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.resources.subtleFillColorSecondary,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: theme.resources.dividerStrokeColorDefault,
                    ),
                  ),
                  child: Text(
                    item.keys,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShortcutItem {
  final String label;
  final String keys;

  _ShortcutItem(this.label, this.keys);
}
