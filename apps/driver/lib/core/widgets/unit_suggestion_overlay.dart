import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/providers/unit_suggestion_provider.dart';
import 'package:milow/core/services/preferences_service.dart';
import 'package:milow/core/utils/unit_utils.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

class UnitSuggestionOverlay extends StatefulWidget {
  final String countryCode;
  final VoidCallback onDismiss;

  const UnitSuggestionOverlay({
    required this.countryCode,
    required this.onDismiss,
    super.key,
  });

  @override
  State<UnitSuggestionOverlay> createState() => _UnitSuggestionOverlayState();
}

class _UnitSuggestionOverlayState extends State<UnitSuggestionOverlay> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final provider = context.watch<UnitSuggestionProvider>();
    final isImperial = UnitUtils.isImperial(widget.countryCode);
    final systemName = isImperial ? 'Imperial' : 'Metric';

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        margin: EdgeInsets.all(tokens.spacingM),
        decoration: BoxDecoration(
          color: tokens.surfaceContainer,
          borderRadius: BorderRadius.circular(tokens.shapeXL),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: tokens.subtleBorderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacingM,
                tokens.spacingM,
                tokens.spacingS,
                tokens.spacingM,
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(tokens.spacingS),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.language,
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: tokens.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Crossing into ${widget.countryCode}?',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          'Suggested: $systemName units',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: tokens.textSecondary,
                    ),
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    tooltip: 'Granular units',
                  ),
                ],
              ),
            ),
            if (_isExpanded) _buildGranularOverrides(context),
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacingM,
                0,
                tokens.spacingM,
                tokens.spacingM,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onDismiss,
                    child: Text(
                      'Dismiss',
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                  ),
                  SizedBox(width: tokens.spacingS),
                  FilledButton(
                    onPressed: () => provider.acceptSuggestion(),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tokens.shapeButton),
                      ),
                    ),
                    child: Text('Switch to $systemName'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGranularOverrides(BuildContext context) {
    final tokens = context.tokens;
    final prefs = context.watch<PreferencesService>();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacingM),
      child: Column(
        children: [
          const Divider(),
          _buildUnitToggle(
            'Distance',
            prefs.getDistanceUnit(),
            ['mi', 'km'],
            (val) => prefs.setDistanceUnit(val),
          ),
          _buildUnitToggle(
            'Volume',
            prefs.getVolumeUnit(),
            ['gal', 'L'],
            (val) => prefs.setVolumeUnit(val),
          ),
          _buildUnitToggle(
            'Weight',
            prefs.getWeightUnit(),
            ['lbs', 'kg'],
            (val) => prefs.setWeightUnit(val),
          ),
          SizedBox(height: tokens.spacingS),
        ],
      ),
    );
  }

  Widget _buildUnitToggle(
    String label,
    String current,
    List<String> options,
    Function(String) onTarget,
  ) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: tokens.textSecondary,
            ),
          ),
          SegmentedButton<String>(
            segments: options.map((o) => ButtonSegment(
              value: o,
              label: Text(o, style: const TextStyle(fontSize: 12)),
            )).toList(),
            selected: {current},
            onSelectionChanged: (set) => onTarget(set.first),
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}
