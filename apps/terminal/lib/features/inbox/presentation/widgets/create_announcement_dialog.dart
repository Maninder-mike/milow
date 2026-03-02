import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terminal/features/settings/providers/company_provider.dart';
import '../../data/announcement_repository.dart';

class CreateAnnouncementDialog extends ConsumerStatefulWidget {
  const CreateAnnouncementDialog({super.key});

  @override
  ConsumerState<CreateAnnouncementDialog> createState() =>
      _CreateAnnouncementDialogState();
}

class _CreateAnnouncementDialogState
    extends ConsumerState<CreateAnnouncementDialog> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('New Announcement'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextBox(
            controller: _titleController,
            placeholder: 'Title',
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: 16),
          TextBox(
            controller: _bodyController,
            placeholder: 'Announcement body...',
            maxLines: 5,
            enabled: !_isSubmitting,
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Text('Publish'),
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (body.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final companyId = await ref.read(currentCompanyIdProvider.future);
      final repo = ref.read(announcementRepositoryProvider);
      final result = await repo.createAnnouncement(
        title.isEmpty ? 'Announcement' : title,
        body,
        companyId,
      );

      if (mounted) {
        result.fold((failure) {
          setState(() => _isSubmitting = false);
          displayInfoBar(
            context,
            builder: (context, close) => InfoBar(
              title: const Text('Error'),
              content: Text(failure.message),
              severity: InfoBarSeverity.error,
            ),
          );
        }, (_) => Navigator.pop(context));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Error'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
          ),
        );
      }
    }
  }
}
