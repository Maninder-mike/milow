import 'package:flutter/material.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/services/load_repository.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/widgets/m3_spring_button.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class LoadDetailsPage extends StatefulWidget {
  final String loadId;

  const LoadDetailsPage({required this.loadId, super.key});

  @override
  State<LoadDetailsPage> createState() => _LoadDetailsPageState();
}

class _LoadDetailsPageState extends State<LoadDetailsPage> {
  Load? _load;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final loads = await LoadRepository.getLoads(refresh: true);
      // Enterprise Pattern: Find by ID in localized cache
      final load = loads.firstWhere((l) => l.id == widget.loadId);
      if (mounted) {
        setState(() {
          _load = load;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading load details: $e')),
        );
      }
    }
  }

  Future<void> _updateStopArrival(Stop stop) async {
    if (_load == null) return;
    try {
      await LoadRepository.updateStopArrival(
        stop.id,
        _load!.id,
        DateTime.now(),
      );
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update arrival: $e')));
      }
    }
  }

  Future<void> _updateStopCompletion(Stop stop, bool isCompleted) async {
    if (_load == null) return;
    try {
      await LoadRepository.updateStopStatus(stop.id, _load!.id, isCompleted);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update completion: $e')),
        );
      }
    }
  }

  void _openInMaps(LoadLocation loc) async {
    final query = Uri.encodeComponent(
      '${loc.address}, ${loc.city}, ${loc.state}',
    );
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_load == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Load Not Found')),
        body: const Center(
          child: Text('The requested load could not be found.'),
        ),
      );
    }

    final load = _load!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Load #${load.tripNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push(
              '/chat',
              extra: {
                'loadId': load.id,
                'partnerName': 'Dispatch - ${load.loadReference}',
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Load Overview Card
            _buildOverviewSection(load),
            SizedBox(height: tokens.spacingL),

            // Vertical Timeline of Stops
            Text(
              'STOP TIMELINE',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: tokens.textTertiary,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: tokens.spacingM),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: load.stops.length,
              itemBuilder: (context, index) {
                return _buildTimelineItem(
                  context,
                  load.stops[index],
                  isFirst: index == 0,
                  isLast: index == load.stops.length - 1,
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomAction(load),
    );
  }

  Widget _buildOverviewSection(Load load) {
    final tokens = context.tokens;
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.shapeL),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacingM),
        child: Column(
          children: [
            _buildDetailRow(Icons.business_rounded, 'Broker', load.brokerName),
            const Divider(height: 24),
            _buildDetailRow(
              Icons.inventory_2_outlined,
              'Commodity',
              load.goods,
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildDetailRow(
                    Icons.scale_outlined,
                    'Weight',
                    '${load.weight} ${load.weightUnit}',
                  ),
                ),
                Expanded(
                  child: _buildDetailRow(
                    Icons.numbers_rounded,
                    'Quantity',
                    load.quantity,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    final tokens = context.tokens;
    return Row(
      children: [
        Icon(icon, size: 20, color: tokens.textSecondary),
        SizedBox(width: tokens.spacingM),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: tokens.textTertiary),
            ),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    Stop stop, {
    required bool isFirst,
    required bool isLast,
  }) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;

    final bool isArrived = stop.arrivedAt != null;
    final bool isCompleted = stop.isCompleted;

    Color stateColor = tokens.textTertiary;
    if (isCompleted) {
      stateColor = tokens.success;
    } else if (isArrived) {
      stateColor = tokens.warning;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Timeline Graphics
          Column(
            children: [
              Container(
                width: 2,
                height: 20,
                color: isFirst
                    ? Colors.transparent
                    : tokens.surfaceContainerHigh,
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: stateColor, width: 2),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check
                      : (stop.type == StopType.pickup
                            ? Icons.storefront
                            : Icons.location_on),
                  size: 16,
                  color: stateColor,
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: isLast
                      ? Colors.transparent
                      : tokens.surfaceContainerHigh,
                ),
              ),
            ],
          ),
          SizedBox(width: tokens.spacingM),

          // Right: Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'STOP ${stop.sequence}: ${stop.type.name.toUpperCase()}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: stateColor,
                        ),
                      ),
                      if (stop.appointmentTime != null)
                        Text(
                          DateFormat.Hm().format(stop.appointmentTime!),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stop.location.address,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${stop.location.city}, ${stop.location.state}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (stop.notes != null && stop.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(tokens.shapeS),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: tokens.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              stop.notes!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildActionChip(
                        context,
                        Icons.map_outlined,
                        'Map',
                        () => _openInMaps(stop.location),
                      ),
                      const SizedBox(width: 8),
                      if (!isCompleted)
                        _buildActionChip(
                          context,
                          isArrived
                              ? Icons.check_circle_outline
                              : Icons.near_me_outlined,
                          isArrived ? 'Complete' : 'Arrived',
                          () {
                            if (isArrived) {
                              _updateStopCompletion(stop, true);
                            } else {
                              _updateStopArrival(stop);
                            }
                          },
                          isPrimary: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isPrimary = false,
  }) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;

    return M3SpringButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary
              ? colorScheme.primary
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(tokens.shapeFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isPrimary ? colorScheme.onPrimary : colorScheme.onSurface,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isPrimary
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildBottomAction(Load load) {
    if (load.status == LoadStatus.delivered ||
        load.status == LoadStatus.cancelled) {
      return null;
    }

    // If the load needs to be accepted
    final isUnaccepted =
        load.status == LoadStatus.assigned ||
        load.status == LoadStatus.pending ||
        load.status == LoadStatus.dispatched ||
        load.status == LoadStatus.tendered;

    // Determine the first pending stop
    final nextStop = load.stops.firstWhere(
      (s) => !s.isCompleted,
      orElse: () => load.stops.last,
    );

    final bool isArrived = nextStop.arrivedAt != null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(context.tokens.spacingM),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: isUnaccepted
              ? FilledButton.icon(
                  onPressed: () async {
                    setState(() => _isLoading = true);
                    try {
                      await LoadRepository.updateLoadStatus(
                        load.id,
                        LoadStatus.enRoute,
                      );
                      await _loadData();
                    } catch (e) {
                      if (mounted) {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to accept load: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text(
                    'ACCEPT LOAD',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                )
              : FilledButton.icon(
                  onPressed: () {
                    if (isArrived) {
                      _updateStopCompletion(nextStop, true);
                    } else {
                      _updateStopArrival(nextStop);
                    }
                  },
                  icon: Icon(isArrived ? Icons.done : Icons.near_me),
                  label: Text(
                    isArrived
                        ? 'Complete ${nextStop.type.name} at ${nextStop.location.city}'
                        : 'Arrived at ${nextStop.type.name} in ${nextStop.location.city}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
        ),
      ),
    );
  }
}
