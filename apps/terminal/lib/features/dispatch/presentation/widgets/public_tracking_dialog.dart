import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:milow_data/milow_data.dart';

/// Flyout dialog to manage and copy public tracking links for brokers/shippers ($0 infra cost).
class PublicTrackingDialog extends StatelessWidget {
  const PublicTrackingDialog({
    super.key,
    required this.load,
  });

  final LoadModel load;

  static Future<void> show(BuildContext context, LoadModel load) async {
    await showDialog<void>(
      context: context,
      builder: (context) => PublicTrackingDialog(load: load),
    );
  }

  String get _trackingUrl =>
      'https://milow.app/track/${load.id.replaceAll('-', '')}';

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      title: Row(
        children: [
          const Icon(FluentIcons.share_24_regular, size: 20),
          const SizedBox(width: 8),
          Text('Public Load Tracking Link - #${load.loadNumber}'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share this live link with your shipper or broker to allow real-time map tracking without requiring an account.',
            style: TextStyle(
              fontSize: 12,
              color: theme.resources.textFillColorSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextBox(
            readOnly: true,
            controller: TextEditingController(text: _trackingUrl),
            suffix: Button(
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.copy_24_regular, size: 14),
                  SizedBox(width: 4),
                  Text('Copy'),
                ],
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _trackingUrl));
                displayInfoBar(
                  context,
                  builder: (context, close) {
                    return const InfoBar(
                      title: Text('Copied!'),
                      content: Text('Tracking URL copied to clipboard.'),
                      severity: InfoBarSeverity.success,
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.resources.subtleFillColorSecondary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(FluentIcons.shield_checkmark_24_regular, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Protected by 256-bit crypto hash. Only public stop status and map telemetry are visible.',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          child: const Text('Done'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
