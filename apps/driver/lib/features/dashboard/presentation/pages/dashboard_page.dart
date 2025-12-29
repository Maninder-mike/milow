import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// TabsShell provides navigation; this page returns content only
import 'package:milow/core/widgets/section_header.dart';
import 'package:milow/core/widgets/border_wait_time_card.dart';
import 'package:milow/core/widgets/shimmer_loading.dart';
import 'package:milow/core/models/border_wait_time.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/utils/address_utils.dart';
import 'package:milow/features/dashboard/presentation/pages/records_list_page.dart';
import 'package:milow/features/dashboard/presentation/pages/global_search_page.dart';
import 'package:milow/core/services/border_wait_time_service.dart';
import 'package:milow/core/services/trip_service.dart';
import 'package:milow/core/services/fuel_service.dart';
import 'package:milow/core/services/data_prefetch_service.dart';
import 'package:milow/core/services/notification_service.dart';
import 'package:milow/core/utils/responsive_layout.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  // Border wait times
  List<BorderWaitTime> _borderWaitTimes = [];
  bool _isLoadingBorders = true;
  String? _borderError;
  Timer? _borderRefreshTimer;

  // Recent entries (trips and fuel)
  List<Map<String, dynamic>> _recentEntries = [];
  bool _isLoadingEntries = true;

  // Notification state
  int _unreadNotificationCount = 0;
  StreamSubscription<int>? _notificationSubscription;
  StreamSubscription<ServiceNotificationItem>? _incomingSubscription;

  // Bell icon animation
  late AnimationController _bellAnimationController;
  late Animation<double> _bellScaleAnimation;

  // Dynamic Gradients
  late List<Color> _currentGradientColors;

  static const List<List<Color>> _gradientPalettes = [
    // Dark Red (Original)
    [Color(0xFF2E0213), Color(0xFF8B2C4B), Color(0xFFA66C44)],
    // Pistachio (Green)
    [
      Color(0xFF1A4D2E), // Deep forest green
      Color(0xFF4F6F52), // Sage green
      Color(0xFFE8DFCA), // Cream/Beige for warmth
    ],
    // Orange / Embers
    [
      Color(0xFF431407), // Dark burnt orange
      Color(0xFF9A3412), // Rust
      Color(0xFFF59E0B), // Vibrant amber
    ],
    // Dark Yellow / Gold
    [
      Color(0xFF422006), // Dark brown
      Color(0xFF854D0E), // Bronze
      Color(0xFFEAB308), // Gold
    ],
    // Midnight Blue
    [
      Color(0xFF0F172A), // Slate 900
      Color(0xFF1E3A8A), // Blue 900
      Color(0xFF3B82F6), // Blue 500
    ],
  ];

  @override
  void initState() {
    super.initState();

    // Initialize bell animation controller
    _bellAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Create scale animation (1.0 to 1.1)
    _bellScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _bellAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Pick a random gradient
    final random = Random();
    _currentGradientColors =
        _gradientPalettes[random.nextInt(_gradientPalettes.length)];

    _loadBorderWaitTimes(
      forceRefresh: false,
    ); // Use prefetched data if available
    _loadRecentEntries();
    _loadNotificationCount();

    // Refresh border wait times every 5 minutes
    _borderRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _loadBorderWaitTimes(forceRefresh: true),
    );
  }

  @override
  void dispose() {
    _borderRefreshTimer?.cancel();
    _notificationSubscription?.cancel();
    _incomingSubscription?.cancel();

    _bellAnimationController.dispose();
    super.dispose();
  }

  /// Pull-to-refresh handler - refreshes all dashboard data
  Future<void> _onRefresh() async {
    // Invalidate cache to force fresh data
    DataPrefetchService.instance.invalidateCache();

    // Refresh all data in parallel
    await Future.wait([
      _loadBorderWaitTimes(forceRefresh: true),
      _loadRecentEntries(),
    ]);
  }

  Future<void> _loadNotificationCount() async {
    await NotificationService.instance.init();
    _unreadNotificationCount = NotificationService.instance.unreadCount;
    _updateBellAnimation(_unreadNotificationCount);
    _notificationSubscription = NotificationService.instance.unreadCountStream
        .listen((count) {
          if (mounted) {
            setState(() {
              _unreadNotificationCount = count;
            });
            _updateBellAnimation(count);
            _updateBellAnimation(count);
          }
        });

    // Listen for incoming notifications to show Snackbar
    _incomingSubscription = NotificationService.instance.incomingStream.listen((
      notification,
    ) {
      // Suppress SnackBar for messages (only show badge)
      if (notification.type == NotificationType.message) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(_getIconForType(notification.type), color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        notification.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        notification.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1F2937),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: const Color(0xFF60A5FA),
              onPressed: () {
                context.push('/notifications');
              },
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
    if (mounted) {
      setState(() {});
    }
  }

  void _updateBellAnimation(int count) {
    if (count > 0) {
      // Start animation if not already running
      if (!_bellAnimationController.isAnimating) {
        _bellAnimationController.repeat(reverse: true);
      }
    } else {
      // Stop animation when no unread notifications
      _bellAnimationController.stop();
      _bellAnimationController.reset();
    }
  }

  Future<void> _loadBorderWaitTimes({bool forceRefresh = false}) async {
    final prefetch = DataPrefetchService.instance;

    // Try to use prefetched data first
    if (!forceRefresh &&
        prefetch.isPrefetchComplete &&
        prefetch.cachedBorderWaitTimes != null) {
      if (mounted) {
        setState(() {
          _borderWaitTimes = prefetch.cachedBorderWaitTimes!;
          _isLoadingBorders = false;
          _borderError = null;
        });
      }
      return;
    }

    if (forceRefresh) {
      setState(() {
        _isLoadingBorders = true;
        _borderError = null;
      });
    }
    try {
      // Force refresh the API data first if requested
      if (forceRefresh) {
        await BorderWaitTimeService.fetchAllWaitTimes(forceRefresh: true);
      }
      final waitTimes = await BorderWaitTimeService.getSavedBorderWaitTimes();
      if (mounted) {
        setState(() {
          _borderWaitTimes = waitTimes;
          _isLoadingBorders = false;
          _borderError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBorders = false;
          _borderError = _getErrorMessage(e);
        });
      }
    }
  }

  Future<void> _loadRecentEntries() async {
    try {
      final prefetch = DataPrefetchService.instance;
      List<Trip> trips;
      List<FuelEntry> fuelEntries;

      // Use prefetched data if available, otherwise fetch
      if (prefetch.isPrefetchComplete &&
          prefetch.cachedTrips != null &&
          prefetch.cachedFuelEntries != null) {
        // Take first 5 from cached data
        trips = prefetch.cachedTrips!.take(5).toList();
        fuelEntries = prefetch.cachedFuelEntries!.take(5).toList();
      } else {
        trips = await TripService.getTrips(limit: 5);
        fuelEntries = await FuelService.getFuelEntries(limit: 5);
      }

      // Combine and sort by date
      final List<Map<String, dynamic>> combined = [];

      for (final trip in trips) {
        combined.add({'type': 'trip', 'data': trip, 'date': trip.tripDate});
      }

      for (final fuel in fuelEntries) {
        combined.add({'type': 'fuel', 'data': fuel, 'date': fuel.fuelDate});
      }

      // Sort by date descending
      combined.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
      );

      // Take only first 5
      final recent = combined.take(5).toList();

      if (mounted) {
        setState(() {
          _recentEntries = List<Map<String, dynamic>>.from(recent);
          _isLoadingEntries = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingEntries = false;
        });
      }
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('socketexception') ||
        errorStr.contains('connection') ||
        errorStr.contains('network')) {
      return 'No internet connection';
    } else if (errorStr.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (errorStr.contains('permission') || errorStr.contains('denied')) {
      return 'Permission denied';
    } else if (errorStr.contains('404')) {
      return 'Data not available';
    } else if (errorStr.contains('500') || errorStr.contains('server')) {
      return 'Server error. Please try again later.';
    }
    return 'Something went wrong. Please try again.';
  }

  Widget _buildHeroSection(BuildContext context, double margin) {
    // Base background color to fade into
    final baseColor = Theme.of(context).scaffoldBackgroundColor;

    return Stack(
      children: [
        // Extended Gradient Background with Fade
        Container(
          height: 540,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _currentGradientColors,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 0.8, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.1),
                  Colors.black.withValues(alpha: 0.3),
                  baseColor.withValues(alpha: 0.8),
                  baseColor,
                ],
              ),
            ),
          ),
        ),

        // Combined Content
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Content (Veo 3)
            SizedBox(
              height: 380,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: margin, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Track Your Journey',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Log fuel, mileage, and border crossings effortlessly.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.push('/add-entry'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: Text(
                        'Start New Entry',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Page Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildPageIndicator(true),
                        const SizedBox(width: 8),
                        _buildPageIndicator(false),
                        const SizedBox(width: 8),
                        _buildPageIndicator(false),
                        const SizedBox(width: 8),
                        _buildPageIndicator(false),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Get Started Section
            Padding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              child: Text(
                'Get started',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: margin),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGetStartedCard(
                    context,
                    'Add Data',
                    Icons.add,
                    () => context.push('/add-entry'),
                  ),
                  const SizedBox(width: 12),
                  _buildGetStartedCard(
                    context,
                    'Explore',
                    Icons.explore_outlined,
                    () => context.go('/explore'),
                  ),
                  const SizedBox(width: 12),
                  _buildGetStartedCard(
                    context,
                    'Inbox',
                    Icons.inbox_outlined,
                    () => context.go('/inbox'),
                  ),
                  const SizedBox(width: 12),
                  _buildGetStartedCard(
                    context,
                    'Settings',
                    Icons.settings_outlined,
                    () => context.go('/settings'),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Header Icons Overlay
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: margin, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GlobalSearchPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.search),
                    style: IconButton.styleFrom(foregroundColor: Colors.white),
                  ),
                  const Spacer(),
                  _buildNotificationBell(context),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator(bool isActive) {
    return Container(
      width: isActive ? 16 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3),
        shape: BoxShape.rectangle,
      ),
    );
  }

  Widget _buildGetStartedCard(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Center(
                child: Icon(
                  icon,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _bellAnimationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _bellScaleAnimation.value,
              child: IconButton(
                onPressed: () => context.push('/notifications'),
                icon: const Icon(Icons.notifications_outlined),
                style: IconButton.styleFrom(foregroundColor: Colors.white),
              ),
            );
          },
        ),
        if (_unreadNotificationCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final margin = ResponsiveLayout.getMargin(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1a1a2e),
                  const Color(0xFF16213e),
                  const Color(0xFF0f0f23),
                ]
              : [Colors.white, const Color(0xFFF5F5F5), Colors.white],
        ),
      ),
      child: Shimmer(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          displacement: 60,
          strokeWidth: 3.0,
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroSection(context, margin),

                Container(
                  transform: Matrix4.translationValues(0, -32, 0),
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(
                    children: [
                      // Border Wait Times Section
                      if (_isLoadingBorders) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: margin),
                          child: const ShimmerLoading(
                            isLoading: true,
                            child: Column(
                              children: [
                                ShimmerBorderWaitCard(),
                                ShimmerBorderWaitCard(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else if (_borderError != null &&
                          _borderWaitTimes.isEmpty) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: margin),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.error_outline,
                                    color: Color(0xFFDC2626),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Border Wait Times Unavailable',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _borderError!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _loadBorderWaitTimes(forceRefresh: true),
                                  child: Text(
                                    'Retry',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else if (_borderWaitTimes.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: margin),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Border Wait Times',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    _loadBorderWaitTimes(forceRefresh: true),
                                icon: Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                label: Text(
                                  'Refresh',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: margin),
                          child: Column(
                            children: _borderWaitTimes
                                .map((bwt) => BorderWaitTimeCard(waitTime: bwt))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Last Record Entries
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: margin),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Last Record Entries',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _isLoadingEntries
                                ? const ShimmerLoading(
                                    isLoading: true,
                                    child: Column(
                                      children: [
                                        ShimmerEntryItem(),
                                        ShimmerEntryItem(),
                                        ShimmerEntryItem(),
                                        ShimmerEntryItem(showDivider: false),
                                      ],
                                    ),
                                  )
                                : _recentEntries.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.inbox_outlined,
                                            size: 48,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.outline,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No entries yet',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Add your first trip or fuel entry',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant
                                                      .withValues(alpha: 0.7),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : Card(
                                    elevation: 0,
                                    margin: EdgeInsets.zero,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.black
                                        : const Color(0xFFF5F5F5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      side: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        ..._recentEntries.asMap().entries.map((
                                          entry,
                                        ) {
                                          final item = entry.value;
                                          final isTrip = item['type'] == 'trip';

                                          Widget entryWidget;
                                          if (isTrip) {
                                            final trip = item['data'] as Trip;
                                            final pickups =
                                                trip.pickupLocations;
                                            final deliveries =
                                                trip.deliveryLocations;
                                            final route =
                                                pickups.isNotEmpty &&
                                                    deliveries.isNotEmpty
                                                ? '${AddressUtils.extractCityState(pickups.first)} -> ${AddressUtils.extractCityState(deliveries.last)}'
                                                : 'No route';
                                            final distance = trip.totalDistance;
                                            final distanceStr = distance != null
                                                ? '${distance.toStringAsFixed(0)} ${trip.distanceUnitLabel}'
                                                : '-';

                                            entryWidget = _buildRecordEntry(
                                              'trip',
                                              'Trip #${trip.tripNumber}',
                                              route,
                                              DateFormat(
                                                'MMM d, yyyy',
                                              ).format(trip.tripDate),
                                              distanceStr,
                                            );
                                          } else {
                                            final fuel =
                                                item['data'] as FuelEntry;
                                            final location =
                                                fuel.location != null
                                                ? AddressUtils.extractCityState(
                                                    fuel.location!,
                                                  )
                                                : 'Unknown location';
                                            final quantity =
                                                '${fuel.fuelQuantity.toStringAsFixed(1)} ${fuel.fuelUnitLabel}';
                                            final identifier = fuel.isTruckFuel
                                                ? fuel.truckNumber ?? 'Truck'
                                                : fuel.reeferNumber ?? 'Reefer';

                                            entryWidget = _buildRecordEntry(
                                              'fuel',
                                              '${fuel.isTruckFuel ? "Truck" : "Reefer"} - $identifier',
                                              location,
                                              DateFormat(
                                                'MMM d, yyyy',
                                              ).format(fuel.fuelDate),
                                              quantity,
                                            );
                                          }
                                          return Column(
                                            children: [
                                              entryWidget,
                                              Divider(
                                                height: 1,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.outlineVariant,
                                              ),
                                            ],
                                          );
                                        }),
                                        // View All Button
                                        InkWell(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const RecordsListPage(),
                                              ),
                                            );
                                          },
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(24),
                                            bottomRight: Radius.circular(24),
                                          ),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              'View All Entries',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      const SectionHeader(title: 'Learning Pages'),
                      const SizedBox(height: 12),
                      Card(
                        margin: EdgeInsets.symmetric(horizontal: margin),
                        elevation: 0,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black
                            : const Color(0xFFF5F5F5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 24,
                            horizontal: 16,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.school_outlined,
                                size: 32,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Learning Resources Coming Soon',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'We are working on great educational content for you.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Extra padding for floating bottom nav bar
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordEntry(
    String type,
    String entryId,
    String description,
    String date,
    String value,
  ) {
    final isTrip = type == 'trip';
    final iconColor = isTrip
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.tertiary;
    final icon = isTrip ? Icons.local_shipping : Icons.local_gas_station;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                // Top row: Entry ID left, Value right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entryId,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Bottom row: Description left, Date right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      date,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.reminder:
        return Icons.notification_important;
      case NotificationType.company:
        return Icons.business;
      case NotificationType.news:
        return Icons.newspaper;
      case NotificationType.message:
        return Icons.chat_bubble_outline;
    }
  }
}
