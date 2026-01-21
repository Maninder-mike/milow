import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow_core/milow_core.dart';

/// Callback when a document is captured
typedef OnDocumentCaptured =
    void Function(
      File file,
      TripDocumentType documentType,
      StopType stopType,
      int stopIndex,
    );

/// Quick document capture button for attaching BOL/POD per stop
class DocumentCaptureButton extends StatelessWidget {
  final StopType stopType;
  final int stopIndex;
  final OnDocumentCaptured onDocumentCaptured;
  final List<TripDocumentType>? attachedDocTypes;

  const DocumentCaptureButton({
    required this.stopType,
    required this.stopIndex,
    required this.onDocumentCaptured,
    super.key,
    this.attachedDocTypes,
  });

  /// Get relevant document types based on stop type
  List<TripDocumentType> _getDocumentTypes() {
    if (stopType == StopType.pickup) {
      return [
        TripDocumentType.billOfLading,
        TripDocumentType.proofOfPickup,
        TripDocumentType.scaleTicket,
        TripDocumentType.commercialInvoice,
        TripDocumentType.other,
      ];
    } else {
      return [
        TripDocumentType.proofOfDelivery,
        TripDocumentType.billOfLading,
        TripDocumentType.scaleTicket,
        TripDocumentType.other,
      ];
    }
  }

  IconData _getDocumentIcon(TripDocumentType type) {
    switch (type) {
      case TripDocumentType.billOfLading:
        return Icons.description_outlined;
      case TripDocumentType.proofOfDelivery:
        return Icons.check_circle_outline;
      case TripDocumentType.proofOfPickup:
        return Icons.inventory_2_outlined;
      case TripDocumentType.scaleTicket:
        return Icons.scale_outlined;
      case TripDocumentType.commercialInvoice:
        return Icons.receipt_long_outlined;
      default:
        return Icons.attach_file_outlined;
    }
  }

  Future<void> _showDocumentPicker(BuildContext context) async {
    final tokens = context.tokens;

    final result =
        await showModalBottomSheet<
          ({TripDocumentType type, ImageSource source})
        >(
          context: context,
          showDragHandle: true,
          backgroundColor: tokens.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(tokens.shapeXL),
            ),
          ),
          builder: (context) => _DocumentPickerSheet(
            documentTypes: _getDocumentTypes(),
            getDocumentIcon: _getDocumentIcon,
            attachedDocTypes: attachedDocTypes ?? [],
          ),
        );

    if (result == null || !context.mounted) return;

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: result.source,
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
    );

    if (image != null && context.mounted) {
      onDocumentCaptured(File(image.path), result.type, stopType, stopIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hasAttachments = attachedDocTypes?.isNotEmpty ?? false;

    return Semantics(
      label: 'Attach document for ${stopType.name} ${stopIndex + 1}',
      button: true,
      child: InkWell(
        onTap: () => _showDocumentPicker(context),
        borderRadius: BorderRadius.circular(tokens.shapeS),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacingS,
            vertical: tokens.spacingXS,
          ),
          decoration: BoxDecoration(
            color: hasAttachments
                ? Theme.of(context).colorScheme.primaryContainer
                : tokens.surfaceContainer,
            borderRadius: BorderRadius.circular(tokens.shapeS),
            border: Border.all(
              color: hasAttachments
                  ? Theme.of(context).colorScheme.primary
                  : tokens.inputBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasAttachments
                    ? Icons.attach_file
                    : Icons.add_photo_alternate_outlined,
                size: 16,
                color: hasAttachments
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : tokens.textSecondary,
              ),
              SizedBox(width: tokens.spacingXS),
              Text(
                hasAttachments
                    ? '${attachedDocTypes!.length} attached'
                    : stopType == StopType.pickup
                    ? 'Attach BOL'
                    : 'Attach POD',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: hasAttachments
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for selecting document type and capture source
class _DocumentPickerSheet extends StatelessWidget {
  final List<TripDocumentType> documentTypes;
  final IconData Function(TripDocumentType) getDocumentIcon;
  final List<TripDocumentType> attachedDocTypes;

  const _DocumentPickerSheet({
    required this.documentTypes,
    required this.getDocumentIcon,
    required this.attachedDocTypes,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacingL,
          0,
          tokens.spacingL,
          tokens.spacingL,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Document Type',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: tokens.spacingM),
            Wrap(
              spacing: tokens.spacingS,
              runSpacing: tokens.spacingS,
              children: documentTypes.map((type) {
                final isAttached = attachedDocTypes.contains(type);
                return _DocumentTypeChip(
                  type: type,
                  icon: getDocumentIcon(type),
                  isAttached: isAttached,
                  onTap: () => _showSourcePicker(context, type),
                );
              }).toList(),
            ),
            SizedBox(height: tokens.spacingL),
          ],
        ),
      ),
    );
  }

  Future<void> _showSourcePicker(
    BuildContext context,
    TripDocumentType type,
  ) async {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: tokens.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.shapeXL),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacingL,
            0,
            tokens.spacingL,
            tokens.spacingL,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                type.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: tokens.spacingL),
              Row(
                children: [
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.camera_alt_outlined,
                      label: 'Camera',
                      onTap: () => Navigator.pop(context, ImageSource.camera),
                    ),
                  ),
                  SizedBox(width: tokens.spacingM),
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      onTap: () => Navigator.pop(context, ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (source != null && context.mounted) {
      Navigator.pop(context, (type: type, source: source));
    }
  }
}

/// Chip for selecting document type
class _DocumentTypeChip extends StatelessWidget {
  final TripDocumentType type;
  final IconData icon;
  final bool isAttached;
  final VoidCallback onTap;

  const _DocumentTypeChip({
    required this.type,
    required this.icon,
    required this.isAttached,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Semantics(
      label: '${type.label}${isAttached ? ", already attached" : ""}',
      button: true,
      child: Material(
        color: isAttached
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(tokens.shapeM),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.shapeM),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacingM,
              vertical: tokens.spacingS,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAttached ? Icons.check_circle : icon,
                  size: 18,
                  color: isAttached
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: tokens.spacingS),
                Text(
                  type.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isAttached
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Button for selecting camera or gallery
class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(tokens.shapeM),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.shapeM),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacingL),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                SizedBox(height: tokens.spacingS),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
