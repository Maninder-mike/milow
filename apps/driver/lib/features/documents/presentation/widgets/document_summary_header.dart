import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow_core/milow_core.dart';

class DocumentSummaryHeader extends StatelessWidget {
  final List<TripDocument> documents;
  final Function(DocumentStatus?) onStatusSelected;
  final DocumentStatus? selectedStatus;

  const DocumentSummaryHeader({
    required this.documents, required this.onStatusSelected, super.key,
    this.selectedStatus,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DesignTokens>()!;

    final int totalCount = documents.length;
    final int pendingCount = documents.where((d) => d.status == DocumentStatus.pending).length;
    final int approvedCount = documents.where((d) => d.status == DocumentStatus.approved).length;
    final int rejectedCount = documents.where((d) => d.status == DocumentStatus.rejected).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          _buildSummaryChip(
            context,
            tokens,
            icon: Icons.description,
            label: 'Total',
            count: totalCount,
            color: tokens.textSecondary,
            isSelected: selectedStatus == null,
            onTap: () => onStatusSelected(null),
          ),
          const SizedBox(width: 8),
          _buildSummaryChip(
            context,
            tokens,
            icon: Icons.access_time,
            label: 'Pending',
            count: pendingCount,
            color: tokens.warning,
            isSelected: selectedStatus == DocumentStatus.pending,
            onTap: () => onStatusSelected(DocumentStatus.pending),
          ),
          const SizedBox(width: 8),
          _buildSummaryChip(
            context,
            tokens,
            icon: Icons.error_outline,
            label: 'Rejected',
            count: rejectedCount,
            color: tokens.error,
            isSelected: selectedStatus == DocumentStatus.rejected,
            onTap: () => onStatusSelected(DocumentStatus.rejected),
          ),
          const SizedBox(width: 8),
          _buildSummaryChip(
            context,
            tokens,
            icon: Icons.check_circle_outline,
            label: 'Approved',
            count: approvedCount,
            color: tokens.success,
            isSelected: selectedStatus == DocumentStatus.approved,
            onTap: () => onStatusSelected(DocumentStatus.approved),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(
    BuildContext context,
    DesignTokens tokens, {
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : tokens.surfaceContainer,
          borderRadius: BorderRadius.circular(tokens.shapeS),
          border: Border.all(
            color: isSelected ? color : tokens.subtleBorderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : tokens.textSecondary),
            const SizedBox(width: 6),
            Text(
              '$label: ',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isSelected ? color : tokens.textSecondary,
                  ),
            ),
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? color : tokens.textPrimary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
