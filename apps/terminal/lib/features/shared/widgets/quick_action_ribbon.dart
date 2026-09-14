import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';

/// Floating quick action ribbon bar for enterprise workflows.
class QuickActionRibbon extends StatelessWidget {
  const QuickActionRibbon({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Card(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: BorderRadius.circular(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Button(
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.add_24_regular, size: 16),
                SizedBox(width: 6),
                Text('New Dispatch'),
              ],
            ),
            onPressed: () => context.go('/dispatch'),
          ),
          const SizedBox(width: 8),
          Button(
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.receipt_add_24_regular, size: 16),
                SizedBox(width: 6),
                Text('Create Invoice'),
              ],
            ),
            onPressed: () => context.go('/invoices'),
          ),
          const SizedBox(width: 8),
          Button(
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.arrow_download_24_regular, size: 16),
                SizedBox(width: 6),
                Text('Export Reports'),
              ],
            ),
            onPressed: () => context.go('/analytics'),
          ),
          const SizedBox(width: 12),
          Container(
            height: 16,
            width: 1,
            color: theme.resources.dividerStrokeColorDefault,
          ),
          const SizedBox(width: 12),
          Text(
            'Tip: Press ⌘K for Command Palette',
            style: TextStyle(
              fontSize: 11,
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
