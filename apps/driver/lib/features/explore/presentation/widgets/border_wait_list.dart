import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/models/border_wait_time.dart';
import 'package:milow/core/services/border_wait_time_service.dart';

class BorderWaitList extends StatelessWidget {
  final bool isDark;

  const BorderWaitList({required this.isDark, super.key});

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
              return _buildCard(item);
            },
          ),
        );
      },
    );
  }

  Widget _buildCard(BorderWaitTime item) {
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

    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.portName,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            item.crossingName,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  '$delay min',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
