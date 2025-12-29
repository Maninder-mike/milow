import 'package:flutter/material.dart';

import 'package:milow/core/models/border_wait_time.dart';
import 'package:milow/core/services/border_wait_time_service.dart';

class BorderWaitList extends StatelessWidget {
  const BorderWaitList({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BorderWaitTime>>(
      future: BorderWaitTimeService.fetchAllWaitTimes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final items = snapshot.data!;
        // Sort by delay descending to show bottlenecks first?
        // Or maybe just show major crossings.
        // For now, let's take a slice of popular ones or filtered list.
        // Since we don't have a "popular" flag, let's just show top 10 unique ports.
        final displayItems = items.take(10).toList();

        if (displayItems.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: displayItems.length,
            separatorBuilder: (c, i) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = displayItems[index];
              return _buildCard(context, item);
            },
          ),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, BorderWaitTime item) {
    int delay = item.commercialDelay ?? 0;
    // If null or -1, treat as 0 or unknown
    if (delay < 0) delay = 0;

    Color statusColor;
    if (delay < 15) {
      statusColor = Colors.green;
    } else if (delay < 45) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.red;
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.portName,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              item.crossingName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    '$delay min',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
