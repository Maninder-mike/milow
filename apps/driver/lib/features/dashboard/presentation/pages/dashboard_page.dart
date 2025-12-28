// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
  late Animation<double> _bellRotationAnimation;
  late Animation<double> _bellScaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize bell animation controller
    _bellAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Create rotation animation (-15° to +15°)
    _bellRotationAnimation =
        Tween<double>(
          begin: -0.26, // -15 degrees in radians
          end: 0.26, // +15 degrees in radians
        ).animate(
          CurvedAnimation(
            parent: _bellAnimationController,
            curve: Curves.easeInOut,
          ),
        );

    // Create scale animation (1.0 to 1.1)
    _bellScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _bellAnimationController,
        curve: Curves.easeInOut,
      ),
    );

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

  Widget _buildHeroSection(
    BuildContext context,
    bool isDark,
    double margin,
    Color cardColor,
    Color borderColor,
    Color secondaryTextColor,
    Color textColor,
  ) {
    // Base background color to fade into (matches Scaffold background)
    final baseColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Stack(
      children: [
        // Extended Gradient Background with Fade
        Container(
          height: 540,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF2E0213), // Deep dark red/purple
                Color(0xFF8B2C4B), // Muted magenta
                Color(0xFFA66C44), // Warm earthy tone
              ],
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
                      'Create with Veo 3',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Generate videos with your ingredients',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Generate Video',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Page Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white54,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white54,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white54,
                            shape: BoxShape.circle,
                          ),
                        ),
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
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
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
                    'Add Data',
                    Icons.add,
                    () => context.push('/add-entry'),
                    cardColor,
                    borderColor,
                    textColor,
                  ),
                  const SizedBox(width: 12),
                  _buildGetStartedCard(
                    'Explore',
                    Icons.explore_outlined,
                    () => context.go('/explore'),
                    cardColor,
                    borderColor,
                    textColor,
                  ),
                  const SizedBox(width: 12),
                  _buildGetStartedCard(
                    'Inbox',
                    Icons.inbox_outlined,
                    () => context.go('/inbox'),
                    cardColor,
                    borderColor,
                    textColor,
                  ),
                  const SizedBox(width: 12),
                  _buildGetStartedCard(
                    'Settings',
                    Icons.settings_outlined,
                    () => context.go('/settings'),
                    cardColor,
                    borderColor,
                    textColor,
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
                  _quickAction(
                    Colors.transparent,
                    Colors.transparent,
                    Colors.white,
                    Icons.search,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GlobalSearchPage(),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  _buildNotificationBell(
                    Colors.transparent,
                    Colors.transparent,
                    Colors.white,
                    forceWhite: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGetStartedCard(
    String label,
    IconData icon,
    VoidCallback onTap,
    Color cardColor,
    Color borderColor,
    Color textColor,
  ) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 32, color: textColor),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark
        ? Colors.white
        : const Color(0xFF101828); // retained for subsequent widgets
    final secondaryTextColor = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF667085);
    final borderColor = isDark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFD0D5DD);

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
              : [
                  const Color(0xFFe8f4f8),
                  const Color(0xFFfce4ec),
                  const Color(0xFFe8f5e9),
                ],
        ),
      ),
      child: Shimmer(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          displacement: 60,
          strokeWidth: 3.0,
          color: const Color(0xFF007AFF),
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroSection(
                  context,
                  isDark,
                  margin,
                  cardColor,
                  borderColor,
                  secondaryTextColor,
                  textColor,
                ),
                const SizedBox(height: 24),
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
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Border Wait Times Unavailable',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _borderError!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: secondaryTextColor,
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
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF007AFF),
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
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              _loadBorderWaitTimes(forceRefresh: true),
                          icon: const Icon(
                            Icons.refresh,
                            size: 16,
                            color: Color(0xFF007AFF),
                          ),
                          label: Text(
                            'Refresh',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF007AFF),
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
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.3)
                                  : Colors.black.withValues(alpha: 0.08),
                              blurRadius: 24,
                              spreadRadius: 0,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDark
                                      ? [
                                          Colors.white.withValues(alpha: 0.15),
                                          Colors.white.withValues(alpha: 0.05),
                                        ]
                                      : [
                                          Colors.white.withValues(alpha: 0.9),
                                          Colors.white.withValues(alpha: 0.7),
                                        ],
                                ),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.8),
                                  width: 1.5,
                                ),
                              ),
                              child: _isLoadingEntries
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
                                              color: secondaryTextColor,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'No entries yet',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                color: secondaryTextColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Add your first trip or fuel entry',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: secondaryTextColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : Column(
                                      children: [
                                        ..._recentEntries.asMap().entries.map((
                                          entry,
                                        ) {
                                          final index = entry.key;
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
                                              textColor,
                                              secondaryTextColor,
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
                                              textColor,
                                              secondaryTextColor,
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
                                              if (index <
                                                  _recentEntries.length - 1)
                                                Divider(
                                                  height: 1,
                                                  color: borderColor,
                                                ),
                                            ],
                                          );
                                        }),
                                        Divider(height: 1, color: borderColor),
                                        // See more button
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
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            child: Center(
                                              child: Text(
                                                'See more',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(
                                                    0xFF007AFF,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const SectionHeader(title: 'Learning Pages'),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(horizontal: margin),
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 32,
                        color: secondaryTextColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Learning Resources Coming Soon',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'We are working on great educational content for you.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: secondaryTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                // Extra padding for floating bottom nav bar
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickAction(
    Color bg,
    Color border,
    Color iconColor,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildNotificationBell(
    Color cardColor,
    Color borderColor,
    Color iconColor, {
    bool forceWhite = false,
  }) {
    return GestureDetector(
      onTap: () async {
        await context.push('/notifications');
        // Refresh notification count after returning from notifications page
        await NotificationService.instance.refreshUnreadCount();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animated bell icon
            AnimatedBuilder(
              animation: _bellAnimationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _unreadNotificationCount > 0
                      ? _bellRotationAnimation.value
                      : 0.0,
                  child: Transform.scale(
                    scale: _unreadNotificationCount > 0
                        ? _bellScaleAnimation.value
                        : 1.0,
                    child: Icon(
                      Icons.notifications_outlined,
                      color: forceWhite ? Colors.white : iconColor,
                      size: 24,
                    ),
                  ),
                );
              },
            ),
            // Red dot indicator for unread notifications
            if (_unreadNotificationCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.all(color: cardColor, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordEntry(
    Color textColor,
    Color secondaryTextColor,
    String type,
    String entryId,
    String description,
    String date,
    String value,
  ) {
    final isTrip = type == 'trip';
    final iconColor = isTrip
        ? const Color(0xFF3B82F6)
        : const Color(0xFFF59E0B);
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
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF3B82F6),
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
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: secondaryTextColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      date,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: secondaryTextColor,
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
