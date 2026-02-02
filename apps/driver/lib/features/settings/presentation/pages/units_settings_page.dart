import 'package:flutter/material.dart';
import 'dart:async';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/preferences_service.dart';

class UnitsSettingsPage extends StatefulWidget {
  const UnitsSettingsPage({super.key});

  @override
  State<UnitsSettingsPage> createState() => _UnitsSettingsPageState();
}

class _UnitsSettingsPageState extends State<UnitsSettingsPage> {
  String _distanceUnit = 'km';
  String _volumeUnit = 'L';
  String _weightUnit = 'lb';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final dUnit = await PreferencesService.getDistanceUnit();
    final vUnit = await PreferencesService.getVolumeUnit();
    final wUnit = await PreferencesService.getWeightUnit();

    if (mounted) {
      setState(() {
        _distanceUnit = dUnit;
        _volumeUnit = vUnit;
        _weightUnit = wUnit;
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
            _buildUnitRow(
              title: 'Distance',
              options: ['mi', 'km'],
              currentValue: _distanceUnit,
              onChanged: (val) async {
                await PreferencesService.setDistanceUnit(val);
                if (mounted) setState(() => _distanceUnit = val);
              },
            ),
            _buildDivider(),
            _buildUnitRow(
              title: 'Volume',
              options: ['gal', 'L'],
              currentValue: _volumeUnit,
              onChanged: (val) async {
                await PreferencesService.setVolumeUnit(val);
                if (mounted) setState(() => _volumeUnit = val);
              },
            ),
            _buildDivider(),
            _buildUnitRow(
              title: 'Weight',
              options: ['lb', 'kg'],
              currentValue: _weightUnit,
              onChanged: (val) async {
                await PreferencesService.setWeightUnit(val);
                if (mounted) setState(() => _weightUnit = val);
              },
            ),
            Padding(
              padding: EdgeInsets.all(context.tokens.spacingL),
              child: Text(
                'These units will be used throughout the app for trips, fuel entries, and reports.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitRow({
    required String title,
    required List<String> options,
    required String currentValue,
    required Function(String) onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.tokens.spacingL,
        vertical: 16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(context.tokens.shapeM),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: options
                  .map(
                    (opt) => _buildSegmentButton(
                      opt.toUpperCase(),
                      currentValue == opt,
                      () => onChanged(opt),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
