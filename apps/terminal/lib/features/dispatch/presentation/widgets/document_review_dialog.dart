import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow_core/milow_core.dart';
import 'package:intl/intl.dart';

class DocumentReviewDialog extends ConsumerStatefulWidget {
  final TripDocument document;

  const DocumentReviewDialog({super.key, required this.document});

  @override
  ConsumerState<DocumentReviewDialog> createState() =>
      _DocumentReviewDialogState();
}

class _DocumentReviewDialogState extends ConsumerState<DocumentReviewDialog> {
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(DocumentStatus status) async {
    if (widget.document.id == null) return;

    setState(() => _isSubmitting = true);

    final result = await DocumentRepository.updateDocumentStatus(
      documentId: widget.document.id!,
      status: status,
      notes: _notesController.text,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);

      result.fold(
        (failure) {
          displayInfoBar(
            context,
            builder: (context, close) => InfoBar(
              title: const Text('Error'),
              content: Text(failure.message),
              severity: InfoBarSeverity.error,
              onClose: close,
            ),
          );
        },
        (updatedDoc) {
          Navigator.pop(context, true);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      title: Text(
        'Review Document: ${widget.document.documentType.label}',
        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 800,
        height: 600,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.resources.cardBackgroundFillColorDefault,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: theme.resources.dividerStrokeColorDefault,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: widget.document.url != null
                      ? Image.network(
                          widget.document.url!,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: ProgressRing());
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    FluentIcons.error_circle_24_regular,
                                    size: 48,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Failed to load document preview',
                                    style: GoogleFonts.outfit(),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : const Center(child: Text('No URL provided')),
                ),
              ),
            ),
            const SizedBox(width: 24),
            // Details & Actions
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDetailRow(
                    'Trip #',
                    widget.document.tripNumber ?? 'N/A',
                  ),
                  _buildDetailRow(
                    'Uploaded',
                    widget.document.createdAt != null
                        ? DateFormat(
                            'MM/dd/yy HH:mm',
                          ).format(widget.document.createdAt!)
                        : 'Unknown',
                  ),
                  if (widget.document.notes != null)
                    _buildDetailRow('Driver Notes', widget.document.notes!),
                  const Spacer(),
                  Text(
                    'Review Feedback',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextBox(
                    controller: _notesController,
                    placeholder: 'Enter review notes/feedback...',
                    maxLines: 5,
                    enabled: !_isSubmitting,
                  ),
                  const SizedBox(height: 24),
                  if (_isSubmitting)
                    const Center(child: ProgressRing())
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Button(
                            onPressed: () =>
                                _updateStatus(DocumentStatus.rejected),
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith(
                                (states) => states.isHovered
                                    ? Colors.red.withValues(alpha: 0.1)
                                    : Colors.transparent,
                              ),
                              foregroundColor: WidgetStateProperty.all(
                                Colors.red,
                              ),
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                _updateStatus(DocumentStatus.approved),
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all(
                                const Color(0xFF43A047),
                              ),
                            ),
                            child: const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: FluentTheme.of(context).resources.textFillColorSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
