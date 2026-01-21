import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

// TabsShell provides navigation; this page returns content only
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/preferences_service.dart';

import 'package:milow/core/services/profile_provider.dart';
import 'package:milow/core/widgets/border_wait_time_card.dart';
import 'package:milow/core/widgets/m3_spring_button.dart';
import 'package:milow/core/widgets/shimmer_loading.dart';
import 'package:milow/core/models/border_wait_time.dart';
import 'package:milow/core/models/recent_entry.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/theme/m3_expressive_motion.dart';
import 'package:milow/core/utils/address_utils.dart';
import 'package:milow/features/dashboard/presentation/pages/global_search_page.dart';
import 'package:milow/core/services/border_wait_time_service.dart';

import 'package:milow/core/services/data_prefetch_service.dart';
import 'package:milow/core/services/notification_service.dart';
import 'package:milow/core/utils/responsive_layout.dart';
import 'package:milow/features/dashboard/presentation/widgets/active_trip_card.dart';
import 'package:milow/core/widgets/sync_status_indicator.dart';
import 'package:milow/core/services/trip_repository.dart';
import 'package:milow/core/services/fuel_repository.dart';
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

  // Recent entries (trips and fuel) - typed for safety
  List<RecentEntry> _recentEntries = [];
  bool _isLoadingEntries = true;

  // Active trip (trip without end odometer)
  Trip? _activeTrip;

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
    // Deep Ocean Blue
    [
      Color(0xFF172554), // Blue 950
      Color(0xFF2563EB), // Blue 600
      Color(0xFF60A5FA), // Blue 400
    ],
    // Sunset Coral
    [
      Color(0xFF7C2D12), // Orange 900
      Color(0xFFEA580C), // Orange 600
      Color(0xFFFDBA74), // Orange 300
    ],
    // Pistachio Green
    [
      Color(0xFF14532D), // Green 900
      Color(0xFF16A34A), // Green 600
      Color(0xFF86EFAC), // Green 300
    ],
    [
      Color(0xFF78350F), // Amber 900
      Color(0xFFD97706), // Amber 600
      Color(0xFFFCD34D), // Amber 300
    ],
    [
      Color(0xFF134E4A), // Teal 900
      Color(0xFF0D9488), // Teal 600
      Color(0xFF5EEAD4), // Teal 300
    ],
    [
      Color(0xFF431407), // Orange 950
      Color(0xFFF97316), // Orange 500
      Color(0xFFFED7AA), // Orange 200
    ],
    // Mint Fresh
    [
      Color(0xFF064E3B), // Emerald 900
      Color(0xFF10B981), // Emerald 500
      Color(0xFFA7F3D0), // Emerald 200
    ],
  ];

  @override
  void initState() {
    super.initState();

    // Initialize bell animation controller
    _bellAnimationController = AnimationController(
      duration: M3ExpressiveMotion.durationLong,
      vsync: this,
    );

    // Create scale animation (1.0 to 1.1)
    _bellScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _bellAnimationController,
        curve: M3ExpressiveMotion.emphasized,
      ),
    );

    // Lock to Royal Purple (Index 3) for design consistency
    _currentGradientColors = _gradientPalettes[3];

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
                SizedBox(width: context.tokens.spacingS),
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
            backgroundColor: Theme.of(context).colorScheme.inverseSurface,
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Theme.of(context).colorScheme.inversePrimary,
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
      // Load active trip (trip without end odometer)
      // final activeTrip = await TripRepository.getActiveTrip();

      final prefetch = DataPrefetchService.instance;
      List<Trip> trips;
      List<FuelEntry> fuelEntries;

      // Use prefetched data if available, otherwise fetch
      if (prefetch.isPrefetchComplete &&
          prefetch.cachedTrips != null &&
          prefetch.cachedFuelEntries != null) {
        // Take first 5 from cached data
        trips = prefetch.cachedTrips!.take(10).toList();
        fuelEntries = prefetch.cachedFuelEntries!.take(5).toList();
      } else {
        // Fetch from repositories (offline-first)
        // Note: Repositories return all items sorted by date
        final allTrips = await TripRepository.getTrips(refresh: true);
        final allFuel = await FuelRepository.getFuelEntries(refresh: true);

        trips = allTrips.take(10).toList();
        fuelEntries = allFuel.take(5).toList();
      }

      // Filter out hidden trips
      final hiddenTripIds = await PreferencesService.getHiddenTripIds();

      // Determine active trip manually to support "Next Active" and filtering
      // An active trip is one without an end odometer.
      // We prioritize the most recent one that isn't hidden.
      Trip? computedActiveTrip;

      try {
        computedActiveTrip = trips.firstWhere((t) {
          final isHidden = t.id != null && hiddenTripIds.contains(t.id);
          if (isHidden) return false;

          // Active logic: incomplete end odometer AND incomplete deliveries
          // If all deliveries are done, it's no longer "active" on the dashboard
          return t.endOdometer == null && !t.allDeliveriesCompleted;
        });
      } catch (_) {
        computedActiveTrip = null;
      }

      // Combine and sort by date using typed RecentEntry
      final List<RecentEntry> combined = [
        ...trips.map((trip) => TripRecentEntry(trip)),
        ...fuelEntries.map((fuel) => FuelRecentEntry(fuel)),
      ];

      // Sort by date descending
      combined.sort((a, b) => b.date.compareTo(a.date));

      // Take only first 5
      final recent = combined.take(5).toList();

      if (mounted) {
        setState(() {
          _activeTrip = computedActiveTrip;
          _recentEntries = recent;
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

  Widget _buildHeroContent(BuildContext context, double margin) {
    // ENTERPRISE PATTERN: Capture nullable state in local final variable
    final activeTrip = _activeTrip;
    final bool showStartTrip =
        activeTrip == null || activeTrip.allDeliveriesCompleted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Content
        Padding(
          padding: EdgeInsets.fromLTRB(margin, 4, margin, 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Show 'Start Trip' if no active trip OR active trip is completed
              if (showStartTrip) ...[
                Text(
                  'Track Your Journey',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: context.tokens.spacingM),
                // Hero Search Pill -> Replaced with "Start Trip" Button
                SizedBox(
                  width: double.infinity,
                  height: 56, // Tall button for easy tapping
                  child: FilledButton.icon(
                    onPressed: () async {
                      final result = await context.push('/add-entry');
                      if (result == true) {
                        unawaited(_onRefresh());
                      }
                    },
                    icon: Icon(
                      Icons.add,
                      color: Theme.of(context).colorScheme.primary,
                      // Using primary color for icon on white/surface button
                    ),
                    label: Text(
                      'Start Trip',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white, // White against gradient
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          context.tokens.shapeFull,
                        ),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                SizedBox(height: context.tokens.spacingL),
              ],
              // Only show active trip card if trip exists AND deliveries are pending
              if (activeTrip != null && !activeTrip.allDeliveriesCompleted)
                GestureDetector(
                  onLongPressStart: (details) {
                    _showActivityMenu(
                      context,
                      activeTrip,
                      details.globalPosition,
                    );
                  },
                  child: ActiveTripCard(
                    trip: activeTrip,
                    onComplete: () async {
                      final result = await context.push(
                        '/add-entry',
                        extra: {'editingTrip': activeTrip},
                      );
                      if (result == true) {
                        unawaited(_onRefresh());
                      }
                    },
                  ),
                )
              else
                // No active trip or trip is complete - show "Track Your Journey" + Pill
                const SizedBox.shrink(),
              SizedBox(height: context.tokens.spacingL),
            ],
          ),
        ),

        // Get Started Section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: margin),
          child: Text(
            'Get started',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        SizedBox(height: context.tokens.spacingM),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: margin),
          child: M3StaggeredList(
            direction: Axis.horizontal,
            spacing: context.tokens.spacingM,
            children: [
              _buildGetStartedCard(context, 'Add Data', Icons.add, () async {
                final result = await context.push('/add-entry');
                if (result == true) {
                  unawaited(_onRefresh());
                }
              }),
              _buildGetStartedCard(
                context,
                'Explore',
                Icons.explore_outlined,
                () => context.go('/explore'),
              ),
              if (context.watch<ProfileProvider>().isConnectedToCompany)
                _buildGetStartedCard(
                  context,
                  'Inbox',
                  Icons.inbox_outlined,
                  () => context.go('/inbox'),
                ),
              _buildGetStartedCard(
                context,
                'Scan Documents',
                Icons.document_scanner_outlined,
                () async {
                  await context.push(
                    '/scan-document',
                    extra: {
                      if (activeTrip != null) 'tripId': activeTrip.id,
                      if (activeTrip != null)
                        'tripNumber': activeTrip.tripNumber,
                    },
                  );
                },
              ),
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
        M3SpringButton(
          onTap: onTap,
          child: SizedBox(
            width: 72, // Slightly smaller to look refined
            height: 72,
            child: Card(
              elevation: 0,
              // Use a proper surface color that adapts to light/dark mode
              // surfaceContainerHigh works well on top of background gradients/colors
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.tokens.shapeL),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 28,
                  // Use onSurfaceVariant for the icon to match the container
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: context.tokens.spacingS),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              // Use onSurface for text legibility against any background (since it's outside the card)
              // But wait, the text is ON THE GRADIENT background.
              // If the background is light, white text is bad.
              // If the background is dark, black text is bad.
              // The text is separate from the card.
              // Check the screenshot. The text is below the buttons on the gradient background.
              // The gradient seems to change based on `_currentGradientColors`.
              // `_currentGradientColors` defaults to `_gradientPalettes[3]` (Amber/Orange).
              // Text on Amber needs to be dark (or specifically handled).
              // However, typically in M3, if we have a qualified background, we should probably check if we want
              // to force a specific color or let it adapt.
              // The user's compliant is "not seeing while light mode".
              // If I change the text to `onSurface`, it will be Black in Light Mode (good for Amber background)
              // and White in Dark Mode (good for Dark background).
              // This relies on the Scaffold background being transparent or ignored if on gradient?
              // `DashboardPage` has a Stack with Gradient Background.
              // And the text is printed on top of that Gradient.
              // The Gradient colors are fixed in `_gradientPalettes`.
              // If we are in Light Mode, `colorScheme.onSurface` is usually dark (black/grey).
              // Dark text on Amber gradient = Visible.
              // If we are in Dark Mode, `colorScheme.onSurface` is light (white/grey).
              // Light Text on Dark Blue gradient = Visible.
              // So `onSurface` should be correct, UNLESS the gradient doesn't match the theme brightness.
              // But let's assume standard theme behavior.
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
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
              padding: EdgeInsets.all(context.tokens.spacingXS),
              decoration: BoxDecoration(
                color: context.tokens.error,
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
    final margin = ResponsiveLayout.getMargin(context);
    final baseColor = Theme.of(context).scaffoldBackgroundColor;

    return Container(
      color: baseColor,
      child: Shimmer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient Background (Fixed height behind content)

            // Scrollable Content
            Positioned.fill(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                displacement: 60,
                strokeWidth: 3.0,
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHigh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Gradient Section (Hero + Border Wait Times)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [..._currentGradientColors, baseColor],
                            stops: const [0.0, 0.33, 0.65, 1.0],
                          ),
                        ),
                        child: Column(
                          children: [
                            // Header Icons Row (scrolls with content)
                            SafeArea(
                              bottom: false,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: margin,
                                  right: margin,
                                  bottom: 8,
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const GlobalSearchPage(),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.search),
                                      style: IconButton.styleFrom(
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                    const Spacer(),
                                    const SyncStatusIndicator(),
                                    SizedBox(width: context.tokens.spacingS),
                                    _buildNotificationBell(context),
                                  ],
                                ),
                              ),
                            ),
                            _buildHeroContent(context, margin),

                            // Border Wait Times Section
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.only(
                                top: 12,
                                bottom: 12,
                              ),
                              child: Column(
                                children: [
                                  // Border Wait Times Section
                                  if (_isLoadingBorders ||
                                      _borderError != null ||
                                      _borderWaitTimes.isNotEmpty) ...[
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: margin,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Border Wait Times',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          TextButton.icon(
                                            onPressed: () =>
                                                _loadBorderWaitTimes(
                                                  forceRefresh: true,
                                                ),
                                            icon: Icon(
                                              Icons.refresh_rounded,
                                              size: 16,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                            label: Text(
                                              'Refresh',
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
                                    SizedBox(height: context.tokens.spacingM),
                                    if (_isLoadingBorders) ...[
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: margin,
                                        ),
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
                                      SizedBox(height: context.tokens.spacingM),
                                    ] else if (_borderError != null &&
                                        _borderWaitTimes.isEmpty) ...[
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: margin,
                                        ),
                                        child: Container(
                                          padding: EdgeInsets.all(
                                            context.tokens.spacingM,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.surfaceContainer,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.outlineVariant,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.errorContainer,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        context.tokens.shapeS,
                                                      ),
                                                ),
                                                child: Icon(
                                                  Icons.error_outline,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.error,
                                                  size: 20,
                                                ),
                                              ),
                                              SizedBox(
                                                width: context.tokens.spacingS,
                                              ),
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
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                    ),
                                                    SizedBox(
                                                      height: context
                                                          .tokens
                                                          .spacingXS,
                                                    ),
                                                    Text(
                                                      _borderError!,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    _loadBorderWaitTimes(
                                                      forceRefresh: true,
                                                    ),
                                                child: Text(
                                                  'Retry',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelLarge
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
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
                                      SizedBox(height: context.tokens.spacingM),
                                    ] else if (_borderWaitTimes.isNotEmpty) ...[
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: margin,
                                        ),
                                        child: Column(
                                          children: _borderWaitTimes
                                              .map(
                                                (bwt) => BorderWaitTimeCard(
                                                  waitTime: bwt,
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                      SizedBox(height: context.tokens.spacingM),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
                            SizedBox(height: context.tokens.spacingM),
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
                                    padding: EdgeInsets.all(
                                      context.tokens.spacingXL,
                                    ),
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
                                          SizedBox(
                                            height: context.tokens.spacingM,
                                          ),
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
                                          SizedBox(
                                            height: context.tokens.spacingXS,
                                          ),
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerLow,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        context.tokens.shapeL,
                                      ),
                                      side: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: M3StaggeredList(
                                      children: [
                                        ..._recentEntries.asMap().entries.map((
                                          entry,
                                        ) {
                                          final item = entry.value;

                                          // Build widget and get navigation route
                                          final (
                                            Widget entryWidget,
                                            VoidCallback onTap,
                                            void Function(Offset)? onLongPress,
                                          ) = switch (item) {
                                            TripRecentEntry(:final trip) => () {
                                              final pickups =
                                                  trip.pickupLocations;
                                              final deliveries =
                                                  trip.deliveryLocations;
                                              final route =
                                                  pickups.isNotEmpty &&
                                                      deliveries.isNotEmpty
                                                  ? '${AddressUtils.extractCityState(pickups.first)} -> ${AddressUtils.extractCityState(deliveries.last)}'
                                                  : 'No route';
                                              final distance =
                                                  trip.totalDistance;
                                              final distanceStr =
                                                  distance != null
                                                  ? '${distance.toStringAsFixed(0)} ${trip.distanceUnitLabel}'
                                                  : '-';

                                              return (
                                                _buildRecordEntry(
                                                  'trip',
                                                  'Trip #${trip.tripNumber}',
                                                  route,
                                                  DateFormat(
                                                    'MMM d, yyyy',
                                                  ).format(trip.tripDate),
                                                  distanceStr,
                                                ),
                                                () async {
                                                  final result = await context
                                                      .push(
                                                        '/add-entry',
                                                        extra: {
                                                          'editingTrip': trip,
                                                        },
                                                      );
                                                  if (result == true) {
                                                    unawaited(_onRefresh());
                                                  }
                                                },
                                                (Offset position) {
                                                  _showEntryOptions(
                                                    context,
                                                    trip,
                                                    position,
                                                  );
                                                },
                                              );
                                            }(),
                                            FuelRecentEntry(:final fuel) => () {
                                              final location =
                                                  fuel.location != null
                                                  ? AddressUtils.extractCityState(
                                                      fuel.location!,
                                                    )
                                                  : 'Unknown location';
                                              final quantity =
                                                  '${fuel.fuelQuantity.toStringAsFixed(1)} ${fuel.fuelUnitLabel}';
                                              final identifier =
                                                  fuel.isTruckFuel
                                                  ? fuel.truckNumber ?? 'Truck'
                                                  : fuel.reeferNumber ??
                                                        'Reefer';

                                              return (
                                                _buildRecordEntry(
                                                  'fuel',
                                                  '${fuel.isTruckFuel ? "Truck" : "Reefer"} - $identifier',
                                                  location,
                                                  DateFormat(
                                                    'MMM d, yyyy',
                                                  ).format(fuel.fuelDate),
                                                  quantity,
                                                ),
                                                () async {
                                                  final result = await context
                                                      .push(
                                                        '/add-entry',
                                                        extra: {
                                                          'editingFuel': fuel,
                                                        },
                                                      );
                                                  if (result == true) {
                                                    unawaited(_onRefresh());
                                                  }
                                                },
                                                null,
                                              );
                                            }(),
                                          };

                                          return Column(
                                            children: [
                                              InkWell(
                                                onTap: onTap,
                                                onLongPress: onLongPress != null
                                                    ? () {
                                                        // Fallback if GestureDetector doesn't catch it or for a11y
                                                      }
                                                    : null,
                                                child: GestureDetector(
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  onLongPressStart:
                                                      onLongPress != null
                                                      ? (
                                                          details,
                                                        ) => onLongPress(
                                                          details
                                                              .globalPosition,
                                                        )
                                                      : null,
                                                  child: entryWidget,
                                                ),
                                              ),
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
                                        M3SpringButton(
                                          onTap: () => context.push('/records'),
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
                      SizedBox(height: context.tokens.spacingL),

                      // Dynamic bottom padding for system navigation bar
                      SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Header icons now scroll with content (see gradient Column above)
          ],
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
      padding: EdgeInsets.symmetric(
        horizontal: context.tokens.spacingM,
        vertical: context.tokens.spacingM,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(context.tokens.shapeM),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          SizedBox(width: context.tokens.spacingS),
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
                SizedBox(height: context.tokens.spacingXS),
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
                    SizedBox(width: context.tokens.spacingS),
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

  void _showActivityMenu(BuildContext context, Trip trip, Offset position) {
    final tokens = Theme.of(context).extension<DesignTokens>()!;
    // Show pickup menu if there are incomplete pickups, otherwise show delivery menu
    final hasIncompletePickups = !trip.allPickupsCompleted;
    final items = <PopupMenuEntry<String>>[];

    if (hasIncompletePickups) {
      items.addAll([
        _buildMenuItem(
          'Mark load picked up',
          Icons.check_circle_outline,
          'picked_up',
        ),
        _buildMenuItem(
          'Open in Maps',
          Icons.navigation_outlined,
          'navigate_pickup',
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          'Add Document (POD)',
          Icons.assignment_turned_in_outlined,
          'add_pod',
        ),
      ]);
    } else {
      items.addAll([
        _buildMenuItem('Mark load delivered', Icons.done_all, 'delivered'),
        _buildMenuItem(
          'Open in Maps',
          Icons.navigation_outlined,
          'navigate_delivery',
        ),
        _buildMenuItem('Complete trip', Icons.flag_outlined, 'complete_trip'),
        const PopupMenuDivider(),
        _buildMenuItem(
          'Add Document (POD)',
          Icons.assignment_turned_in_outlined,
          'add_pod',
        ),
      ]);
    }

    // Add generic options
    items.addAll([
      const PopupMenuDivider(),
      _buildMenuItem(
        'Hide Activity Bar',
        Icons.visibility_off_outlined,
        'hide_activity_bar',
      ),
    ]);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: items,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.shapeM),
      ),
      elevation: tokens.elevationLevel2,
      color: tokens.surfaceContainer,
      surfaceTintColor: Colors.transparent, // Clean look
    ).then((value) {
      if (value != null) {
        _handleMenuAction(value);
      }
    });
  }

  void _showEntryOptions(BuildContext context, Trip trip, Offset position) {
    final tokens = Theme.of(context).extension<DesignTokens>()!;
    final items = <PopupMenuEntry<String>>[
      _buildMenuItem('Edit Trip', Icons.edit_outlined, 'edit'),
      const PopupMenuDivider(),
      _buildMenuItem(
        'Add Document (BOL)',
        Icons.description_outlined,
        'add_bol',
      ),
      _buildMenuItem(
        'Add Document (POD)',
        Icons.assignment_turned_in_outlined,
        'add_pod',
      ),
    ];

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: items,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.shapeM),
      ),
      elevation: tokens.elevationLevel2,
      color: tokens.surfaceContainer,
      surfaceTintColor: Colors.transparent,
    ).then((value) {
      if (value != null) {
        _handleEntryAction(value, trip);
      }
    });
  }

  Future<void> _handleEntryAction(String value, Trip trip) async {
    switch (value) {
      case 'edit':
        final result = await context.push(
          '/add-entry',
          extra: {'editingTrip': trip},
        );
        if (result == true) {
          unawaited(_onRefresh());
        }
        break;
      case 'add_bol':
        await context.push(
          '/scan-document',
          extra: {
            'tripId': trip.id,
            'tripNumber': trip.tripNumber,
            'initialDocumentType': 'bol',
          },
        );
        break;
      case 'add_pod':
        await context.push(
          '/scan-document',
          extra: {
            'tripId': trip.id,
            'tripNumber': trip.tripNumber,
            'initialDocumentType': 'pod',
          },
        );
        break;
    }
  }

  PopupMenuItem<String> _buildMenuItem(
    String label,
    IconData icon,
    String value,
  ) {
    final tokens = Theme.of(context).extension<DesignTokens>()!;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: tokens.textSecondary, size: 24),
          SizedBox(width: context.tokens.spacingS),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Mark the next incomplete pickup as complete with current timestamp
  Future<void> _markPickupComplete(Trip trip) async {
    if (trip.pickupLocations.isEmpty) return;

    // Find the first incomplete pickup index
    int pickupIndex = -1;
    for (int i = 0; i < trip.pickupLocations.length; i++) {
      final isCompleted = i < trip.pickupCompleted.length
          ? trip.pickupCompleted[i]
          : false;
      if (!isCompleted) {
        pickupIndex = i;
        break;
      }
    }

    if (pickupIndex == -1) {
      // All pickups already completed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All pickups already completed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Build new lists with updated values
    final newPickupTimes = List<DateTime?>.from(trip.pickupTimes);
    final newPickupCompleted = List<bool>.from(trip.pickupCompleted);

    // Ensure lists are long enough
    while (newPickupTimes.length <= pickupIndex) {
      newPickupTimes.add(null);
    }
    while (newPickupCompleted.length <= pickupIndex) {
      newPickupCompleted.add(false);
    }

    // Set current time and mark complete
    newPickupTimes[pickupIndex] = DateTime.now();
    newPickupCompleted[pickupIndex] = true;

    // Create updated trip
    final updatedTrip = trip.copyWith(
      pickupTimes: newPickupTimes,
      pickupCompleted: newPickupCompleted,
    );

    try {
      // Update database
      await TripRepository.updateTrip(updatedTrip);

      if (mounted) {
        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pickup ${pickupIndex + 1} of ${trip.pickupLocations.length} marked complete',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: context.tokens.success,
          ),
        );

        // Refresh dashboard to show updated state
        unawaited(_onRefresh());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update pickup: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: context.tokens.error,
          ),
        );
      }
    }
  }

  /// Mark the next incomplete delivery as complete with current timestamp
  Future<void> _markDeliveryComplete(Trip trip) async {
    if (trip.deliveryLocations.isEmpty) return;

    // Find the first incomplete delivery index
    int deliveryIndex = -1;
    for (int i = 0; i < trip.deliveryLocations.length; i++) {
      final isCompleted = i < trip.deliveryCompleted.length
          ? trip.deliveryCompleted[i]
          : false;
      if (!isCompleted) {
        deliveryIndex = i;
        break;
      }
    }

    if (deliveryIndex == -1) {
      // All deliveries already completed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All deliveries already completed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Build new lists with updated values
    final newDeliveryTimes = List<DateTime?>.from(trip.deliveryTimes);
    final newDeliveryCompleted = List<bool>.from(trip.deliveryCompleted);

    // Ensure lists are long enough
    while (newDeliveryTimes.length <= deliveryIndex) {
      newDeliveryTimes.add(null);
    }
    while (newDeliveryCompleted.length <= deliveryIndex) {
      newDeliveryCompleted.add(false);
    }

    // Set current time and mark complete
    newDeliveryTimes[deliveryIndex] = DateTime.now();
    newDeliveryCompleted[deliveryIndex] = true;

    // Create updated trip
    final updatedTrip = trip.copyWith(
      deliveryTimes: newDeliveryTimes,
      deliveryCompleted: newDeliveryCompleted,
    );

    try {
      // Update database
      await TripRepository.updateTrip(updatedTrip);

      if (mounted) {
        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Delivery ${deliveryIndex + 1} of ${trip.deliveryLocations.length} marked complete',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: context.tokens.success,
          ),
        );

        // Refresh dashboard to show updated state
        unawaited(_onRefresh());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update delivery: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: context.tokens.error,
          ),
        );
      }
    }
  }

  Future<void> _handleMenuAction(String value) async {
    final trip = _activeTrip;
    if (trip == null) return;

    if (value == 'hide_activity_bar') {
      if (_activeTrip!.id != null) {
        await PreferencesService.addHiddenTripId(_activeTrip!.id!);
        // Refresh to apply filter
        unawaited(_loadRecentEntries());
      }
      return;
    }

    switch (value) {
      case 'picked_up':
        await _markPickupComplete(trip);
        break;

      case 'delivered':
        await _markDeliveryComplete(trip);
        break;

      case 'navigate_pickup':
      case 'navigate_delivery':
        // Open maps with destination
        final destination = value == 'navigate_pickup'
            ? (trip.pickupLocations.isNotEmpty
                  ? trip.pickupLocations.first
                  : null)
            : (trip.deliveryLocations.isNotEmpty
                  ? trip.deliveryLocations.first
                  : null);

        if (destination != null) {
          if (Platform.isAndroid) {
            final encoded = Uri.encodeComponent(destination);
            final uri = Uri.parse('geo:0,0?q=$encoded');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            } else {
              final webUri = Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=$encoded',
              );
              await launchUrl(webUri, mode: LaunchMode.externalApplication);
            }
          } else if (Platform.isIOS) {
            await _showMapSelectionSheet(context, destination);
          } else {
            final encoded = Uri.encodeComponent(destination);
            final webUri = Uri.parse(
              'https://www.google.com/maps/search/?api=1&query=$encoded',
            );
            await launchUrl(webUri, mode: LaunchMode.externalApplication);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No destination address available'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
        break;

      case 'complete_trip':
        final result = await context.push(
          '/add-entry',
          extra: {'editingTrip': trip},
        );
        if (result == true) {
          unawaited(_onRefresh());
        }
        break;

      case 'add_bol':
        await context.push(
          '/scan-document',
          extra: {
            'tripId': trip.id,
            'tripNumber': trip.tripNumber,
            'initialDocumentType': 'bol',
          },
        );
        break;

      case 'add_pod':
        await context.push(
          '/scan-document',
          extra: {
            'tripId': trip.id,
            'tripNumber': trip.tripNumber,
            'initialDocumentType': 'pod',
          },
        );
        break;
    }
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

  Future<void> _showMapSelectionSheet(
    BuildContext context,
    String address,
  ) async {
    final encoded = Uri.encodeComponent(address);
    // Navigation Intents
    final appleUrl = Uri.parse('http://maps.apple.com/?daddr=$encoded');
    final googleUrl = Uri.parse(
      'comgooglemaps://?daddr=$encoded&directionsmode=driving',
    );
    final wazeUrl = Uri.parse('waze://?q=$encoded&navigate=yes');

    final tokens = Theme.of(context).extension<DesignTokens>()!;

    await showModalBottomSheet(
      context: context,
      backgroundColor: tokens.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: context.tokens.spacingS),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Open in Maps',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map, color: Colors.blue),
              title: const Text('Apple Maps'),
              onTap: () async {
                Navigator.pop(ctx);
                await launchUrl(appleUrl, mode: LaunchMode.externalApplication);
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined, color: Colors.green),
              title: const Text('Google Maps'),
              onTap: () async {
                Navigator.pop(ctx);
                if (await canLaunchUrl(googleUrl)) {
                  await launchUrl(googleUrl);
                } else {
                  // Fallback to web
                  final webUrl = Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=$encoded',
                  );
                  await launchUrl(webUrl, mode: LaunchMode.externalApplication);
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.directions_car,
                color: Colors.blueAccent,
              ),
              title: const Text('Waze'),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                if (await canLaunchUrl(wazeUrl)) {
                  await launchUrl(wazeUrl);
                } else {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Waze not installed')),
                  );
                }
              },
            ),
            SizedBox(height: context.tokens.spacingM),
          ],
        ),
      ),
    );
  }
}
