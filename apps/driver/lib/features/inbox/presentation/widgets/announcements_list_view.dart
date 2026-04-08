import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/announcements_provider.dart';

class AnnouncementsListView extends StatelessWidget {
  const AnnouncementsListView({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final provider = context.watch<AnnouncementsProvider>();
    final announcements = provider.announcements;

    if (provider.isLoading && announcements.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (announcements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No announcements yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Company-wide news will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: announcements.length,
      padding: EdgeInsets.all(tokens.spacingM),
      itemBuilder: (context, index) {
        final announcement = announcements[index];
        return _AnnouncementCard(announcement: announcement);
      },
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;

  const _AnnouncementCard({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Card(
      margin: EdgeInsets.only(bottom: tokens.spacingM),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.shapeM),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(tokens.spacingS),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.campaign_rounded,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                SizedBox(width: tokens.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(announcement.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacingM),
            Text(
              announcement.content,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) return 'Just now';
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return DateFormat.E().add_Hm().format(date);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}
