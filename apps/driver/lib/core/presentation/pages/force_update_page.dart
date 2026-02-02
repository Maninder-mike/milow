import 'dart:io';

import 'package:flutter/material.dart';
import 'package:milow_core/milow_core.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdatePage extends StatelessWidget {
  const ForceUpdatePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine store URL based on platform
    final storeUrl = Platform.isAndroid
        ? 'market://details?id=com.maninder.milow.driver' // Replace with actual package name
        : 'https://apps.apple.com/app/idYOUR_APP_ID'; // Replace with actual App ID

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.system_update, size: 80, color: Colors.blue),
              const SizedBox(height: 32),
              Text(
                'Update Required',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'A new version of Milow is available. Please update to continue using the app.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: () async {
                  final uri = Uri.parse(storeUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    // Fallback to web URL if market:// fails (Android)
                    if (Platform.isAndroid) {
                      final webUri = Uri.parse(
                        'https://play.google.com/store/apps/details?id=com.maninder.milow.driver',
                      );
                      await launchUrl(
                        webUri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      AppLogger.error('Could not launch store url: $storeUrl');
                    }
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  child: Text('Update Now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
