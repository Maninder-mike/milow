import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/notification_service.dart';
// import 'package:intl/intl.dart';

class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  final FlyoutController _flyoutController = FlyoutController();
  bool _isHovered = false;

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationListProvider);
    final unreadCount = notifications.where((n) => !n.isRead).length;
    final theme = FluentTheme.of(context);

    return FlyoutTarget(
      controller: _flyoutController,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: () {
            _flyoutController.showFlyout(
              barrierDismissible: true,
              dismissOnPointerMoveAway: false,
              dismissWithEsc: true,
              builder: (context) {
                return MenuFlyout(
                  items: [
                    MenuFlyoutItem(
                      text: Text(
                        'Notifications ${unreadCount > 0 ? "($unreadCount)" : ""}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {},
                    ),
                    const MenuFlyoutSeparator(),
                    if (notifications.isEmpty)
                      MenuFlyoutItem(
                        text: const Text('No notifications'),
                        onPressed: () {},
                      ),
                    ...notifications.take(5).map((n) {
                      return MenuFlyoutItem(
                        leading: Icon(
                          n.isRead
                              ? FluentIcons.mail_read_24_regular
                              : FluentIcons.mail_24_filled,
                          size: 16,
                          color: n.isRead
                              ? theme.resources.textFillColorSecondary
                              : theme.accentColor,
                        ),
                        text: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              n.title,
                              style: TextStyle(
                                fontWeight: n.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                            Text(
                              n.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.resources.textFillColorSecondary,
                              ),
                            ),
                          ],
                        ),
                        onPressed: () {
                          // Mark as read logic
                          ref
                              .read(notificationListProvider.notifier)
                              .markAsRead(n.id);
                        },
                      );
                    }),
                    const MenuFlyoutSeparator(),
                    if (notifications.isNotEmpty)
                      MenuFlyoutItem(
                        text: const Text('Clear All'),
                        onPressed: () {
                          ref
                              .read(notificationListProvider.notifier)
                              .clearAll();
                        },
                      ),
                  ],
                );
              },
            );
          },
          child: Stack(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _isHovered
                      ? theme.resources.subtleFillColorSecondary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Icon(
                  unreadCount > 0
                      ? FluentIcons.alert_24_filled
                      : FluentIcons.alert_24_regular,
                  size: 20,
                  color: theme.resources.textFillColorPrimary,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.cardColor, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
