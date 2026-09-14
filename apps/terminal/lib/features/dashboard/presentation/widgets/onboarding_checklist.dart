import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingChecklistCard extends StatefulWidget {
  const OnboardingChecklistCard({
    super.key,
    this.onAddDriver,
    this.onCreateLoad,
    this.onCompanySettings,
  });

  final VoidCallback? onAddDriver;
  final VoidCallback? onCreateLoad;
  final VoidCallback? onCompanySettings;

  @override
  State<OnboardingChecklistCard> createState() =>
      _OnboardingChecklistCardState();
}

class _OnboardingChecklistCardState extends State<OnboardingChecklistCard> {
  bool _dismissed = false;
  final bool _step1Done = true; // Auth complete
  bool _step2Done = false; // Driver invited
  bool _step3Done = false; // First load
  bool _step4Done = false; // Billing setup

  int get _completedSteps =>
      (_step1Done ? 1 : 0) +
      (_step2Done ? 1 : 0) +
      (_step3Done ? 1 : 0) +
      (_step4Done ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final theme = FluentTheme.of(context);
    final progress = _completedSteps / 4;

    return Card(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  FluentIcons.rocket_24_regular,
                  color: theme.accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to Milow Terminal',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Complete these steps to get your fleet fully operational ($_completedSteps/4 complete)',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: theme.resources.textFillColorSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(FluentIcons.dismiss_20_regular),
                onPressed: () => setState(() => _dismissed = true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ProgressBar(
            value: progress * 100,
            activeColor: theme.accentColor,
          ),
          const SizedBox(height: 16),
          _buildCheckItem(
            context: context,
            title: 'Create Account & Organization',
            subtitle: 'Account verified and ready for team access',
            isCompleted: _step1Done,
            onTap: null,
          ),
          const Divider(),
          _buildCheckItem(
            context: context,
            title: 'Invite Your First Driver',
            subtitle: 'Send invite link for the Milow Driver mobile app',
            isCompleted: _step2Done,
            onTap: () {
              widget.onAddDriver?.call();
              setState(() => _step2Done = !_step2Done);
            },
          ),
          const Divider(),
          _buildCheckItem(
            context: context,
            title: 'Dispatch Your First Load',
            subtitle: 'Create a multi-stop route with RateCon PDF export',
            isCompleted: _step3Done,
            onTap: () {
              widget.onCreateLoad?.call();
              setState(() => _step3Done = !_step3Done);
            },
          ),
          const Divider(),
          _buildCheckItem(
            context: context,
            title: 'Configure Fleet & Billing Profile',
            subtitle: 'Set up settlement rules and company logo for RateCons',
            isCompleted: _step4Done,
            onTap: () {
              widget.onCompanySettings?.call();
              setState(() => _step4Done = !_step4Done);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required VoidCallback? onTap,
  }) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Checkbox(
            checked: isCompleted,
            onChanged: onTap != null ? (value) => onTap() : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted
                        ? theme.resources.textFillColorTertiary
                        : theme.resources.textFillColorPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!isCompleted && onTap != null)
            Button(
              onPressed: onTap,
              child: Text(
                'Start',
                style: GoogleFonts.outfit(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
