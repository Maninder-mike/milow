import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow_core/milow_core.dart';
import 'package:go_router/go_router.dart';
import 'document_type_icon.dart';

class DocumentCard extends StatelessWidget {
  final TripDocument document;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDetailsTap;
  final Function(bool?)? onSelectionChanged;

  const DocumentCard({
    required this.document, required this.isSelected, required this.isSelectionMode, required this.onTap, required this.onLongPress, required this.onDetailsTap, super.key,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DesignTokens>()!;
    final isPendingOrFailed = document.status == DocumentStatus.pendingUpload ||
        document.status == DocumentStatus.uploadFailed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Card(
          elevation: 0,
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : tokens.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.shapeM),
            side: BorderSide(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: IgnorePointer(
            ignoring: isSelectionMode || isPendingOrFailed,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DocumentTypeIcon(type: document.documentType, size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    document.fileName ??
                                        document.documentType.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildStatusBadge(document.status, tokens),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              document.description?.isNotEmpty == true
                                  ? document.description!
                                  : (document.notes?.isNotEmpty == true
                                      ? document.notes!
                                      : (document.tripNumber != null 
                                          ? 'Load #${document.tripNumber}' 
                                          : 'No notes')),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: tokens.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (isSelectionMode)
                        Checkbox(
                          value: isSelected,
                          onChanged: onSelectionChanged,
                          shape: const CircleBorder(),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: onDetailsTap,
                        ),
                    ],
                  ),
                  
                  if (document.status == DocumentStatus.rejected &&
                      document.reviewNotes != null) ...[
                    const SizedBox(height: 12),
                    _buildRejectionCallout(context, tokens),
                  ],

                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: tokens.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(document.createdAt),
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: tokens.textTertiary),
                      ),
                      const SizedBox(width: 16),
                      if (document.fileSize != null) ...[
                        Icon(
                          Icons.sd_storage_outlined,
                          size: 14,
                          color: tokens.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatFileSize(document.fileSize),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: tokens.textTertiary),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRejectionCallout(BuildContext context, DesignTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(tokens.shapeS),
        border: Border.all(color: tokens.error.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.report_problem_outlined, size: 16, color: tokens.error),
              const SizedBox(width: 6),
              Text(
                'Reason for Rejection:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: tokens.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            document.reviewNotes!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.textPrimary,
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              context.push(
                '/chat',
                extra: {
                  'loadId': document.tripId,
                  'partnerName': 'Load #${document.tripNumber ?? 'Unknown'}',
                },
              );
            },
            icon: const Icon(Icons.chat_bubble_outline, size: 16),
            label: const Text('Message Dispatcher'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(DocumentStatus status, DesignTokens tokens) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case DocumentStatus.approved:
        color = tokens.success;
        icon = Icons.check_circle_outline;
        label = 'Approved';
        break;
      case DocumentStatus.rejected:
        color = tokens.error;
        icon = Icons.error_outline;
        label = 'Rejected';
        break;
      case DocumentStatus.pending:
        color = tokens.warning;
        icon = Icons.access_time;
        label = 'Pending';
        break;
      case DocumentStatus.pendingUpload:
        color = tokens.textTertiary;
        icon = Icons.cloud_upload_outlined;
        label = 'Uploading';
        break;
      case DocumentStatus.uploadFailed:
        color = tokens.error;
        icon = Icons.cloud_off;
        label = 'Failed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(tokens.shapeS),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('MMM d, y • HH:mm').format(date);
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return 'Unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
