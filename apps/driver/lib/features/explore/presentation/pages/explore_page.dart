import 'package:flutter/material.dart';
import 'package:milow/core/theme/m3_expressive_motion.dart';
import 'package:milow/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/services/trip_repository.dart';
import 'package:milow/core/services/fuel_repository.dart';
import 'package:milow/core/services/data_prefetch_service.dart';
import 'package:milow/features/trips/presentation/pages/add_entry_page.dart';
import 'package:milow/features/explore/presentation/providers/explore_provider.dart';
import 'package:milow/features/explore/presentation/utils/explore_utils.dart';
import 'package:milow/features/explore/presentation/widgets/explore_map_view.dart';
import 'package:milow/features/explore/presentation/widgets/stats_overview_card.dart';
import 'package:milow/features/explore/presentation/widgets/state_collector_card.dart';
import 'package:milow/features/explore/presentation/widgets/smart_suggestions_card.dart';
import 'package:milow/features/explore/presentation/pages/visited_states_map_page.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExploreProvider>().loadData();
    });
  }

  Future<void> _onRefresh() async {
    await context.read<ExploreProvider>().loadData(forceRefresh: true);
  }

  // Methods moved to ExploreProvider:
  // _loadData, _generateMapMarkers, _calculateStats, _filteredTrips, _filteredDestinations, _filteredActivity
  // Methods moved to ExploreUtils:
  // _extractCityState, _extractLastCity, _toTitleCase, _extractStateCode

  @override
  Widget build(BuildContext context) {
    final exploreProvider = context.watch<ExploreProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text(
          AppLocalizations.of(context)?.explore ?? 'Explore',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surfaceContainerLow.withValues(alpha: 0.8),
              colorScheme.surfaceContainerLowest,
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          displacement: 20, // Reduced displacement since AppBar is fixed
          strokeWidth: 3.0,
          color: colorScheme.primary,
          backgroundColor: colorScheme.surface,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const SliverPadding(padding: EdgeInsets.only(top: 8)),

              if (exploreProvider.isLoading)
                SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3.0,
                      color: colorScheme.primary,
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: M3StaggeredList(
                    staggerDelay: const Duration(milliseconds: 100),
                    children: [
                      // Map Section - Immersive but framed
                      if (exploreProvider.selectedCategory == 'All Routes' ||
                          exploreProvider.selectedCategory == 'Long Haul' ||
                          exploreProvider.selectedCategory == 'Regional' ||
                          exploreProvider.selectedCategory == 'Local') ...[
                        const _SectionHeaderRow(
                          title: 'Activity Map',
                          horizontalPadding: 20,
                        ),
                        const SizedBox(height: 12),
                        if (exploreProvider.isMapLoading)
                          const SizedBox(
                            height: 300,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ExploreMapView(
                              markers: exploreProvider.mapMarkers,
                              onMarkerTap: (marker) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(marker.title),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(marker.subtitle),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Date: ${DateFormat.yMMMd().format(marker.date)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 32),
                      ],

                      // Stats & Intelligence Strip
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: StatsOverviewCard(),
                      ),
                      const SizedBox(height: 8),

                      // Achievement Progress
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: StateCollectorCard(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VisitedStatesMapPage(
                                  trips: exploreProvider.allTrips,
                                  fuelEntries: exploreProvider.allFuelEntries,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SmartSuggestionsCard(
                          trips: exploreProvider.allTrips,
                          fuelEntries: exploreProvider.allFuelEntries,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Trending Destinations
                      _SectionHeaderRow(
                        title: AppLocalizations.of(
                          context,
                        )!.popularDestinations,
                        horizontalPadding: 20,
                        onAction:
                            exploreProvider.filteredDestinations.isNotEmpty
                            ? () => _navigateToAllDestinations()
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildDestinationsList(exploreProvider),
                      ),
                      const SizedBox(height: 48),

                      // History / Activity
                      _SectionHeaderRow(
                        title: AppLocalizations.of(context)!.recentActivity,
                        horizontalPadding: 20,
                        onAction: exploreProvider.filteredActivity.isNotEmpty
                            ? () => _navigateToAllActivity()
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildActivityList(exploreProvider),
                      ),

                      // Dynamic bottom padding
                      SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 60,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDestinationsList(ExploreProvider exploreProvider) {
    if (exploreProvider.filteredDestinations.isEmpty) {
      return const _EmptyStateCard(
        message: 'No recent destinations found.',
        icon: Icons.map,
      );
    }
    return Column(
      children: exploreProvider.filteredDestinations.map((dest) {
        return _SimpleDestinationCard(
          destination: dest,
          onTap: () => _navigateToAllDestinations(),
        );
      }).toList(),
    );
  }

  Widget _buildActivityList(ExploreProvider provider) {
    final activity = provider.filteredActivity;
    if (activity.isEmpty) {
      return const _EmptyStateCard(
        message: 'No recent activity matches your filter.',
        icon: Icons.history_rounded,
      );
    }

    return Column(
      children: activity.map((item) {
        return _SimpleActivityCard(
          activity: item,
          onTap: () => _navigateToAllActivity(),
        );
      }).toList(),
    );
  }

  void _navigateToAllDestinations() {
    final exploreProvider = context.read<ExploreProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AllDestinationsPage(
          destinations: exploreProvider.filteredDestinations,
          categoryLabel: exploreProvider.selectedCategory,
        ),
      ),
    );
  }

  void _navigateToAllActivity() {
    final exploreProvider = context.read<ExploreProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AllActivityPage(
          trips: exploreProvider.filteredTrips,
          fuelEntries: exploreProvider.selectedCategory == 'All Routes'
              ? exploreProvider.allFuelEntries
              : [],
          categoryLabel: exploreProvider.selectedCategory,
        ),
      ),
    );
  }
}

// ============== Helper Widgets ==============

class _SectionHeaderRow extends StatelessWidget {
  final String title;
  final VoidCallback? onAction;
  final double horizontalPadding;

  const _SectionHeaderRow({
    required this.title,
    this.onAction,
    this.horizontalPadding = 0,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See all',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyStateCard({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              size: 24,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============== Simple Cards for Explore Page ==============

// ============== Flattened Components for Explore Page ==============

class _ExploreListItem extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback? onTap;

  const _ExploreListItem({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleDestinationCard extends StatelessWidget {
  final Map<String, dynamic> destination;
  final VoidCallback? onTap;

  const _SimpleDestinationCard({required this.destination, this.onTap});

  @override
  Widget build(BuildContext context) {
    final city = destination['city'] as String;
    final description = destination['description'] as String;
    final count = destination['count'] as int;

    return _ExploreListItem(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.location_on_rounded,
          color: Colors.orange,
          size: 20,
        ),
      ),
      title: city,
      subtitle: description,
      trailing: '$count visits',
    );
  }
}

class _SimpleActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final VoidCallback? onTap;

  const _SimpleActivityCard({required this.activity, this.onTap});

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) {
      return DateFormat('MMM d').format(date);
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = activity['title'] as String;
    final subtitle = activity['subtitle'] as String;
    final date = activity['date'] as DateTime;
    final type = activity['type'] as String;
    final isTrip = type == 'trip';

    return _ExploreListItem(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (isTrip ? Colors.blue : Colors.green).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isTrip
              ? Icons.local_shipping_rounded
              : Icons.local_gas_station_rounded,
          color: isTrip ? Colors.blue : Colors.green,
          size: 20,
        ),
      ),
      title: title,
      subtitle: subtitle,
      trailing: _formatTimeAgo(date),
    );
  }
}

// ============== Expandable Cards for See All Pages ==============

class _ExpandableRouteCard extends StatefulWidget {
  final Trip trip;

  const _ExpandableRouteCard({required this.trip});

  @override
  State<_ExpandableRouteCard> createState() => _ExpandableRouteCardState();
}

class _ExpandableRouteCardState extends State<_ExpandableRouteCard> {
  bool _isExpanded = false;

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  Color _getDistanceColor(BuildContext context, double? distance) {
    if (distance == null) return Theme.of(context).colorScheme.outline;
    if (distance > 500) return Theme.of(context).colorScheme.primary;
    if (distance >= 200) return Colors.orange;
    return Theme.of(context).colorScheme.tertiary;
  }

  String _getDistanceCategory(double? distance) {
    if (distance == null) return '';
    if (distance > 500) return 'Long Haul';
    if (distance >= 200) return 'Regional';
    return 'Local';
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final route =
        trip.pickupLocations.isNotEmpty && trip.deliveryLocations.isNotEmpty
        ? '${ExploreUtils.extractCityState(trip.pickupLocations.first)} → ${ExploreUtils.extractCityState(trip.deliveryLocations.last)}'
        : 'No route';
    final distance = trip.totalDistance;
    final distanceColor = _getDistanceColor(context, distance);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Distance section
                  Container(
                    width: 80,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          distance != null ? distance.toStringAsFixed(0) : '--',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          trip.distanceUnitLabel.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: distanceColor,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Vertical Divider
                  Container(
                    width: 1,
                    height: 40,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(width: 16),
                  // Trip info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trip ${trip.tripNumber}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          route,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Expand icon
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: M3ExpressiveMotion.durationShort,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Expanded content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildExpandedContent(context),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: M3ExpressiveMotion.durationShort,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    final trip = widget.trip;
    final distance = trip.totalDistance;
    final category = _getDistanceCategory(distance);
    final distanceColor = _getDistanceColor(context, distance);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Divider(
            color: Theme.of(context).colorScheme.outlineVariant,
            height: 1,
          ),
          const SizedBox(height: 16),

          // Trip details section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Trip Details',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: distanceColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: distanceColor,
                              ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(
                        context,
                        icon: Icons.calendar_today_outlined,
                        label: 'Date',
                        value: _formatDate(trip.tripDate),
                      ),
                    ),
                    Expanded(
                      child: _buildDetailItem(
                        context,
                        icon: Icons.directions_car_outlined,
                        label: 'Truck',
                        value: trip.truckNumber,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Odometer section
          if (trip.startOdometer != null || trip.endOdometer != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.tertiary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.speed_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Odometer',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${trip.startOdometer?.toStringAsFixed(0) ?? '--'} → ${trip.endOdometer?.toStringAsFixed(0) ?? '--'} ${trip.distanceUnitLabel}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

          if (trip.startOdometer != null || trip.endOdometer != null)
            const SizedBox(height: 12),

          // Locations
          Row(
            children: [
              Expanded(
                child: _buildLocationChip(
                  context,
                  icon: Icons.trip_origin,
                  label: 'Pickups',
                  locations: trip.pickupLocations,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLocationChip(
                  context,
                  icon: Icons.flag_outlined,
                  label: 'Deliveries',
                  locations: trip.deliveryLocations,
                  color: Colors.orange,
                ),
              ),
            ],
          ),

          // Trailers
          if (trip.trailers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.rv_hookup,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Trailers: ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      trip.trailers.join(', '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Notes
          if (trip.notes != null && trip.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.note_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.notes!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required List<String> locations,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                '$label (${locations.length})',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...locations
              .take(2)
              .map(
                (loc) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    ExploreUtils.extractCityState(loc),
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          if (locations.length > 2)
            Text(
              '+${locations.length - 2} more',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}

class _ExpandableDestinationCard extends StatefulWidget {
  final Map<String, dynamic> destination;

  const _ExpandableDestinationCard({required this.destination});

  @override
  State<_ExpandableDestinationCard> createState() =>
      _ExpandableDestinationCardState();
}

class _ExpandableDestinationCardState
    extends State<_ExpandableDestinationCard> {
  bool _isExpanded = false;

  String _formatDate(DateTime date) {
    return DateFormat('MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final city = widget.destination['city'] as String;
    final count = widget.destination['count'] as int;
    final trips = widget.destination['trips'] as List<Trip>? ?? [];
    final totalMiles = widget.destination['totalMiles'] as double? ?? 0.0;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Count section
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$count',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                        ),
                        Text(
                          count == 1 ? 'TRIP' : 'TRIPS',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                                fontSize: 9,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // City info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          city,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (totalMiles > 0)
                          Text(
                            '${totalMiles.toStringAsFixed(0)} miles total',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                  ),
                  // Expand icon
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: M3ExpressiveMotion.durationShort,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Expanded content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildExpandedContent(
                context,
                trips: trips,
                totalMiles: totalMiles,
              ),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: M3ExpressiveMotion.durationShort,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent(
    BuildContext context, {
    required List<Trip> trips,
    required double totalMiles,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Divider(
            color: Theme.of(context).colorScheme.outlineVariant,
            height: 1,
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  icon: Icons.local_shipping_outlined,
                  label: trips.length == 1 ? 'Trip' : 'Trips',
                  value: '${trips.length}',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  icon: Icons.straighten_outlined,
                  label: 'Distance',
                  value: '${totalMiles.toStringAsFixed(0)} mi',
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ],
          ),

          if (trips.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.history,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Trips',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...trips.take(3).map((trip) {
              final route =
                  trip.pickupLocations.isNotEmpty &&
                      trip.deliveryLocations.isNotEmpty
                  ? '${ExploreUtils.extractCityState(trip.pickupLocations.first)} → ${ExploreUtils.extractCityState(trip.deliveryLocations.last)}'
                  : 'Trip ${trip.tripNumber}';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.local_shipping_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trip ${trip.tripNumber}',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            route,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatDate(trip.tripDate),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        if (trip.totalDistance != null)
                          Text(
                            '${trip.totalDistance!.toStringAsFixed(0)} mi',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.tertiary,
                                ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableActivityCard extends StatefulWidget {
  final Map<String, dynamic> activity;

  const _ExpandableActivityCard({required this.activity});

  @override
  State<_ExpandableActivityCard> createState() =>
      _ExpandableActivityCardState();
}

class _ExpandableActivityCardState extends State<_ExpandableActivityCard> {
  bool _isExpanded = false;

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isTrip = widget.activity['type'] == 'trip';
    final accentColor = isTrip
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.tertiary;
    final date = widget.activity['date'] as DateTime;
    final icon = widget.activity['icon'] as IconData;
    final title = widget.activity['title'] as String;
    final subtitle = widget.activity['subtitle'] as String;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon section
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  // Info section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Time ago
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTimeAgo(date),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: M3ExpressiveMotion.durationShort,
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Expanded content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: isTrip
                  ? _buildTripExpandedContent(context)
                  : _buildFuelExpandedContent(context),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: M3ExpressiveMotion.durationShort,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripExpandedContent(BuildContext context) {
    final trip = widget.activity['trip'] as Trip?;
    if (trip == null) return const SizedBox.shrink();

    final distance = trip.totalDistance;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Divider(
            color: Theme.of(context).colorScheme.outlineVariant,
            height: 1,
          ),
          const SizedBox(height: 16),

          // Trip overview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(
                  context,
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: _formatDate(trip.tripDate),
                ),
                _buildInfoItem(
                  context,
                  icon: Icons.directions_car_outlined,
                  label: 'Truck',
                  value: trip.truckNumber,
                ),
                if (distance != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${distance.toStringAsFixed(0)} ${trip.distanceUnitLabel}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSecondary,
                                fontSize: 13,
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Locations
          Row(
            children: [
              Expanded(
                child: _buildLocationInfo(
                  context,
                  icon: Icons.trip_origin,
                  label: 'From',
                  locations: trip.pickupLocations,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLocationInfo(
                  context,
                  icon: Icons.flag_outlined,
                  label: 'To',
                  locations: trip.deliveryLocations,
                  color: Colors.orange,
                ),
              ),
            ],
          ),

          // Trailers
          if (trip.trailers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.rv_hookup,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Trailers: ${trip.trailers.join(', ')}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Notes
          if (trip.notes != null && trip.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.note_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.notes!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFuelExpandedContent(BuildContext context) {
    final fuel = widget.activity['fuel'] as FuelEntry?;
    if (fuel == null) return const SizedBox.shrink();

    final accentColor = Theme.of(context).colorScheme.tertiary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Divider(
            color: Theme.of(context).colorScheme.outlineVariant,
            height: 1,
          ),
          const SizedBox(height: 16),

          // Fuel overview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(
                  context,
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: _formatDate(fuel.fuelDate),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    fuel.formattedTotalCost,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Fuel details grid
          Row(
            children: [
              Expanded(
                child: _buildFuelDetailCard(
                  context,
                  icon: Icons.local_gas_station_outlined,
                  label: 'Quantity',
                  value:
                      '${fuel.fuelQuantity.toStringAsFixed(1)} ${fuel.fuelUnitLabel}',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFuelDetailCard(
                  context,
                  icon: Icons.attach_money,
                  label: 'Price',
                  value: fuel.formattedPricePerUnit,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Additional info
          Row(
            children: [
              if (fuel.isTruckFuel && fuel.truckNumber != null)
                Expanded(
                  child: _buildFuelDetailCard(
                    context,
                    icon: Icons.local_shipping_outlined,
                    label: 'Truck',
                    value: fuel.truckNumber!,
                    color: Colors.orange,
                  ),
                )
              else if (fuel.isReeferFuel && fuel.reeferNumber != null)
                Expanded(
                  child: _buildFuelDetailCard(
                    context,
                    icon: Icons.ac_unit_outlined,
                    label: 'Reefer',
                    value: fuel.reeferNumber!,
                    color: Colors.blue,
                  ),
                )
              else
                const Expanded(child: SizedBox()),
              const SizedBox(width: 12),
              if (fuel.isTruckFuel && fuel.odometerReading != null)
                Expanded(
                  child: _buildFuelDetailCard(
                    context,
                    icon: Icons.speed_outlined,
                    label: 'Odometer',
                    value:
                        '${fuel.odometerReading!.toStringAsFixed(0)} ${fuel.distanceUnitLabel}',
                    color: Colors.purple,
                  ),
                )
              else if (fuel.isReeferFuel && fuel.reeferHours != null)
                Expanded(
                  child: _buildFuelDetailCard(
                    context,
                    icon: Icons.timer_outlined,
                    label: 'Hours',
                    value: fuel.reeferHours!.toStringAsFixed(1),
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),

          // Location
          if (fuel.location != null && fuel.location!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fuel.location!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationInfo(
    BuildContext context, {
    required IconData icon,
    required String label,
    required List<String> locations,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                '$label (${locations.length})',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...locations
              .take(2)
              .map(
                (loc) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    ExploreUtils.extractCityState(loc),
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          if (locations.length > 2)
            Text(
              '+${locations.length - 2} more',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFuelDetailCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============== See All Pages ==============

class _AllDestinationsPage extends StatelessWidget {
  final List<Map<String, dynamic>> destinations;
  final String categoryLabel;

  const _AllDestinationsPage({
    required this.destinations,
    required this.categoryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          categoryLabel == 'All Routes'
              ? 'Popular Destinations'
              : '$categoryLabel Destinations',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: destinations.isEmpty
          ? Center(
              child: Text(
                categoryLabel == 'All Routes'
                    ? 'No destinations found'
                    : 'No destinations for $categoryLabel trips',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final dest = destinations[index];
                return _ExpandableDestinationCard(destination: dest);
              },
            ),
    );
  }
}

class _AllActivityPage extends StatefulWidget {
  final List<Trip> trips;
  final List<FuelEntry> fuelEntries;
  final String categoryLabel;

  const _AllActivityPage({
    required this.trips,
    required this.fuelEntries,
    required this.categoryLabel,
  });

  @override
  State<_AllActivityPage> createState() => _AllActivityPageState();
}

class _AllActivityPageState extends State<_AllActivityPage> {
  late List<Map<String, dynamic>> _activity;

  @override
  void initState() {
    super.initState();
    _buildActivityList();
  }

  void _buildActivityList() {
    _activity = [];

    for (final trip in widget.trips) {
      final route =
          trip.pickupLocations.isNotEmpty && trip.deliveryLocations.isNotEmpty
          ? '${ExploreUtils.extractCityState(trip.pickupLocations.first)} → ${ExploreUtils.extractCityState(trip.deliveryLocations.last)}'
          : 'Trip ${trip.tripNumber}';
      _activity.add({
        'type': 'trip',
        'title': 'Trip ${trip.tripNumber}',
        'subtitle': route,
        'date': trip.createdAt ?? trip.tripDate,
        'icon': Icons.local_shipping,
        'trip': trip,
      });
    }

    for (final fuel in widget.fuelEntries) {
      final location = fuel.location != null
          ? ExploreUtils.extractCityState(fuel.location!)
          : 'Unknown location';
      _activity.add({
        'type': 'fuel',
        'title': fuel.isTruckFuel ? 'Truck Fuel' : 'Reefer Fuel',
        'subtitle':
            '$location • ${fuel.fuelQuantity.toStringAsFixed(1)} ${fuel.fuelUnitLabel}',
        'date': fuel.createdAt ?? fuel.fuelDate,
        'icon': Icons.local_gas_station,
        'fuel': fuel,
      });
    }

    _activity.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );
  }

  Future<void> _deleteItem(Map<String, dynamic> item, int index) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final isTrip = item['type'] == 'trip';
    final title = item['title'] as String;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Delete ${isTrip ? 'Trip' : 'Fuel Entry'}',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete $title?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (isTrip) {
          final trip = item['trip'] as Trip;
          if (trip.id != null) {
            await TripRepository.deleteTrip(trip.id!);
          }
        } else {
          final fuel = item['fuel'] as FuelEntry;
          if (fuel.id != null) {
            await FuelRepository.deleteFuelEntry(fuel.id!);
          }
        }

        DataPrefetchService.instance.invalidateCache();

        setState(() {
          _activity.removeAt(index);
        });

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('$title deleted'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _modifyItem(Map<String, dynamic> item) async {
    final isTrip = item['type'] == 'trip';

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEntryPage(
          editingTrip: isTrip ? item['trip'] as Trip : null,
          editingFuel: !isTrip ? item['fuel'] as FuelEntry : null,
          initialTab: isTrip ? 0 : 1,
        ),
      ),
    );

    if (result == true) {
      DataPrefetchService.instance.invalidateCache();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.categoryLabel == 'All Routes'
              ? 'All Activity'
              : '${widget.categoryLabel} Activity',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: _activity.isEmpty
          ? Center(
              child: Text(
                widget.categoryLabel == 'All Routes'
                    ? 'No activity found'
                    : 'No ${widget.categoryLabel} activity found',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _activity.length,
              itemBuilder: (context, index) {
                final item = _activity[index];
                final isTrip = item['type'] == 'trip';

                return Dismissible(
                  key: Key(
                    '${item['type']}_${isTrip ? (item['trip'] as Trip).id : (item['fuel'] as FuelEntry).id}_$index',
                  ),
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Modify',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                  secondaryBackground: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Delete',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onError,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.delete,
                          color: Theme.of(context).colorScheme.onError,
                        ),
                      ],
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.endToStart) {
                      await _deleteItem(item, index);
                      return false;
                    } else {
                      await _modifyItem(item);
                      return false;
                    }
                  },
                  child: _ExpandableActivityCard(activity: item),
                );
              },
            ),
    );
  }
}

// ============== Search Dialog ==============
