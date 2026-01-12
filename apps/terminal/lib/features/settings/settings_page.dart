import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'panels/compliance_panel.dart';
import 'panels/general_panel.dart';
import 'panels/integration_panel.dart';
import 'panels/notification_panel.dart';
import 'panels/security_panel.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      appBar: NavigationAppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      pane: NavigationPane(
        selected: _currentIndex,
        onChanged: (index) => setState(() => _currentIndex = index),
        displayMode: PaneDisplayMode.open,
        items: [
          PaneItem(
            icon: const Icon(FluentIcons.settings_24_regular),
            title: const Text('General'),
            body: const GeneralPanel(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.shield_24_regular),
            title: const Text('Compliance'),
            body: const CompliancePanel(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.alert_24_regular),
            title: const Text('Notifications'),
            body: const NotificationPanel(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.lock_shield_24_regular),
            title: const Text('Security'),
            body: const SecurityPanel(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.plug_connected_24_regular),
            title: const Text('Integrations'),
            body: const IntegrationPanel(),
          ),
        ],
      ),
    );
  }
}
