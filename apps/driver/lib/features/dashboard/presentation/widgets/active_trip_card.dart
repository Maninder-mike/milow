import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';

import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow_core/milow_core.dart';

/// Interactive card showing the current active trip (trip without end odometer)
/// Displays destination info and dynamic distance using geolocator
class ActiveTripCard extends StatefulWidget {
  final Trip trip;
  final VoidCallback? onComplete;

  const ActiveTripCard({required this.trip, super.key, this.onComplete});

  @override
  State<ActiveTripCard> createState() => _ActiveTripCardState();
}

class _ActiveTripCardState extends State<ActiveTripCard> {
  double? _distanceToDestination;
  bool _isLoadingDistance = true;
  Timer? _locationTimer;

  // Determine if we're going to pickup or delivery
  // If no deliveries have been done yet, we're going to pickup
  // For now, assume going to first pickup if it exists, else first delivery
  bool get _isGoingToPickup => widget.trip.pickupLocations.isNotEmpty;

  String get _destinationAddress {
    String fullAddress;
    if (_isGoingToPickup && widget.trip.pickupLocations.isNotEmpty) {
      fullAddress = widget.trip.pickupLocations.first;
    } else if (widget.trip.deliveryLocations.isNotEmpty) {
      fullAddress = widget.trip.deliveryLocations.first;
    } else {
      return 'Unknown destination';
    }
    return _extractCityStateCountry(fullAddress);
  }

  /// Extract city, state, country from full address
  /// Example: "123 Main St, Dallas, TX, USA" -> "Dallas, TX, USA"
  String _extractCityStateCountry(String address) {
    if (address.isEmpty) return 'Unknown';

    // Split by comma and filter out empty or numeric-only parts (like ZIP codes)
    final parts = address
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !RegExp(r'^\d+$').hasMatch(e))
        .toList();

    if (parts.length >= 3) {
      // If we have 4+ parts (e.g., Street, City, State, Country),
      // the last 3 are usually City, State, Country.
      return parts.sublist(parts.length - 3).join(', ');
    }

    return parts.join(', ');
  }

  String get _statusLabel =>
      _isGoingToPickup ? 'EN ROUTE TO PICKUP' : 'EN ROUTE TO DELIVERY';

  Color get _statusColor =>
      _isGoingToPickup ? const Color(0xFFEA580C) : const Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _initLocation();
    // Update location every 30 seconds
    _locationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateDistance(),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingDistance = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingDistance = false);
        return;
      }

      await _updateDistance();
    } catch (e) {
      setState(() => _isLoadingDistance = false);
    }
  }

  Future<void> _updateDistance() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      // Geocode destination address to get coordinates
      final locations = await locationFromAddress(_destinationAddress);
      if (locations.isNotEmpty) {
        final dest = locations.first;
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          dest.latitude,
          dest.longitude,
        );

        if (mounted) {
          setState(() {
            _distanceToDestination = distance;
            _isLoadingDistance = false;
          });
        }
      } else {
        setState(() => _isLoadingDistance = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDistance = false);
      }
    }
  }

  String _formatDistance(double meters) {
    // Use trip's distance unit preference
    final useKm = widget.trip.distanceUnit == 'km';
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

  // Calculate progress (0.0 to 1.0) - placeholder for now
  // In future, could use start location to calculate actual progress
  double get _progress {
    if (_distanceToDestination == null) return 0.3; // Default placeholder
    // Assume max distance of 500km for progress calculation
    const maxDistance = 500000.0; // 500km in meters
    final progress =
        1.0 - (_distanceToDestination! / maxDistance).clamp(0.0, 1.0);
    return progress.clamp(0.1, 0.95);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return GestureDetector(
      onTap: () {
        context.push('/add-entry', extra: {'editingTrip': widget.trip});
      },
      child: Card(
        // Rules: Cards No elevation, shapeL (16px)
        elevation: 0,
        color: Theme.of(context).colorScheme.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.shapeL),
          side: BorderSide(color: tokens.subtleBorderColor, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Status & Trip Number
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(tokens.shapeFull),
                      border: Border.all(
                        color: _statusColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 8, color: _statusColor),
                        const SizedBox(width: 6),
                        Text(
                          _statusLabel,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _statusColor,
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
              const SizedBox(height: 12),

              // Destination
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tokens.surfaceContainer,
                      borderRadius: BorderRadius.circular(tokens.shapeS),
                    ),
                    child: Icon(
                      _isGoingToPickup
                          ? Icons.store_rounded
                          : Icons.local_shipping_rounded,
                      size: 20,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Destination',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: tokens.textTertiary),
                        ),
                        Text(
                          _destinationAddress,
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
              const SizedBox(height: 12),

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
                        width: width * _progress,
                        decoration: BoxDecoration(
                          color: _statusColor,
                          borderRadius: BorderRadius.circular(tokens.shapeFull),
                        ),
                      ),
                      // Truck Icon
                      Positioned(
                        left: (width * _progress) - 12,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: _statusColor, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: _statusColor.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.local_shipping_rounded,
                            size: 12,
                            color: _statusColor,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),

              // Footer: Distance & Label
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isLoadingDistance
                        ? 'Calculating...'
                        : _formatDistance(_distanceToDestination ?? 0),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: tokens.textPrimary,
                    ),
                  ),
                  Text(
                    'Geofence Proximity',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.textTertiary,
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
