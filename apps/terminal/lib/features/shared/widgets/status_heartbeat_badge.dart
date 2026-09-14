import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

/// Real-time database heartbeat and latency status badge for enterprise terminal status bar.
class StatusHeartbeatBadge extends StatefulWidget {
  const StatusHeartbeatBadge({
    super.key,
    this.latencyMs = 24,
    this.isConnected = true,
  });

  final int latencyMs;
  final bool isConnected;

  @override
  State<StatusHeartbeatBadge> createState() => _StatusHeartbeatBadgeState();
}

class _StatusHeartbeatBadgeState extends State<StatusHeartbeatBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isGood = widget.isConnected && widget.latencyMs < 100;
    final color = widget.isConnected
        ? (isGood ? Colors.green : Colors.orange)
        : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.resources.subtleFillColorSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.resources.cardStrokeColorDefault,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: _pulseAnimation.value),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          Text(
            widget.isConnected ? '${widget.latencyMs} ms' : 'Offline',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.resources.textFillColorSecondary,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            FluentIcons.arrow_sync_16_regular,
            size: 10,
          ),
        ],
      ),
    );
  }
}
