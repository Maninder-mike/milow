import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/dashboard_config_provider.dart';

class DashboardCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final DashboardWidgetType type;
  final bool isEditMode;
  final VoidCallback onRemove;
  final Widget? extra;

  const DashboardCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.type,
    required this.onRemove,
    this.color,
    this.isEditMode = false,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final accentColor = color ?? theme.accentColor;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: theme.resources.dividerStrokeColorDefault,
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Semantic Accent Bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: Container(color: accentColor),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.bold,
                            color: theme.resources.textFillColorSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(icon, size: 16, color: accentColor),
                      ),
                    ],
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: theme.resources.textFillColorPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (extra != null) ...[const SizedBox(height: 12), extra!],
                  if (type == DashboardWidgetType.loadVolumeTrend) ...[
                    const Spacer(),
                    SizedBox(
                      height: 40,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _SparklinePainter(accentColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isEditMode)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(FluentIcons.dismiss_12_filled, size: 10),
                  onPressed: onRemove,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                      Colors.red.withValues(alpha: 0.9),
                    ),
                    foregroundColor: WidgetStateProperty.all(Colors.white),
                    shape: WidgetStateProperty.all(const CircleBorder()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class WidgetGalleryDialog extends StatelessWidget {
  final List<DashboardWidgetType> activeWidgets;
  final Function(DashboardWidgetType) onAdd;

  const WidgetGalleryDialog({
    super.key,
    required this.activeWidgets,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Add Dashboard Widget'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: DashboardWidgetType.values.map((type) {
            final isActive = activeWidgets.contains(type);
            return ListTile(
              title: Text(_getWidgetLabel(type)),
              subtitle: Text(_getWidgetDescription(type)),
              leading: Icon(_getWidgetIcon(type)),
              trailing: isActive
                  ? Icon(FluentIcons.checkmark_24_regular, color: Colors.green)
                  : const Icon(FluentIcons.add_24_regular),
              onPressed: isActive ? null : () => onAdd(type),
            );
          }).toList(),
        ),
      ),
      actions: [
        Button(
          child: const Text('Close'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  String _getWidgetLabel(DashboardWidgetType type) {
    switch (type) {
      case DashboardWidgetType.activeLoads:
        return 'Active Loads';
      case DashboardWidgetType.revenueMTD:
        return 'Revenue MTD';
      case DashboardWidgetType.fleetHealth:
        return 'Fleet Health';
      case DashboardWidgetType.awaitingDispatch:
        return 'Awaiting Dispatch';
      case DashboardWidgetType.loadVolumeTrend:
        return 'Volume Trends';
      case DashboardWidgetType.criticalAlerts:
        return 'Critical Alerts';
      case DashboardWidgetType.operationalMap:
        return 'Operational Map';
    }
  }

  String _getWidgetDescription(DashboardWidgetType type) {
    switch (type) {
      case DashboardWidgetType.activeLoads:
        return 'Currently moving freight';
      case DashboardWidgetType.revenueMTD:
        return 'Gross revenue for this month';
      case DashboardWidgetType.fleetHealth:
        return 'Percentage of operational trucks';
      case DashboardWidgetType.awaitingDispatch:
        return 'Loads ready for booking';
      case DashboardWidgetType.loadVolumeTrend:
        return '7-day throughput chart';
      case DashboardWidgetType.criticalAlerts:
        return 'Vehicles requiring immediate attention';
      case DashboardWidgetType.operationalMap:
        return 'Real-time fleet position overview';
    }
  }

  IconData _getWidgetIcon(DashboardWidgetType type) {
    switch (type) {
      case DashboardWidgetType.activeLoads:
        return FluentIcons.document_text_24_regular;
      case DashboardWidgetType.revenueMTD:
        return FluentIcons.money_24_regular;
      case DashboardWidgetType.fleetHealth:
        return FluentIcons.vehicle_truck_24_regular;
      case DashboardWidgetType.awaitingDispatch:
        return FluentIcons.clock_24_regular;
      case DashboardWidgetType.loadVolumeTrend:
        return FluentIcons.data_usage_24_regular;
      case DashboardWidgetType.criticalAlerts:
        return FluentIcons.warning_24_regular;
      case DashboardWidgetType.operationalMap:
        return FluentIcons.map_24_regular;
    }
  }
}

class _SparklinePainter extends CustomPainter {
  final Color color;

  _SparklinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final points = [
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.2, size.height * 0.6),
      Offset(size.width * 0.4, size.height * 0.9),
      Offset(size.width * 0.6, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.5),
      Offset(size.width, size.height * 0.1),
    ];

    path.moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
