import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/features/learning/domain/models/learning_resource.dart';

class LearningResourceCard extends StatelessWidget {
  final LearningResource resource;
  final VoidCallback onTap;

  const LearningResourceCard({
    required this.resource,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      margin: EdgeInsets.only(bottom: tokens.spacingM),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.shapeM),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.shapeM),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacingM),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail / Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(tokens.shapeS),
                ),
                child: Center(
                  child: Icon(
                    _getIconForType(resource.type),
                    color: colorScheme.primary,
                    size: 32,
                  ),
                ),
              ),
              SizedBox(width: tokens.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: tokens.spacingXS),
                    Text(
                      resource.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: tokens.spacingXS),
                    Row(
                      children: [
                        _buildTag(
                          context,
                          _getCategoryLabel(resource.category),
                        ),
                        if (resource.duration != null) ...[
                          SizedBox(width: tokens.spacingS),
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(resource.duration!),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(context.tokens.shapeXS),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  IconData _getIconForType(LearningResourceType type) {
    switch (type) {
      case LearningResourceType.video:
        return Icons.play_circle_outline;
      case LearningResourceType.article:
        return Icons.article_outlined;
      case LearningResourceType.document:
        return Icons.description_outlined;
    }
  }

  String _getCategoryLabel(LearningCategory category) {
    switch (category) {
      case LearningCategory.safety:
        return 'Safety';
      case LearningCategory.compliance:
        return 'Compliance';
      case LearningCategory.maintenance:
        return 'Vehicle Care';
      case LearningCategory.general:
        return 'General';
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
