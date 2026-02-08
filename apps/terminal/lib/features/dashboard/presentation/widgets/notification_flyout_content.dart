import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
// Correct relative paths from features/dashboard/presentation/widgets/
import '../../../notifications/domain/models/notification_item.dart';
import '../../../notifications/presentation/providers/notifications_aggregator_provider.dart';
import '../../../notifications/data/notification_provider.dart';
import '../../../../core/router/router_provider.dart';

class NotificationFlyoutContent extends ConsumerStatefulWidget {
  const NotificationFlyoutContent({super.key});

  @override
  ConsumerState<NotificationFlyoutContent> createState() =>
      _NotificationFlyoutContentState();
}

class _NotificationFlyoutContentState
    extends ConsumerState<NotificationFlyoutContent> {
  bool _showOnlyAlerts = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final notifications = ref.watch(notificationsAggregatorProvider);

    // Filter logic
    final displayedNotifications = _showOnlyAlerts
        ? notifications
              .where(
                (n) =>
                    n.type == NotificationType.error ||
                    n.type == NotificationType.warning,
              )
              .toList()
        : notifications;

    final unreadCount = notifications.where((n) => !n.isRead).length;

    return Container(
      width: 360,
      constraints: const BoxConstraints(maxHeight: 520),
      color: theme.resources.solidBackgroundFillColorBase,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(theme, unreadCount),

          // Tabs / Filter
          _buildFilterBar(theme),

          // Content
          Flexible(
            child: displayedNotifications.isEmpty
                ? _buildEmptyState(theme)
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: displayedNotifications.length,
                    separatorBuilder: (c, i) => Divider(
                      style: DividerThemeData(
                        thickness: 0.5,
                        decoration: BoxDecoration(
                          color: theme.resources.dividerStrokeColorDefault,
                        ),
                      ),
                    ),
                    itemBuilder: (context, index) {
                      return _NotificationTile(
                        item: displayedNotifications[index],
                      );
                    },
                  ),
          ),

          // Footer
          if (displayedNotifications.isNotEmpty) _buildFooter(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(FluentThemeData theme, int unreadCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.resources.dividerStrokeColorDefault),
        ),
        color: theme.resources.solidBackgroundFillColorSecondary,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Notifications',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: theme.resources.textFillColorPrimary,
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.accentColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),

          IconButton(
            icon: Icon(FluentIcons.checkmark_16_regular, size: 16),
            onPressed: () {
              // 1. Mark DB notifications as read
              ref.read(notificationActionsProvider).markAllAsRead();

              // 2. Dismiss local aggregation items (like pending users)
              final notifications = ref.read(notificationsAggregatorProvider);
              final ids = notifications.map((n) => n.id);
              ref.read(dismissedItemsProvider.notifier).addAll(ids);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      // Use standard subtle fill if tertiary is not available or valid
      color: theme.resources.subtleFillColorSecondary,
      child: Row(
        children: [
          _localFilterChip(
            label: 'All',
            isSelected: !_showOnlyAlerts,
            onTap: () => setState(() => _showOnlyAlerts = false),
          ),
          const SizedBox(width: 8),
          _localFilterChip(
            label: 'Alerts',
            isSelected: _showOnlyAlerts,
            isError: true,
            onTap: () => setState(() => _showOnlyAlerts = true),
          ),
        ],
      ),
    );
  }

  Widget _localFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isError = false,
  }) {
    final theme = FluentTheme.of(context);
    final selectedColor = isError ? AppColors.error : theme.accentColor;

    return HoverButton(
      onPressed: onTap,
      builder: (context, states) {
        final isHovering = states.contains(WidgetState.hovered);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? selectedColor.withValues(alpha: 0.15)
                : (isHovering
                      ? theme.resources.controlFillColorSecondary
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected
                  ? selectedColor.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? selectedColor
                  : theme.resources.textFillColorPrimary,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(FluentThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(
            FluentIcons.reading_mode_mobile_24_regular,
            size: 48,
            color: theme.resources.textFillColorSecondary.withValues(
              alpha: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'You\'re all caught up',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.resources.textFillColorPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No new notifications to show.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(FluentThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.resources.solidBackgroundFillColorSecondary,
        border: Border(
          top: BorderSide(color: theme.resources.dividerStrokeColorDefault),
        ),
      ),
      child: HyperlinkButton(
        onPressed: () {
          Flyout.of(context).close();
          ref.read(routerProvider).push('/inbox');
        },
        child: Text(
          'View all history',
          style: GoogleFonts.outfit(fontSize: 12),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;

  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final hoverColor = theme.resources.controlFillColorSecondary;

    return HoverButton(
      onPressed: () {
        Flyout.of(context).close();
        item.onTap?.call();
      },
      builder: (context, states) {
        return Container(
          color: states.contains(WidgetState.hovered)
              ? hoverColor
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIcon(context),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: theme.resources.textFillColorPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeAgo(item.timestamp),
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: theme.resources.textFillColorSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.body,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: theme.resources.textFillColorSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              if (item.onDismiss != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: IconButton(
                    icon: Icon(
                      FluentIcons.dismiss_16_regular,
                      size: 14,
                      color: theme.resources.textFillColorTertiary,
                    ),
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(const EdgeInsets.all(4)),
                    ),
                    onPressed: item.onDismiss,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIcon(BuildContext context) {
    IconData icon;
    Color color;

    final theme = FluentTheme.of(context);

    switch (item.type) {
      case NotificationType.error:
        icon = FluentIcons.error_circle_24_regular;
        color = AppColors.error;
        break;
      case NotificationType.warning:
        icon = FluentIcons.warning_24_regular;
        color = AppColors.warning;
        break;
      case NotificationType.success:
        icon = FluentIcons.checkmark_circle_24_regular;
        color = AppColors.success;
        break;
      case NotificationType.info:
        icon = FluentIcons.info_24_regular;
        color = theme.accentColor;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 7) {
      return DateFormat('MM/dd').format(dateTime);
    } else if (diff.inDays >= 1) {
      return '${diff.inDays}d';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes >= 1) {
      return '${diff.inMinutes}m';
    } else {
      return 'Just now';
    }
  }
}
