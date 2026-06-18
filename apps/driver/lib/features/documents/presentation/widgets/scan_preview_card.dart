import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow_core/milow_core.dart';
import 'package:intl/intl.dart';
import 'document_type_icon.dart';
import 'dart:io';

class ScanPreviewCard extends StatelessWidget {
  final TripDocument document;
  final VoidCallback onTap;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  const ScanPreviewCard({
    required this.document, required this.onTap, super.key,
    this.onRetry,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DesignTokens>()!;
    final isFailed = document.status == DocumentStatus.uploadFailed;
    final isUploading = document.status == DocumentStatus.pendingUpload;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: tokens.surfaceContainer,
            borderRadius: BorderRadius.circular(tokens.shapeM),
            border: Border.all(
              color: isFailed ? tokens.error : tokens.subtleBorderColor,
            ),
          ),
          child: Row(
            children: [
              // Thumbnail placeholder (would show real image in production)
              Container(
                width: 80,
                height: 100,
                decoration: BoxDecoration(
                  color: tokens.surfaceContainerHigh,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(tokens.shapeM - 1),
                  ),
                  image: File(document.filePath).existsSync()
                      ? DecorationImage(
                          image: FileImage(File(document.filePath)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: !File(document.filePath).existsSync()
                    ? Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: tokens.textTertiary,
                        ),
                      )
                    : null,
              ),
              
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          DocumentTypeIcon(type: document.documentType, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              document.documentType.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(document.createdAt),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                      const Spacer(),
                      if (isUploading) ...[
                        Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Uploading...',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                      ] else if (isFailed) ...[
                        Row(
                          children: [
                            Icon(Icons.error_outline, size: 14, color: tokens.error),
                            const SizedBox(width: 4),
                            Text(
                              'Upload Failed',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: tokens.error,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Actions
              if (isFailed)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.refresh, color: tokens.error),
                        onPressed: onRetry,
                        tooltip: 'Retry Upload',
                      ),
                    ],
                  ),
                )
              else if (isUploading)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    icon: Icon(Icons.cancel_outlined, color: tokens.textSecondary),
                    onPressed: onCancel,
                    tooltip: 'Cancel Upload',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('MMM d, y • HH:mm').format(date);
  }
}
