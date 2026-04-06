import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons, IconButton;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:terminal/features/dashboard/presentation/providers/driver_locations_provider.dart';
import 'package:terminal/features/dispatch/presentation/providers/load_providers.dart';
import 'package:milow_core/milow_core.dart';

class FleetMapView extends ConsumerStatefulWidget {
  const FleetMapView({super.key});

  @override
  ConsumerState<FleetMapView> createState() => _FleetMapViewState();
}

class _FleetMapViewState extends ConsumerState<FleetMapView> {
  final MapController _mapController = MapController();
  String? _followedDriverId;

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(driverLocationsProvider);
    final loadsAsync = ref.watch(loadsListProvider);
    final theme = FluentTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.resources.dividerStrokeColorDefault,
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            locationsAsync.when(
              data: (locations) {
                if (_followedDriverId != null) {
                  final followedLoc = locations.firstWhere(
                    (l) => l.driverId == _followedDriverId,
                    orElse: () => locations.first,
                  );
                  _mapController.move(
                    latlong.LatLng(followedLoc.latitude, followedLoc.longitude),
                    _mapController.camera.zoom,
                  );
                }

                return FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: locations.isNotEmpty
                        ? latlong.LatLng(
                            locations.first.latitude,
                            locations.first.longitude,
                          )
                        : latlong.LatLng(43.6532, -79.3832), // Toronto default
                    initialZoom: 12.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    // Stop Geofence Circles
                    CircleLayer(
                      circles: loadsAsync.maybeWhen(
                        data: (loads) => loads
                            .expand((l) => l.stops)
                            .where((s) =>
                                s.location.latitude != null &&
                                s.location.longitude != null)
                            .map((s) {
                          return CircleMarker(
                            point: latlong.LatLng(
                                s.location.latitude!, s.location.longitude!),
                            radius: 500, // 500 meters
                            useRadiusInMeter: true,
                            color: (s.type == StopType.pickup
                                    ? Colors.green
                                    : Colors.red)
                                .withValues(alpha: 0.1),
                            borderColor: (s.type == StopType.pickup
                                    ? Colors.green
                                    : Colors.red)
                                .withValues(alpha: 0.3),
                            borderStrokeWidth: 1,
                          );
                        }).toList(),
                        orElse: () => <CircleMarker>[],
                      ),
                    ),
                    // Stop Markers
                    MarkerLayer(
                      markers: loadsAsync.maybeWhen(
                        data: (loads) => loads
                            .expand((l) => l.stops)
                            .where((s) =>
                                s.location.latitude != null &&
                                s.location.longitude != null)
                            .map((s) {
                          return Marker(
                            point: latlong.LatLng(
                                s.location.latitude!, s.location.longitude!),
                            width: 32,
                            height: 32,
                            child: _StopMarker(stop: s),
                          );
                        }).toList(),
                        orElse: () => [],
                      ),
                    ),
                    // Driver Markers
                    MarkerLayer(
                      markers: locations.map((loc) {
                        return Marker(
                          point: latlong.LatLng(loc.latitude, loc.longitude),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _followedDriverId = loc.driverId;
                              });
                            },
                            child: _DriverMarker(
                              driverId: loc.driverId,
                              heading: loc.heading ?? 0,
                              isFollowed: _followedDriverId == loc.driverId,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: ProgressRing()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),

            // Map Controls
            Positioned(
              top: 12,
              right: 12,
              child: Column(
                children: [
                  _MapControlButton(
                    icon: FluentIcons.add_24_regular,
                    onPressed: () => _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MapControlButton(
                    icon: FluentIcons.subtract_24_regular,
                    onPressed: () => _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    ),
                  ),
                  if (_followedDriverId != null) ...[
                    const SizedBox(height: 8),
                    _MapControlButton(
                      icon: FluentIcons.location_24_regular,
                      color: theme.accentColor,
                      onPressed: () {
                        setState(() {
                          _followedDriverId = null;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),

            // Info Overlay
            if (_followedDriverId != null)
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.cardColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.accentColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        FluentIcons.location_24_regular,
                        size: 14,
                        color: theme.accentColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Following Driver...',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _followedDriverId = null),
                        child: Icon(
                          FluentIcons.dismiss_24_regular,
                          size: 12,
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DriverMarker extends StatelessWidget {
  final String driverId;
  final double heading;
  final bool isFollowed;

  const _DriverMarker({
    required this.driverId,
    required this.heading,
    required this.isFollowed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        if (isFollowed)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 1),
            builder: (context, value, child) {
              return Container(
                width: 40 * value,
                height: 40 * value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.accentColor.withValues(alpha: 1 - value),
                    width: 2,
                  ),
                ),
              );
            },
            onEnd: () {}, // Repeat would be nice but keeping it simple for now
          ),
        Transform.rotate(
          angle: heading * (3.14159 / 180),
          child: Container(
            decoration: BoxDecoration(
              color: isFollowed ? theme.accentColor : Colors.blue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: const Icon(
              FluentIcons.navigation_24_filled,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _StopMarker extends StatelessWidget {
  final Stop stop;

  const _StopMarker({required this.stop});

  @override
  Widget build(BuildContext context) {
    final isPickup = stop.type == StopType.pickup;
    final color = isPickup ? Colors.green : Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(
        isPickup
            ? FluentIcons.location_24_filled
            : FluentIcons.location_24_regular,
        size: 16,
        color: color,
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  const _MapControlButton({
    required this.icon,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Button(
        onPressed: onPressed,
        child: Icon(
          icon,
          size: 16,
          color: color ?? theme.resources.textFillColorPrimary,
        ),
      ),
    );
  }
}
