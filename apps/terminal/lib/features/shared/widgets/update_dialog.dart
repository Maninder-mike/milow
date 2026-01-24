import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'dart:io';

class UpdateDialog extends StatelessWidget {
  final bool isForceUpdate;

  const UpdateDialog({super.key, required this.isForceUpdate});

  Future<void> _launchUpdateUrl() async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    String? url;

    if (Platform.isWindows) {
      // Try to get specific store URL from config, otherwise fallback to generic protocol
      url = remoteConfig.getString('windows_store_url');
      if (url.isEmpty) {
        // Fallback to MS Store protocol with specific ProductId if known, or search
        // For now, let's assume we want to open the product page.
        // Replace '9NBLGGH4NNS1' with your actual Product ID when available.
        url = 'ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1';
      }
    } else if (Platform.isMacOS) {
      url = remoteConfig.getString('macos_download_url');
    }

    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('New Version Available'),
      content: Text(
        isForceUpdate
            ? 'A critical update is required to continue using Milow Terminal. Please update to the latest version.'
            : 'A new version of Milow Terminal is available. Would you like to update now?',
      ),
      actions: [
        if (!isForceUpdate)
          Button(
            child: const Text('Later'),
            onPressed: () => Navigator.pop(context),
          ),
        FilledButton(
          onPressed: _launchUpdateUrl,
          child: const Text('Download Update'),
        ),
      ],
    );
  }
}
