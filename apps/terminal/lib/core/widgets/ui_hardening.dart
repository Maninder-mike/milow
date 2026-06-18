import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

/// A standardized error state widget following the "Icon-Title-Description-Action" pattern.
class StandardErrorState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;

  const StandardErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.icon = FluentIcons.error_circle_24_regular,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.typography.subtitle?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.typography.body?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onRetry,
                child: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A standardized empty state widget.
class StandardEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  const StandardEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = FluentIcons.search_info_24_regular,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: theme.resources.textFillColorTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.typography.subtitle?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.typography.body?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A simple box that represents a skeleton loader element.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 4.0,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: theme.resources.controlFillColorSecondary,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: theme.resources.surfaceStrokeColorDefault.withValues(alpha: 0.05),
        ),
      ),
    );
  }
}

/// A skeleton loader for a list tile.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const SkeletonBox(width: 32, height: 32, borderRadius: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 120, height: 12),
                const SizedBox(height: 6),
                const SkeletonBox(width: 80, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A skeleton loader for a data table.
class TableSkeleton extends StatelessWidget {
  final int rowCount;
  final List<int> columnFlex;
  final bool showCheckbox;

  const TableSkeleton({
    super.key,
    this.rowCount = 8,
    this.columnFlex = const [3, 2, 1, 2, 2],
    this.showCheckbox = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final resources = theme.resources;

    return Column(
      children: [
        // Header Skeleton
        Container(
          height: 48,
          color: resources.subtleFillColorSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (showCheckbox) const SizedBox(width: 40),
              for (var flex in columnFlex)
                Expanded(
                  flex: flex,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: SkeletonBox(height: 14),
                  ),
                ),
              const SizedBox(width: 80), // Actions space
            ],
          ),
        ),
        const Divider(),
        // Rows Skeleton
        Expanded(
          child: ListView.separated(
            itemCount: rowCount,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              return Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (showCheckbox) const SizedBox(width: 40),
                    for (var flex in columnFlex)
                      Expanded(
                        flex: flex,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 16),
                          child: Opacity(
                            opacity: 0.5,
                            child: SkeletonBox(height: 16),
                          ),
                        ),
                      ),
                    const SizedBox(width: 80), // Actions space
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
