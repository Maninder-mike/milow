import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:milow_core/milow_core.dart';
import 'package:intl/intl.dart';

import '../providers/load_events_provider.dart';
import '../providers/load_providers.dart';
import 'create_check_call_dialog.dart';

class LoadTimelinePanel extends ConsumerWidget {
  final String loadId;

  const LoadTimelinePanel({super.key, required this.loadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(loadEventsStreamProvider(loadId));

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FluentIcons.clock_24_regular),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Load Timeline', style: FluentTheme.of(context).typography.subtitle),
              ),
              Tooltip(
                message: 'Request Structured Check-Call',
                child: IconButton(
                  icon: const Icon(FluentIcons.call_add_24_regular),
                  onPressed: () async {
                    // We need the driver_id. We can get it from the load details.
                    final loadsAsync = ref.read(loadsListProvider);
                    final load = loadsAsync.value?.firstWhere((l) => l.id == loadId);
                    
                    if (load?.assignedDriverId == null) {
                      displayInfoBar(
                        context,
                        builder: (context, close) => InfoBar(
                          title: const Text('Cannot request check-call'),
                          content: const Text('This load has no driver assigned.'),
                          severity: InfoBarSeverity.warning,
                          onClose: close,
                        ),
                      );
                      return;
                    }

                    await showDialog(
                      context: context,
                      builder: (context) => CreateCheckCallDialog(
                        loadId: loadId,
                        driverId: load!.assignedDriverId!,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: stream.when(
              data: (events) {
                if (events.isEmpty) {
                  return const Center(child: Text('No events yet.'));
                }
                // Group by day maybe, or just list timeline items
                return ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return _TimelineItem(
                      event: event,
                      isLast: index == events.length - 1,
                    );
                  },
                );
              },
              loading: () => const Center(child: ProgressRing()),
              error: (err, stack) => Center(child: Text('Error loading timeline: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final LoadEvent event;
  final bool isLast;

  const _TimelineItem({
    required this.event,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getEventColor(context, event.eventType),
                  ),
                  child: Center(
                    child: Icon(
                      _getEventIcon(event.eventType),
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getEventTitle(event),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DateFormat('MMM d, h:mm a').format(event.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: FluentTheme.of(context).resources.textFillColorTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_getEventSubtitle(event) != null)
                    Text(
                      _getEventSubtitle(event)!,
                      style: TextStyle(
                        color: FluentTheme.of(context).resources.textFillColorSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getEventIcon(LoadEventType type) {
    switch (type) {
      case LoadEventType.assigned:
        return FluentIcons.person_board_24_regular;
      case LoadEventType.accepted:
        return FluentIcons.checkmark_circle_24_regular;
      case LoadEventType.rejected:
        return FluentIcons.dismiss_circle_24_regular;
      case LoadEventType.enRoute:
        return FluentIcons.vehicle_truck_24_regular;
      case LoadEventType.arrived:
        return FluentIcons.location_24_regular;
      case LoadEventType.completed:
        return FluentIcons.checkmark_starburst_24_regular;
      case LoadEventType.statusChanged:
        return FluentIcons.status_24_regular;
      case LoadEventType.noteAdded:
        return FluentIcons.note_24_regular;
      case LoadEventType.documentAttached:
        return FluentIcons.document_24_regular;
      case LoadEventType.checkCall:
        return FluentIcons.call_24_regular;
    }
  }

  Color _getEventColor(BuildContext context, LoadEventType type) {
    switch (type) {
      case LoadEventType.accepted:
      case LoadEventType.completed:
        return Colors.green;
      case LoadEventType.rejected:
        return Colors.red;
      case LoadEventType.assigned:
      case LoadEventType.enRoute:
        return Colors.blue;
      case LoadEventType.arrived:
      case LoadEventType.checkCall:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getEventTitle(LoadEvent event) {
    switch (event.eventType) {
      case LoadEventType.assigned:
        return 'Load Assigned';
      case LoadEventType.accepted:
        return 'Load Accepted by Driver';
      case LoadEventType.rejected:
        return 'Load Rejected by Driver';
      case LoadEventType.enRoute:
        return 'Driver is En Route';
      case LoadEventType.arrived:
        final stopNum = event.eventData['stop_sequence'] ?? '?';
        return 'Driver Arrived at Stop $stopNum';
      case LoadEventType.completed:
        final stopNum = event.eventData['stop_sequence'] ?? '?';
        return 'Stop $stopNum Completed';
      case LoadEventType.statusChanged:
        final newStatus = event.eventData['new'] ?? 'unknown';
        return 'Status Changed: $newStatus';
      case LoadEventType.noteAdded:
        return 'Note Added';
      case LoadEventType.documentAttached:
        return 'Document Uploaded';
      case LoadEventType.checkCall:
        return 'Check-Call Update';
    }
  }

  String? _getEventSubtitle(LoadEvent event) {
    switch (event.eventType) {
      case LoadEventType.assigned:
        return 'Driver ID: ${event.eventData['driver_id']}';
      case LoadEventType.rejected:
        return 'Reason: ${event.eventData['reason'] ?? 'Not provided'}';
      case LoadEventType.statusChanged:
        final oldStatus = event.eventData['old'] ?? 'unknown';
        final newStatus = event.eventData['new'] ?? 'unknown';
        return 'Changed from $oldStatus to $newStatus';
      case LoadEventType.checkCall:
        return 'ETA: ${event.eventData['eta']}';
      default:
        return null;
    }
  }
}
