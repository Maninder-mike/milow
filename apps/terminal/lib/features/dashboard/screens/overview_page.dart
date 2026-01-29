import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/entrance_fader.dart';
import '../presentation/providers/dashboard_config_provider.dart';
import '../presentation/providers/dashboard_metrics_provider.dart';
import '../presentation/widgets/dashboard_widgets.dart';

class OverviewPage extends ConsumerStatefulWidget {
  const OverviewPage({super.key});

  @override
  ConsumerState<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends ConsumerState<OverviewPage> {
  bool _isEditMode = false;
  final _currencyFormat = NumberFormat.currency(symbol: '\$');

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(dashboardConfigProvider);
    final metricsAsync = ref.watch(dashboardMetricsProvider);

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: Text(
          'Dashboard Overview',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: Icon(
                _isEditMode
                    ? FluentIcons.checkmark_24_regular
                    : FluentIcons.edit_24_regular,
              ),
              label: Text(_isEditMode ? 'Done' : 'Edit Layout'),
              onPressed: () => setState(() => _isEditMode = !_isEditMode),
            ),
            if (_isEditMode)
              CommandBarButton(
                icon: const Icon(FluentIcons.add_24_regular),
                label: const Text('Add Widget'),
                onPressed: _showWidgetGallery,
              ),
          ],
        ),
      ),
      children: [
        metricsAsync.when(
          data: (metrics) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EntranceFader(
                delay: const Duration(milliseconds: 100),
                child: _buildQuickActions(context),
              ),
              const SizedBox(height: 24),
              _buildReorderableGrid(metrics, config),
              const SizedBox(height: 32),
              EntranceFader(
                delay: const Duration(milliseconds: 400),
                child: _buildSectionHeader(context, 'Critical Exceptions'),
              ),
              const SizedBox(height: 16),
              EntranceFader(
                delay: const Duration(milliseconds: 500),
                child: _buildAlertList(metrics),
              ),
            ],
          ),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(64.0),
              child: ProgressRing(),
            ),
          ),
          error: (e, s) => Center(child: Text('Error loading metrics: \$e')),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildQuickAction(
            context,
            'New Load',
            FluentIcons.add_24_regular,
            onPressed: () {},
          ),
          _buildQuickAction(
            context,
            'Assign Driver',
            FluentIcons.person_add_24_regular,
            onPressed: () {},
          ),
          _buildQuickAction(
            context,
            'Dispatch Truck',
            FluentIcons.vehicle_truck_profile_24_regular,
            onPressed: () {},
          ),
          _buildQuickAction(
            context,
            'Billing Report',
            FluentIcons.document_bullet_list_24_regular,
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    String label,
    IconData icon, {
    required VoidCallback onPressed,
  }) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: HoverButton(
        onPressed: onPressed,
        builder: (context, states) {
          final isHovered = states.isHovered;
          return Container(
            width: 140,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: isHovered
                  ? theme.accentColor.withValues(alpha: 0.1)
                  : theme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHovered
                    ? theme.accentColor.withValues(alpha: 0.3)
                    : theme.resources.dividerStrokeColorDefault,
              ),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: theme.accentColor.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isHovered
                      ? theme.accentColor
                      : theme.resources.textFillColorPrimary,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: isHovered ? FontWeight.bold : FontWeight.w500,
                    color: isHovered
                        ? theme.accentColor
                        : theme.resources.textFillColorPrimary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReorderableGrid(
    DashboardMetrics metrics,
    List<DashboardWidgetType> config,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1600
            ? 5
            : (constraints.maxWidth > 1200
                  ? 4
                  : (constraints.maxWidth > 800 ? 3 : 2));

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.8,
          ),
          itemCount: config.length,
          itemBuilder: (context, index) {
            final type = config[index];
            return EntranceFader(
              delay: Duration(milliseconds: 200 + (index * 50)),
              child: _buildDraggableWidget(type, metrics, index),
            );
          },
        );
      },
    );
  }

  Widget _buildDraggableWidget(
    DashboardWidgetType type,
    DashboardMetrics metrics,
    int index,
  ) {
    final widget = _createWidget(type, metrics);

    if (!_isEditMode) return widget;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) {
        ref.read(dashboardConfigProvider.notifier).reorder(details.data, index);
      },
      builder: (context, candidates, rejects) {
        return LongPressDraggable<int>(
          data: index,
          feedback: SizedBox(
            width: 200,
            height: 120,
            child: Opacity(opacity: 0.8, child: widget),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: widget),
          child: widget,
        );
      },
    );
  }

  Widget _createWidget(DashboardWidgetType type, DashboardMetrics metrics) {
    final theme = FluentTheme.of(context);

    switch (type) {
      case DashboardWidgetType.activeLoads:
        return DashboardCard(
          label: 'ACTIVE LOADS',
          value: '${metrics.activeLoads}',
          icon: FluentIcons.document_text_24_regular,
          type: type,
          isEditMode: _isEditMode,
          onRemove: () =>
              ref.read(dashboardConfigProvider.notifier).removeWidget(type),
        );
      case DashboardWidgetType.revenueMTD:
        return DashboardCard(
          label: 'REVENUE MTD',
          value: _currencyFormat.format(metrics.revenueMTD),
          icon: FluentIcons.money_24_regular,
          color: Colors.green,
          type: type,
          isEditMode: _isEditMode,
          onRemove: () =>
              ref.read(dashboardConfigProvider.notifier).removeWidget(type),
        );
      case DashboardWidgetType.fleetHealth:
        return DashboardCard(
          label: 'FLEET HEALTH',
          value: '${metrics.fleetHealthPercent.toStringAsFixed(1)}%',
          icon: FluentIcons.vehicle_truck_24_regular,
          type: type,
          isEditMode: _isEditMode,
          onRemove: () =>
              ref.read(dashboardConfigProvider.notifier).removeWidget(type),
          extra: ProgressBar(value: metrics.fleetHealthPercent, strokeWidth: 4),
        );
      case DashboardWidgetType.awaitingDispatch:
        return DashboardCard(
          label: 'AWAITING DISPATCH',
          value: '${metrics.awaitingDispatch}',
          icon: FluentIcons.clock_24_regular,
          color: theme.accentColor,
          type: type,
          isEditMode: _isEditMode,
          onRemove: () =>
              ref.read(dashboardConfigProvider.notifier).removeWidget(type),
        );
      case DashboardWidgetType.criticalAlerts:
        return DashboardCard(
          label: 'CRITICAL ALERTS',
          value: '${metrics.criticalAlertsCount}',
          icon: FluentIcons.warning_24_regular,
          color: Colors.red,
          type: type,
          isEditMode: _isEditMode,
          onRemove: () =>
              ref.read(dashboardConfigProvider.notifier).removeWidget(type),
        );
      case DashboardWidgetType.operationalMap:
        return _buildMapPlaceholder(context, type);
      case DashboardWidgetType.loadVolumeTrend:
        return DashboardCard(
          label: 'VOLUME TRENDS (7D)',
          value: 'Up 12%',
          icon: FluentIcons.data_usage_24_regular,
          type: type,
          isEditMode: _isEditMode,
          onRemove: () =>
              ref.read(dashboardConfigProvider.notifier).removeWidget(type),
        );
    }
  }

  Widget _buildMapPlaceholder(BuildContext context, DashboardWidgetType type) {
    final theme = FluentTheme.of(context);
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
            // Decorative Tech Grid
            CustomPaint(
              size: Size.infinite,
              painter: _GridPainter(theme.accentColor.withValues(alpha: 0.05)),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      FluentIcons.map_24_regular,
                      size: 28,
                      color: theme.accentColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Fleet Map View',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Integrated operational awareness',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (_isEditMode)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(FluentIcons.dismiss_12_filled, size: 10),
                  onPressed: () => ref
                      .read(dashboardConfigProvider.notifier)
                      .removeWidget(type),
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

  void _showWidgetGallery() {
    showDialog(
      context: context,
      builder: (context) => WidgetGalleryDialog(
        activeWidgets: ref.read(dashboardConfigProvider),
        onAdd: (type) {
          ref.read(dashboardConfigProvider.notifier).addWidget(type);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildAlertList(DashboardMetrics metrics) {
    final theme = FluentTheme.of(context);
    if (metrics.criticalAlertsCount == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48),
        decoration: BoxDecoration(
          color: theme.resources.subtleFillColorSecondary.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.resources.dividerStrokeColorDefault,
            style: BorderStyle.none,
          ),
        ),
        child: Column(
          children: [
            Icon(
              FluentIcons.checkmark_circle_24_regular,
              size: 32,
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            Text(
              'No critical exceptions detected.',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.resources.textFillColorPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your operation is running smoothly as planned.',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(metrics.criticalAlertsCount, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: theme.resources.dividerStrokeColorDefault,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle MIL Alert: Inspection Required',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Automated exception based on telemetry data',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: theme.resources.textFillColorSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;

  _GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    const spacing = 20.0;
    for (var x = 0.0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
