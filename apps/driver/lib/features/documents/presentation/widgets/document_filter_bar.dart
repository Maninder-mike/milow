import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow_core/milow_core.dart';

class DocumentFilterBar extends StatelessWidget {
  final TripDocumentType? selectedType;
  final Function(TripDocumentType?) onTypeSelected;

  const DocumentFilterBar({
    required this.selectedType, required this.onTypeSelected, super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DesignTokens>()!;
    
    // Most common document types for quick filters
    final quickFilters = [
      TripDocumentType.billOfLading,
      TripDocumentType.proofOfDelivery,
      TripDocumentType.rateConfirmation,
      TripDocumentType.fuelReceipt,
      TripDocumentType.complianceWSIP,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          _buildFilterChip(
            context: context,
            tokens: tokens,
            label: 'All',
            isSelected: selectedType == null,
            onSelected: (_) => onTypeSelected(null),
          ),
          const SizedBox(width: 8),
          ...quickFilters.map((type) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildFilterChip(
                context: context,
                tokens: tokens,
                label: _getShortLabel(type),
                isSelected: selectedType == type,
                onSelected: (_) => onTypeSelected(type),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required DesignTokens tokens,
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      showCheckmark: false,
      backgroundColor: tokens.surfaceContainerHigh,
      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected 
            ? Theme.of(context).colorScheme.primary 
            : tokens.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected 
            ? Theme.of(context).colorScheme.primary 
            : tokens.subtleBorderColor,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.shapeButton),
      ),
    );
  }

  String _getShortLabel(TripDocumentType type) {
    switch (type) {
      case TripDocumentType.billOfLading:
        return 'BOL';
      case TripDocumentType.proofOfDelivery:
        return 'POD';
      case TripDocumentType.rateConfirmation:
        return 'Rate Conf';
      case TripDocumentType.fuelReceipt:
        return 'Fuel';
      case TripDocumentType.complianceWSIP:
        return 'Compliance';
      default:
        return type.label;
    }
  }
}
