import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';

class RecordsFilterBar extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const RecordsFilterBar({
    required this.selectedFilter,
    required this.onFilterChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56, // Comfort height for touch targets (48px targets + padding)
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        children: [
          _buildFilterChip(context, 'All'),
          const SizedBox(width: 8),
          _buildFilterChip(context, 'Trips Only'),
          const SizedBox(width: 8),
          _buildFilterChip(context, 'Fuel Only'),
          const SizedBox(width: 8),
          Container(
            height: 20,
            width: 1,
            color: context.tokens.subtleBorderColor,
            margin: const EdgeInsets.only(right: 8),
          ),
          _buildFilterChip(context, 'Short (<100 mi)'),
          const SizedBox(width: 8),
          _buildFilterChip(context, 'Medium (100-200 mi)'),
          const SizedBox(width: 8),
          _buildFilterChip(context, 'Long (>200 mi)'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label) {
    final isSelected = selectedFilter == label;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          onFilterChanged(label);
        }
      },
      // Styling to match M3 aesthetics
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant,
        fontSize: 13, // Slightly smaller
      ),
      selectedColor: colorScheme.primaryContainer,
      backgroundColor: colorScheme.surfaceContainerLow,
      side: BorderSide(
        color: isSelected
            ? Colors.transparent
            : context.tokens.subtleBorderColor,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.tokens.shapeFull),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      showCheckmark: false, // Cleaner look without checkmark
    );
  }
}
