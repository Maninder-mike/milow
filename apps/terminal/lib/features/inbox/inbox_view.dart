import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'data/announcement_repository.dart';

class InboxView extends ConsumerStatefulWidget {
  const InboxView({super.key});

  @override
  ConsumerState<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends ConsumerState<InboxView> {
  final _messageController = TextEditingController();

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      await ref
          .read(announcementRepositoryProvider)
          .createAnnouncement(_messageController.text.trim());
      _messageController.clear();
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: const Text('Success'),
              content: const Text('Message sent!'),
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
              severity: InfoBarSeverity.success,
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: const Text('Error'),
              content: Text(e.toString()),
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
              severity: InfoBarSeverity.error,
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final announcementsAsync = ref.watch(announcementsProvider);

    return ScaffoldPage(
      header: PageHeader(
        title: Text(
          'Inbox & Announcements',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        commandBar: FilledButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => ContentDialog(
                title: const Text('New Announcement'),
                content: TextBox(
                  controller: _messageController,
                  placeholder: 'Type your message...',
                  maxLines: 3,
                ),
                actions: [
                  Button(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _sendMessage();
                    },
                    child: const Text('Send'),
                  ),
                ],
              ),
            );
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.add),
              SizedBox(width: 8),
              Text('New Message'),
            ],
          ),
        ),
      ),
      content: announcementsAsync.when(
        data: (messages) {
          if (messages.isEmpty) {
            return const Center(child: Text('No announcements yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final date =
                  DateTime.tryParse(msg['created_at'] ?? '') ?? DateTime.now();

              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(FluentIcons.megaphone, color: Colors.blue),
                ),
                title: Text(
                  msg['title'] ?? 'No Title',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(msg['body'] ?? ''),
                trailing: Text(DateFormat.yMMMd().add_jm().format(date)),
              );
            },
          );
        },
        loading: () => const Center(child: ProgressRing()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
