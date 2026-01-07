import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';

import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/location_service.dart';
import 'package:milow/core/services/preferences_service.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/theme/m3_expressive_motion.dart';

/// Interactive swipeable card showing pickup and delivery destinations
/// Displays destination info and dynamic distance using geolocator
class ActiveTripCard extends StatefulWidget {
  final Trip trip;
  final VoidCallback? onComplete;

  const ActiveTripCard({required this.trip, super.key, this.onComplete});

  @override
  State<ActiveTripCard> createState() => _ActiveTripCardState();
}

class _ActiveTripCardState extends State<ActiveTripCard> {
  double? _pickupDistance;
  double? _deliveryDistance;
  bool _isLoadingPickup = true;
  bool _isLoadingDelivery = true;
  Timer? _locationTimer;
  late PageController _pageController;
  int _currentPage = 0;
  UnitSystem _unitSystem = UnitSystem.metric;

  // Check which locations are available
  bool get _hasPickup => widget.trip.pickupLocations.isNotEmpty;
  bool get _hasDelivery => widget.trip.deliveryLocations.isNotEmpty;
  int get _totalPages => (_hasPickup ? 1 : 0) + (_hasDelivery ? 1 : 0);

  // Determine initial page based on trip state
  // If pickup locations exist, we're in pickup mode (show pickup first)
  // If no pickups, we're in delivery mode
  int get _initialPage => _hasPickup ? 0 : 0;

  String get _pickupAddress {
    if (_hasPickup) {
      return _extractCityStateCountry(widget.trip.pickupLocations.first);
    }
    return 'No pickup';
  }

  String get _deliveryAddress {
    if (_hasDelivery) {
      return _extractCityStateCountry(widget.trip.deliveryLocations.first);
    }
    return 'No delivery';
  }

  String get _fullPickupAddress =>
      _hasPickup ? widget.trip.pickupLocations.first : '';
  String get _fullDeliveryAddress =>
      _hasDelivery ? widget.trip.deliveryLocations.first : '';

  /// Extract city, state, country from full address
  String _extractCityStateCountry(String address) {
    if (address.isEmpty) return 'Unknown';

    final parts = address
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !RegExp(r'^\d+$').hasMatch(e))
        .toList();

    if (parts.length >= 3) {
      return parts.sublist(parts.length - 3).join(', ');
    }

    return parts.join(', ');
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialPage);
    _currentPage = _initialPage;
    _initLocation();
    // Update location every 30 seconds
    _locationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateDistances(),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingPickup = false;
            _isLoadingDelivery = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingPickup = false;
          _isLoadingDelivery = false;
        });
        return;
      }

      await _updateDistances();
    } catch (e) {
      setState(() {
        _isLoadingPickup = false;
        _isLoadingDelivery = false;
      });
    }
  }

  Future<void> _updateDistances() async {
    try {
      final unitSystem = await PreferencesService.getUnitSystem();
      if (mounted) {
        setState(() => _unitSystem = unitSystem);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      // Update pickup distance
      if (_hasPickup) {
        unawaited(
          _updateDistanceForAddress(_fullPickupAddress, position, (distance) {
            if (mounted) {
              setState(() {
                _pickupDistance = distance;
                _isLoadingPickup = false;
              });
            }
          }),
        );
      } else {
        setState(() => _isLoadingPickup = false);
      }

      // Update delivery distance
      if (_hasDelivery) {
        unawaited(
          _updateDistanceForAddress(_fullDeliveryAddress, position, (distance) {
            if (mounted) {
              setState(() {
                _deliveryDistance = distance;
                _isLoadingDelivery = false;
              });
            }
          }),
        );
      } else {
        setState(() => _isLoadingDelivery = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPickup = false;
          _isLoadingDelivery = false;
        });
      }
    }
  }

  Future<void> _updateDistanceForAddress(
    String fullAddress,
    Position position,
    void Function(double) onDistance,
  ) async {
    try {
      final resolvedAddress = await LocationService.resolveAddress(fullAddress);
      final addressToGeocode = resolvedAddress ?? fullAddress;
      final locations = await locationFromAddress(addressToGeocode);

      if (locations.isNotEmpty) {
        final dest = locations.first;
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          dest.latitude,
          dest.longitude,
        );
        onDistance(distance);
      }
    } catch (e) {
      // Silently fail for individual address
    }
  }

  String _formatDistance(double meters) {
    final useKm = _unitSystem == UnitSystem.metric;
    if (useKm) {
      final km = meters / 1000;
      if (km < 1) {
        return '${meters.round()} m away';
      }
      return '${km.toStringAsFixed(1)} km away';
    } else {
      final miles = meters / 1609.34;
      if (miles < 0.1) {
        final feet = meters * 3.28084;
        return '${feet.round()} ft away';
      }
      return '${miles.toStringAsFixed(1)} mi away';
    }
  }

  String _formatETA(double meters) {
    const avgSpeedMps = 26.82; // 60 mph
    final seconds = meters / avgSpeedMps;
    final minutes = (seconds / 60).round();

    if (minutes < 1) {
      return 'Arriving';
    } else if (minutes < 60) {
      return '~$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMins = minutes % 60;
      if (remainingMins == 0) {
        return '~${hours}h';
      }
      return '~${hours}h ${remainingMins}m';
    }
  }

  double _calculateProgress(double? distance) {
    if (distance == null) return 0.3;
    const maxDistance = 500000.0;
    final progress = 1.0 - (distance / maxDistance).clamp(0.0, 1.0);
    return progress.clamp(0.1, 0.95);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // Build list of pages based on available locations
    final pages = <Widget>[];

    // Check completion status
    final allPickupsCompleted = widget.trip.allPickupsCompleted;
    final allDeliveriesCompleted = widget.trip.allDeliveriesCompleted;

    if (_hasPickup) {
      pages.add(
        _buildCard(
          context,
          isPickup: true,
          address: _pickupAddress,
          distance: _pickupDistance,
          isLoading: _isLoadingPickup,
          statusLabel: allPickupsCompleted
              ? 'PICKUP COMPLETE'
              : (widget.trip.isEmptyLeg ? 'EMPTY LEG' : 'EN ROUTE TO PICKUP'),
          statusColor: allPickupsCompleted
              ? tokens.success
              : (widget.trip.isEmptyLeg
                    ? tokens.textSecondary
                    : tokens.warning),
          icon: allPickupsCompleted
              ? Icons.check_circle_rounded
              : Icons.store_rounded,
          hideEta: allPickupsCompleted,
        ),
      );
    }
    if (_hasDelivery) {
      pages.add(
        _buildCard(
          context,
          isPickup: false,
          address: _deliveryAddress,
          distance: _deliveryDistance,
          isLoading: _isLoadingDelivery,
          statusLabel: allDeliveriesCompleted
              ? 'DELIVERY COMPLETE'
              : (widget.trip.isEmptyLeg ? 'EMPTY LEG' : 'EN ROUTE TO DELIVERY'),
          statusColor: allDeliveriesCompleted
              ? tokens.success
              : (widget.trip.isEmptyLeg ? tokens.textSecondary : tokens.info),
          icon: allDeliveriesCompleted
              ? Icons.check_circle_rounded
              : Icons.local_shipping_rounded,
          hideEta: allDeliveriesCompleted,
        ),
      );
    }

    if (pages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Swipeable Cards
        SizedBox(
          height: 175, // Fixed height for consistency
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            children: pages,
          ),
        ),
        if (_totalPages > 1) ...[
          SizedBox(height: tokens.spacingM),
          // Page Indicator Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalPages, (index) {
              final isActive = index == _currentPage;
              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: M3ExpressiveMotion.durationMedium,
                    curve: M3ExpressiveMotion.standard,
                  );
                },
                child: AnimatedContainer(
                  duration: M3ExpressiveMotion.durationShort,
                  margin: EdgeInsets.symmetric(horizontal: tokens.spacingXS),
                  width: isActive ? tokens.spacingL : tokens.spacingS,
                  height: tokens.spacingS,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(tokens.shapeFull),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required bool isPickup,
    required String address,
    required double? distance,
    required bool isLoading,
    required String statusLabel,
    required Color statusColor,
    required IconData icon,
    bool hideEta = false,
  }) {
    final tokens = context.tokens;
    final progress = _calculateProgress(distance);

    return GestureDetector(
      onTap: () {
        context.push('/add-entry', extra: {'editingTrip': widget.trip});
      },
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surface,
        margin: EdgeInsets.symmetric(horizontal: tokens.spacingXS),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.shapeL),
          side: BorderSide(color: tokens.subtleBorderColor, width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacingM),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Status & Trip Number
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacingS,
                      vertical: tokens.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(tokens.shapeFull),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: tokens.spacingS,
                          color: statusColor,
                        ),
                        SizedBox(width: tokens.spacingS),
                        Text(
                          statusLabel,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                                letterSpacing: 0.3,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '#${widget.trip.tripNumber}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacingM),

              // Destination
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(tokens.spacingS),
                    decoration: BoxDecoration(
                      color: tokens.surfaceContainer,
                      borderRadius: BorderRadius.circular(tokens.shapeS),
                    ),
                    child: Icon(icon, size: 20, color: tokens.textPrimary),
                  ),
                  SizedBox(width: tokens.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPickup ? 'Pickup' : 'Delivery',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: tokens.textTertiary),
                        ),
                        Text(
                          address,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: tokens.textPrimary,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacingM),

              // Progress Bar
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      // Track
                      Container(
                        height: 6,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: tokens.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(tokens.shapeFull),
                        ),
                      ),
                      // Progress
                      Container(
                        height: 6,
                        width: width * progress,
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(tokens.shapeFull),
                        ),
                      ),
                      // Truck Icon
                      Positioned(
                        left: (width * progress) - 12,
                        child: Container(
                          padding: EdgeInsets.all(tokens.spacingXS),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: statusColor, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.local_shipping_rounded,
                            size: 12,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: tokens.spacingS),

              // Footer: Distance & ETA (or completion status)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    hideEta
                        ? 'Complete ✓'
                        : (isLoading
                              ? 'Calculating...'
                              : _formatDistance(distance ?? 0)),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: hideEta ? tokens.success : tokens.textPrimary,
                    ),
                  ),
                  if (!hideEta && !isLoading && distance != null)
                    Text(
                      _formatETA(distance),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: tokens.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
