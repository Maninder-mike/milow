import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/geofence_service.dart';
import 'package:milow/features/settings/presentation/pages/border_crossing_selector.dart';

class DriverToolsPage extends StatefulWidget {
  const DriverToolsPage({super.key});

  @override
  State<DriverToolsPage> createState() => _DriverToolsPageState();
}

class _DriverToolsPageState extends State<DriverToolsPage> {
  bool _geofenceEnabled = false;
  int _geofenceRadius = 500;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await GeofenceService.instance.isEnabled;
    final radius = await GeofenceService.instance.radiusMeters;
    if (mounted) {
      setState(() {
        _geofenceEnabled = enabled;
        _geofenceRadius = radius;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Driver Tools',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(vertical: context.tokens.spacingM),
          children: [
            _buildSectionHeader('AUTOMATION'),
            _buildToolItem(
              icon: Icons.notifications_active_outlined,
              title: 'Arrival Alerts',
              subtitle: 'Auto-notify when arriving at locations',
              iconColor: Colors.orange,
              trailing: Switch.adaptive(
                value: _geofenceEnabled,
                activeTrackColor: Theme.of(context).colorScheme.primary,
                onChanged: (value) async {
                  await GeofenceService.instance.setEnabled(value);
                  setState(() => _geofenceEnabled = value);
                },
              ),
              onTap: null,
            ),
            if (_geofenceEnabled)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.tokens.spacingL + 40,
                  0,
                  context.tokens.spacingL,
                  context.tokens.spacingM,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Detection radius',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: textColor.withValues(alpha: 0.7),
                              ),
                        ),
                        const Spacer(),
                        Text(
                          '${_geofenceRadius}m',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                      ),
                      child: Slider(
                        value: _geofenceRadius.toDouble(),
                        min: 100,
                        max: 1000,
                        divisions: 9,
                        onChanged: (value) {
                          setState(() => _geofenceRadius = value.round());
                        },
                        onChangeEnd: (value) async {
                          await GeofenceService.instance.setRadiusMeters(
                            value.round(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            _buildDivider(),
            _buildSectionHeader('UTILS'),
            _buildToolItem(
              icon: Icons.map_outlined,
              title: 'Border Crossing',
              subtitle: 'Manage monitored border wait times',
              iconColor: Colors.indigo,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BorderCrossingSelector(),
                ),
              ),
            ),
            _buildDivider(),
            Padding(
              padding: EdgeInsets.all(context.tokens.spacingL),
              child: Text(
                'More tools coming soon to help you on the road.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.tokens.spacingL,
        context.tokens.spacingM,
        context.tokens.spacingL,
        context.tokens.spacingS,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildToolItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.tokens.spacingL,
          vertical: context.tokens.spacingM,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(context.tokens.shapeM),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            SizedBox(width: context.tokens.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: textColor.withValues(alpha: 0.3),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: context.tokens.spacingL + 40,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.3),
    );
  }
}
