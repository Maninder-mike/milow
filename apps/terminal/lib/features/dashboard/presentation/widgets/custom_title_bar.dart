import 'package:fluent_ui/fluent_ui.dart';
import 'package:window_manager/window_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

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

    final backgroundColor = isLight
        ? const Color(0xFFDDDDDD)
        : const Color(0xFF3C3C3C);
    final foregroundColor = isLight ? const Color(0xFF333333) : Colors.white;
    final iconColor = isLight ? const Color(0xFF333333) : Colors.white;

    return SizedBox(
      height: 38,
      child: Container(
        color: backgroundColor,
        child: Row(
          children: [
            const Expanded(
              child: DragToMoveArea(child: SizedBox(height: double.infinity)),
            ),
            Expanded(
              flex: 4,
              child: DragToMoveArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 450,
                      height: 28,
                      child: AutoSuggestBox<String>(
                        focusNode: widget.searchFocusNode,
                        placeholder: 'Search files, trips, customer, etc.',
                        leadingIcon: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            FluentIcons.search,
                            size: 12,
                            color: iconColor,
                          ),
                        ),
                        style: TextStyle(color: foregroundColor),
                        items: [
                          AutoSuggestBoxItem(
                            value: 'Customer: John Doe',
                            label: 'Customer: John Doe',
                          ),
                          AutoSuggestBoxItem(
                            value: 'Trip: #12345',
                            label: 'Trip: #12345',
                          ),
                          AutoSuggestBoxItem(
                            value: 'Cmd: Reload Window',
                            label: '> Reload Window',
                          ),
                        ],
                        onSelected: (item) {
                          debugPrint('Selected: ${item.value}');
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: DragToMoveArea(
                      child: SizedBox(height: double.infinity),
                    ),
                  ),
                  const _UserHeader(),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  const _UserHeader();

  @override
  Widget build(BuildContext context) {
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: FluentTheme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: FluentTheme.of(
                        context,
                      ).resources.dividerStrokeColorDefault,
                    ),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey,
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
                            fontSize: 12,
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
