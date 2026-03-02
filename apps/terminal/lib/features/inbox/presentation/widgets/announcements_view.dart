import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/announcement_repository.dart';
import 'create_announcement_dialog.dart';

class AnnouncementsView extends ConsumerWidget {
  const AnnouncementsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(announcementsProvider);
    final theme = FluentTheme.of(context);

    return ScaffoldPage(
      header: PageHeader(
        title: Text(
          'Company Announcements',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add_24_regular),
              label: const Text('New Announcement'),
              onPressed: () => _showCreateAnnouncementDialog(context),
            ),
          ],
        ),
      ),
      content: announcementsAsync.when(
        data: (announcements) {
          if (announcements.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FluentIcons.megaphone_24_regular,
                    size: 48,
                    color: theme.resources.textFillColorSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No announcements yet',
                    style: theme.typography.subtitle,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              final title = announcement['title'] ?? 'No Title';
              final body = announcement['body'] ?? '';
              final createdAtStr = announcement['created_at'] as String?;
              final createdAt = createdAtStr != null
                  ? DateTime.parse(createdAtStr)
                  : DateTime.now();

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Expander(
                  header: Row(
                    children: [
                      const Icon(FluentIcons.megaphone_20_regular),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (DateTime.now().difference(createdAt).inHours < 24)
                        IconButton(
                          icon: const Icon(
                            FluentIcons.delete_20_regular,
                            size: 16,
                          ),
                          onPressed: () =>
                              _handleDelete(context, ref, announcement['id']),
                        ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat.yMMMd().format(createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    body,
                    style: TextStyle(
                      color: theme.resources.textFillColorPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: ProgressRing()),
        error: (err, stack) =>
            Center(child: Text('Error loading announcements: $err')),
      ),
    );
  }

  void _showCreateAnnouncementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateAnnouncementDialog(),
    );
  }

  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Delete Announcement?'),
        content: const Text(
          'This will remove the announcement for all users. This action cannot be undone.',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                FluentTheme.of(context).accentColor,
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      final repo = ref.read(announcementRepositoryProvider);
      final deleteResult = await repo.deleteAnnouncement(id);

      if (context.mounted) {
        deleteResult.fold(
          (failure) => displayInfoBar(
            context,
            builder: (context, close) => InfoBar(
              title: const Text('Error'),
              content: Text(failure.message),
              severity: InfoBarSeverity.error,
            ),
          ),
          (_) => displayInfoBar(
            context,
            builder: (context, close) => const InfoBar(
              title: Text('Success'),
              content: Text('Announcement deleted'),
              severity: InfoBarSeverity.success,
            ),
          ),
        );
      }
    }
  }
}
