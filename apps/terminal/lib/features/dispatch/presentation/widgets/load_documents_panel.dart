import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow_core/milow_core.dart';
import 'package:terminal/features/dispatch/presentation/providers/load_documents_provider.dart';
import 'package:terminal/features/dispatch/presentation/widgets/load_document_review_dialog.dart';
import 'package:intl/intl.dart';

class LoadDocumentsPanel extends ConsumerWidget {
  final String loadId;

  const LoadDocumentsPanel({super.key, required this.loadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Using simple FutureProvider now
    final docsAsync = ref.watch(loadDocumentsProvider(loadId));
    final theme = FluentTheme.of(context);

    return Column(
      children: [
        // Header with refresh
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LOAD DOCUMENTS',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: theme.resources.textFillColorSecondary,
                  letterSpacing: 1.1,
                ),
              ),
              IconButton(
                icon: const Icon(FluentIcons.arrow_clockwise_24_regular, size: 16),
                onPressed: () => ref.invalidate(loadDocumentsProvider(loadId)),
              ),
            ],
          ),
        ),

        Expanded(
          child: docsAsync.when(
            data: (docs) {
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        FluentIcons.document_24_regular,
                        size: 48,
                        color: theme.resources.textFillColorSecondary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No documents uploaded',
                        style: GoogleFonts.outfit(
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                separatorBuilder: (context, _) => const Divider(),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  return _buildDocumentItem(context, ref, doc);
                },
              );
            },
            loading: () => const Center(child: ProgressRing()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentItem(BuildContext context, WidgetRef ref, LoadDocument doc) {
    final theme = FluentTheme.of(context);
    final statusColor = _getStatusColor(doc.status);

    return HoverButton(
      onPressed: () => _openReviewDialog(context, ref, doc),
      builder: (context, states) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: states.isHovered 
                ? theme.resources.subtleFillColorTertiary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              // Icon/Thumbnail placeholder
              Container(
                width: 40,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.resources.cardBackgroundFillColorDefault,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: theme.resources.dividerStrokeColorDefault),
                ),
                child: Center(
                  child: Icon(
                    doc.documentType == TripDocumentType.proofOfDelivery
                        ? FluentIcons.note_24_regular
                        : FluentIcons.document_24_regular,
                    size: 20,
                    color: theme.accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Name & Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.documentType.label,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doc.createdAt != null
                          ? DateFormat('MM/dd/yy HH:mm').format(doc.createdAt!)
                          : 'Uploaded',
                      style: theme.typography.caption,
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  doc.status.name.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.approved:
        return Colors.green;
      case DocumentStatus.rejected:
        return Colors.red;
      case DocumentStatus.pending:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _openReviewDialog(BuildContext context, WidgetRef ref, LoadDocument doc) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => LoadDocumentReviewDialog(document: doc),
    );

    if (result == true) {
      // Refresh the provider
      ref.invalidate(loadDocumentsProvider(loadId));
    }
  }
}
