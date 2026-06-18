import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';

class DocumentsEmptyState extends StatelessWidget {
  final VoidCallback? onScanPressed;
  final bool isFiltered;
  final String? title;
  final String? subtitle;
  final IconData? icon;

  const DocumentsEmptyState({
    super.key,
    this.onScanPressed,
    this.isFiltered = false,
    this.title,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DesignTokens>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? (isFiltered ? Icons.filter_alt_off_outlined : Icons.document_scanner_outlined),
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title ?? (isFiltered ? 'No documents match filters' : 'No Documents Yet'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle ?? (isFiltered 
                  ? 'Try changing your filters or search query to find what you are looking for.'
                  : 'Scan and upload your first document to get started. All your important paperwork will be securely stored here.'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            if (!isFiltered && onScanPressed != null) ...[
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onScanPressed,
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Scan Document'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
