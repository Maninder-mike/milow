import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:window_manager/window_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../settings/widgets/custom_about_dialog.dart';
import '../../../settings/utils/update_checker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/theme_provider.dart';
import 'package:terminal/features/dashboard/domain/models/search_result.dart';
import 'package:terminal/features/dashboard/presentation/providers/global_search_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:terminal/features/shared/widgets/shortcuts_reference_dialog.dart';

class CustomTitleBar extends StatefulWidget {
  final FocusNode? searchFocusNode;

  const CustomTitleBar({super.key, this.searchFocusNode});

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> {
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final foregroundColor = theme.resources.textFillColorPrimary;

    return Mica(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 650;
          final isMedium = constraints.maxWidth < 900;

          return SizedBox(
            height: 44,
            child: Stack(
              children: [
                // 1. Full drag area background
                const Positioned.fill(
                  child: DragToMoveArea(child: SizedBox.expand()),
                ),

                // 2. Left and Right Content
                Row(
                  children: [
                    // Windows Menu Bar (only show on Windows)
                    if (Platform.isWindows && !isSmall) ...[
                      const SizedBox(width: 8),
                      _WindowsMenuBar(foregroundColor: foregroundColor),
                    ],

                    // Spacer to push content to the edges
                    const Spacer(),

                    // Right area with actions
                    _ActionsRow(
                      foregroundColor: foregroundColor,
                      isCompact: isMedium,
                    ),

                    // Windows control buttons
                    if (Platform.isWindows) ...[
                      const SizedBox(width: 8),
                      _WindowControlButtons(isLight: isLight),
                    ] else ...[
                      // Right padding for macOS to not hug the edge too tight
                      const SizedBox(width: 16),
                    ],
                  ],
                ),

                // 3. Centered search bar
                // We use Align to center it perfectly in the window
                Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 600,
                      minWidth: isSmall ? 150 : 300,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _WindowsSearchBar(
                        focusNode: widget.searchFocusNode,
                        foregroundColor: foregroundColor,
                        isLight: isLight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Windows 10-style window control buttons
class _WindowControlButtons extends StatefulWidget {
  final bool isLight;

  const _WindowControlButtons({required this.isLight});

  @override
  State<_WindowControlButtons> createState() => _WindowControlButtonsState();
}

class _WindowControlButtonsState extends State<_WindowControlButtons> {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    _checkMaximized();
  }

  Future<void> _checkMaximized() async {
    final isMaximized = await windowManager.isMaximized();
    if (mounted) {
      setState(() => _isMaximized = isMaximized);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final iconColor = theme.resources.textFillColorPrimary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Minimize button
        _WindowButton(
          icon: FluentIcons.subtract_24_regular,
          iconColor: iconColor,
          hoverColor: theme.resources.subtleFillColorSecondary,
          onPressed: () async {
            await windowManager.minimize();
          },
        ),
        // Maximize/Restore button
        _WindowButton(
          icon: _isMaximized
              ? FluentIcons.square_multiple_24_regular
              : FluentIcons.maximize_24_regular,
          iconColor: iconColor,
          hoverColor: theme.resources.subtleFillColorSecondary,
          onPressed: () async {
            if (_isMaximized) {
              await windowManager.restore();
            } else {
              await windowManager.maximize();
            }
            await _checkMaximized();
          },
        ),
        // Close button
        _WindowButton(
          icon: FluentIcons.dismiss_24_regular,
          iconColor: iconColor,
          hoverColor: Colors.red,
          hoverIconColor: Colors.white,
          onPressed: () async {
            await windowManager.close();
          },
        ),
      ],
    );
  }
}

/// Individual window control button
class _WindowButton extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color hoverColor;
  final Color? hoverIconColor;
  final VoidCallback onPressed;

  const _WindowButton({
    required this.icon,
    required this.iconColor,
    required this.hoverColor,
    this.hoverIconColor,
    required this.onPressed,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 38,
          color: _isHovered ? widget.hoverColor : Colors.transparent,
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 16,
            color: _isHovered && widget.hoverIconColor != null
                ? widget.hoverIconColor
                : widget.iconColor,
          ),
        ),
      ),
    );
  }
}

/// Windows 11-style search bar using fluent_ui
class _WindowsSearchBar extends ConsumerStatefulWidget {
  final FocusNode? focusNode;
  final Color foregroundColor;
  final bool isLight;

  const _WindowsSearchBar({
    required this.focusNode,
    required this.foregroundColor,
    required this.isLight,
  });

  @override
  ConsumerState<_WindowsSearchBar> createState() => _WindowsSearchBarState();
}

class _WindowsSearchBarState extends ConsumerState<_WindowsSearchBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isFocused = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final resultsAsync = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider);

    // Sync controller with provider if changed externally (e.g. cleared)
    if (_controller.text != query && !_isFocused) {
      _controller.text = query;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 468, maxHeight: 32),
      child: Focus(
        onFocusChange: (focused) {
          setState(() => _isFocused = focused);
        },
        child: AutoSuggestBox<SearchResult>(
          controller: _controller,
          focusNode: widget.focusNode,
          items: resultsAsync.maybeWhen(
            data: (results) => results
                .map(
                  (r) => AutoSuggestBoxItem<SearchResult>(
                    value: r,
                    label: r.title,
                    child: Row(
                      children: [
                        if (r.icon != null) ...[
                          Icon(
                            r.icon,
                            size: 16,
                            color: theme.resources.textFillColorSecondary,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                r.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.1,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                r.subtitle.replaceAll('\n', ' '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.1,
                                  color: theme.resources.textFillColorSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            orElse: () => [],
          ),
          placeholder: 'Search loads, drivers (Cmd+P)',
          onChanged: (value, reason) {
            ref.read(searchQueryProvider.notifier).update(value);
          },
          onSelected: (item) {
            final result = item.value;
            if (result == null) return;

            if (result.route != null) {
              context.go(result.route!);
            } else if (result.data is String) {
              // Handle special command actions
              final command = result.data as String;
              switch (command) {
                case 'open_shortcuts':
                  showDialog(
                    context: context,
                    builder: (context) => const ShortcutsReferenceDialog(),
                  );
                  break;
                case 'open_report_issue':
                  launchUrl(
                    Uri.parse('https://github.com/Maninder-mike/milow/issues'),
                  );
                  break;
                case 'open_help':
                  launchUrl(
                    Uri.parse('https://github.com/Maninder-mike/milow/wiki'),
                  );
                  break;
              }
            }

            // Clear query after selection if it was a navigation action
            if (result.type == SearchResultType.action) {
              ref.read(searchQueryProvider.notifier).update('');
              _controller.clear();
            }
          },
          trailingIcon: query.isNotEmpty
              ? IconButton(
                  icon: const Icon(FluentIcons.dismiss_24_regular, size: 14),
                  onPressed: () {
                    _controller.clear();
                    ref.read(searchQueryProvider.notifier).update('');
                  },
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    FluentIcons.search_24_regular,
                    size: 16,
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
          decoration: WidgetStateProperty.all(
            BoxDecoration(
              color: theme.resources.cardBackgroundFillColorDefault,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _isFocused
                    ? theme.accentColor
                    : theme.resources.dividerStrokeColorDefault,
                width: _isFocused ? 1.5 : 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Windows-specific menu bar widget
class _WindowsMenuBar extends StatelessWidget {
  final Color foregroundColor;

  const _WindowsMenuBar({required this.foregroundColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MenuBarItem(
          label: 'File',
          foregroundColor: foregroundColor,
          menuItems: [
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.info_24_regular, size: 16),
              text: const Text('About Milow Terminal'),
              onPressed: () => showCustomAboutDialog(context),
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.arrow_sync_24_regular, size: 16),
              text: const Text('Check for Updates...'),
              onPressed: () => checkForUpdates(context),
            ),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.dismiss_24_regular, size: 16),
              text: const Text('Exit'),
              onPressed: () => exit(0),
            ),
          ],
        ),
        _MenuBarItem(
          label: 'Edit',
          foregroundColor: foregroundColor,
          menuItems: [
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.arrow_undo_24_regular, size: 16),
              text: const Text('Undo'),
              trailing: const Text('Ctrl+Z'),
              onPressed: () {},
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.arrow_redo_24_regular, size: 16),
              text: const Text('Redo'),
              trailing: const Text('Ctrl+Shift+Z'),
              onPressed: () {},
            ),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.cut_24_regular, size: 16),
              text: const Text('Cut'),
              trailing: const Text('Ctrl+X'),
              onPressed: () {},
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.copy_24_regular, size: 16),
              text: const Text('Copy'),
              trailing: const Text('Ctrl+C'),
              onPressed: () {},
            ),
            MenuFlyoutItem(
              leading: const Icon(
                FluentIcons.clipboard_paste_24_regular,
                size: 16,
              ),
              text: const Text('Paste'),
              trailing: const Text('Ctrl+V'),
              onPressed: () {},
            ),
            MenuFlyoutItem(
              leading: const Icon(
                FluentIcons.select_all_on_24_regular,
                size: 16,
              ),
              text: const Text('Select All'),
              trailing: const Text('Ctrl+A'),
              onPressed: () {},
            ),
          ],
        ),
        _MenuBarItem(
          label: 'View',
          foregroundColor: foregroundColor,
          menuItems: [
            MenuFlyoutSubItem(
              text: const Text('Theme'),
              items: (context) => [
                MenuFlyoutItem(
                  text: const Text('System'),
                  onPressed: () {
                    final ref = ProviderScope.containerOf(context);
                    ref.read(themeProvider.notifier).setTheme(ThemeMode.system);
                  },
                ),
                MenuFlyoutItem(
                  text: const Text('Light'),
                  onPressed: () {
                    final ref = ProviderScope.containerOf(context);
                    ref.read(themeProvider.notifier).setTheme(ThemeMode.light);
                  },
                ),
                MenuFlyoutItem(
                  text: const Text('Dark'),
                  onPressed: () {
                    final ref = ProviderScope.containerOf(context);
                    ref.read(themeProvider.notifier).setTheme(ThemeMode.dark);
                  },
                ),
              ],
            ),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              leading: const Icon(
                FluentIcons.full_screen_maximize_24_regular,
                size: 16,
              ),
              text: const Text('Toggle Full Screen'),
              trailing: const Text('F11'),
              onPressed: () async {
                final isFullScreen = await windowManager.isFullScreen();
                await windowManager.setFullScreen(!isFullScreen);
              },
            ),
          ],
        ),
        _MenuBarItem(
          label: 'Window',
          foregroundColor: foregroundColor,
          menuItems: [
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.subtract_24_regular, size: 16),
              text: const Text('Minimize'),
              trailing: const Text('Ctrl+M'),
              onPressed: () async => await windowManager.minimize(),
            ),
            MenuFlyoutItem(
              leading: const Icon(
                FluentIcons.arrow_maximize_24_regular,
                size: 16,
              ),
              text: const Text('Zoom'),
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.restore();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.dismiss_24_regular, size: 16),
              text: const Text('Close Window'),
              trailing: const Text('Ctrl+W'),
              onPressed: () async => await windowManager.close(),
            ),
          ],
        ),
        _MenuBarItem(
          label: 'Tools',
          foregroundColor: foregroundColor,
          menuItems: [
            MenuFlyoutItem(
              leading: const Icon(
                FluentIcons.document_add_24_regular,
                size: 16,
              ),
              text: const Text('Master Entry'),
              onPressed: () {},
            ),
            MenuFlyoutItem(
              leading: const Icon(
                FluentIcons.calendar_day_24_regular,
                size: 16,
              ),
              text: const Text('Day to Day Entry'),
              onPressed: () {},
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.edit_24_regular, size: 16),
              text: const Text('Modify Entries'),
              onPressed: () {},
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.delete_24_regular, size: 16),
              text: const Text('Delete Entries'),
              onPressed: () {},
            ),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.gas_pump_24_regular, size: 16),
              text: const Text('Fuel-Tax (IFTA)'),
              onPressed: () {},
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.book_24_regular, size: 16),
              text: const Text('GL Module'),
              onPressed: () {},
            ),
            MenuFlyoutItem(
              leading: const Icon(
                FluentIcons.shield_checkmark_24_regular,
                size: 16,
              ),
              text: const Text('CSA/FAST Module'),
              onPressed: () {},
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.receipt_24_regular, size: 16),
              text: const Text('Master Invoice'),
              onPressed: () {},
            ),
          ],
        ),
        _MenuBarItem(
          label: 'Help',
          foregroundColor: foregroundColor,
          menuItems: [
            MenuFlyoutItem(
              leading: const Icon(
                FluentIcons.question_circle_24_regular,
                size: 16,
              ),
              text: const Text('Milow Terminal Help'),
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }
}

/// Individual menu bar item with dropdown flyout
class _MenuBarItem extends StatefulWidget {
  final String label;
  final Color foregroundColor;
  final List<MenuFlyoutItemBase> menuItems;

  const _MenuBarItem({
    required this.label,
    required this.foregroundColor,
    required this.menuItems,
  });

  @override
  State<_MenuBarItem> createState() => _MenuBarItemState();
}

class _MenuBarItemState extends State<_MenuBarItem> {
  final FlyoutController _flyoutController = FlyoutController();
  bool _isHovered = false;

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                return MenuFlyout(items: widget.menuItems);
              },
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _isHovered
                  ? theme.resources.subtleFillColorSecondary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.foregroundColor,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  final Color foregroundColor;
  final bool isCompact;

  const _ActionsRow({required this.foregroundColor, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Settings Action
        IconButton(
          icon: Icon(
            FluentIcons.settings_24_regular,
            size: 20,
            color: foregroundColor,
          ),
          onPressed: () {
            context.go('/settings');
          },
        ),
        const SizedBox(width: 12),
        // Divider
        if (!isCompact) ...[
          Container(
            height: 16,
            width: 1,
            color: theme.resources.dividerStrokeColorDefault,
          ),
          const SizedBox(width: 12),
        ],
        // User Profile
        _UserHeader(isCompact: isCompact),
      ],
    );
  }
}

class _UserHeader extends StatelessWidget {
  final bool isCompact;
  const _UserHeader({this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) return const SizedBox();

    return FutureBuilder(
      future: Supabase.instance.client
          .from('profiles')
          .select('avatar_url, role')
          .eq('id', userId)
          .single(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final avatarUrl = data?['avatar_url'] as String?;
        final role = data?['role'] as String? ?? 'User';

        // Fallback to metadata if available immediately while loading
        final metaAvatar =
            Supabase
                    .instance
                    .client
                    .auth
                    .currentUser
                    ?.userMetadata?['avatar_url']
                as String?;
        final effectiveUrl = avatarUrl ?? metaAvatar;

        final userEmail = Supabase.instance.client.auth.currentUser?.email;
        final initials = (userEmail?.isNotEmpty == true)
            ? userEmail![0].toUpperCase()
            : '?';

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final location = GoRouterState.of(context).matchedLocation;
              if (location == '/profile') {
                context.go('/dashboard');
              } else {
                context.go('/profile');
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isCompact) ...[
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                ],
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.neutral,
                    border: Border.all(
                      color: theme.resources.cardStrokeColorDefault,
                      width: 1.5,
                    ),
                    image: effectiveUrl != null
                        ? DecorationImage(
                            image: NetworkImage(effectiveUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: effectiveUrl == null
                      ? Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
