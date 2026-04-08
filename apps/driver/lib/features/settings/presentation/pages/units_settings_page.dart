import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/preferences_service.dart';

class UnitsSettingsPage extends StatefulWidget {
  const UnitsSettingsPage({super.key});

  @override
  State<UnitsSettingsPage> createState() => _UnitsSettingsPageState();
}

class _UnitsSettingsPageState extends State<UnitsSettingsPage> {
  UnitSystem _unitSystem = UnitSystem.metric;
  bool _autoDetect = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefService = Provider.of<PreferencesService>(context, listen: false);
    final sys = prefService.getUnitSystem();
    final autoDetect = prefService.getAutoUpdateUnits();

    if (mounted) {
      setState(() {
        _unitSystem = sys;
        _autoDetect = autoDetect;
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
          'Units',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.tokens.spacingL,
                context.tokens.spacingM,
                context.tokens.spacingL,
                context.tokens.spacingS,
              ),
              child: Text(
                'MEASUREMENT UNITS',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(
                'Auto-detect Units & Currency',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Set units automatically based on your current location',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              value: _autoDetect,
              activeThumbColor: Theme.of(context).colorScheme.primary,
              onChanged: (val) async {
                final prefService = context.read<PreferencesService>();
                await prefService.setAutoUpdateUnits(val);
                if (mounted) {
                  setState(() => _autoDetect = val);
                  if (val) {
                    // Trigger immediate sync if enabled
                    // ignore: use_build_context_synchronously
                    await _loadPreferences();
                  }
                }
              },
            ),
            _buildDivider(),
            _buildSystemRow(
              title: 'System',
              options: const [UnitSystem.metric, UnitSystem.imperial],
              currentValue: _unitSystem,
              enabled: !_autoDetect,
              onChanged: (val) async {
                final prefService = context.read<PreferencesService>();
                await prefService.setUnitSystem(val);
                if (mounted) setState(() => _unitSystem = val);
              },
            ),
            Padding(
              padding: EdgeInsets.all(context.tokens.spacingL),
              child: Text(
                _autoDetect 
                  ? 'Currently auto-detecting and using the ${_unitSystem == UnitSystem.metric ? "Metric" : "Imperial"} system for this region. These units will be used throughout the app for trips, fuel entries, and reports.'
                  : 'These units will be used throughout the app for trips, fuel entries, and reports.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor.withValues(alpha: 0.6),
                ),
              ),
            ),
            const Spacer(),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                  'Advanced Overrides',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Manually override specific units (e.g. km + Gallons)',
                  style: TextStyle(fontSize: 11),
                ),
                children: [
                  _buildGranularRow(
                    title: 'Distance',
                    currentValue: context.watch<PreferencesService>().getDistanceUnit(),
                    options: ['km', 'mi'],
                    onChanged: (val) => context.read<PreferencesService>().setDistanceUnit(val),
                  ),
                  _buildGranularRow(
                    title: 'Fuel Volume',
                    currentValue: context.watch<PreferencesService>().getVolumeUnit(),
                    options: ['L', 'gal'],
                    onChanged: (val) => context.read<PreferencesService>().setVolumeUnit(val),
                  ),
                  _buildGranularRow(
                    title: 'Weight',
                    currentValue: context.watch<PreferencesService>().getWeightUnit(),
                    options: ['kg', 'lbs'],
                    onChanged: (val) => context.read<PreferencesService>().setWeightUnit(val),
                  ),
                  SizedBox(height: context.tokens.spacingL),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGranularRow({
    required String title,
    required String currentValue,
    required List<String> options,
    required Function(String) onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.tokens.spacingL,
        vertical: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          SegmentedButton<String>(
            segments: options
                .map((opt) => ButtonSegment(
                      value: opt,
                      label: Text(opt),
                    ))
                .toList(),
            selected: {currentValue},
            onSelectionChanged: (set) => onChanged(set.first),
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemRow({
    required String title,
    required List<UnitSystem> options,
    required UnitSystem currentValue,
    required Function(UnitSystem) onChanged,
    bool enabled = true,
  }) {
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.tokens.spacingL,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(context.tokens.shapeM),
                ),
                child: Row(
                  children: options
                      .map(
                        (opt) => Expanded(
                          child: _buildSegmentButton(
                            opt == UnitSystem.metric ? 'Metric\n(km, L, kg)' : 'Imperial\n(mi, gal, lbs)',
                            currentValue == opt,
                            () => onChanged(opt),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentButton(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(context.tokens.shapeS),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: context.tokens.spacingL,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.3),
    );
  }
}
