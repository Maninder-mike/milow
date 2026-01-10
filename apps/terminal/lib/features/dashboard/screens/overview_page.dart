import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../../core/widgets/choreographed_entrance.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      content: ChoreographedEntrance(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FluentIcons.data_usage_24_regular,
                size: 64,
                color: FluentTheme.of(context).accentColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Dashboard Overview',
                style: FluentTheme.of(context).typography.title,
              ),
              const SizedBox(height: 8),
              const Text('Coming Soon'),
            ],
          ),
        ),
      ),
    );
  }
}
