import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:milow/features/explore/presentation/utils/explore_map_helper.dart';

class ExploreMapView extends StatefulWidget {
  final List<ExploreMapMarker> markers;
  final Function(ExploreMapMarker)? onMarkerTap;

  const ExploreMapView({required this.markers, this.onMarkerTap, super.key});

  @override
  State<ExploreMapView> createState() => _ExploreMapViewState();
}

class _ExploreMapViewState extends State<ExploreMapView> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 400,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(39.8283, -98.5795), // Center of US
                  initialZoom: 3.5,
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: isDark
                        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.maninder.milow',
                  ),
                  MarkerLayer(
                    markers: widget.markers.map((marker) {
                      return Marker(
                        point: marker.point,
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => widget.onMarkerTap?.call(marker),
                          child: _buildMarkerIcon(context, marker),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              // Controls Overlay
              Positioned(
                right: 8,
                top: 8,
                child: Column(
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: () {
                        _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom + 1,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.remove, size: 20),
                      onPressed: () {
                        _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom - 1,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: () {
                        _mapController.move(
                          const LatLng(39.8283, -98.5795),
                          3.5,
                        );
                      },
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

  Widget _buildMarkerIcon(BuildContext context, ExploreMapMarker marker) {
    Color color;
    IconData icon;

    switch (marker.type) {
      case MapMarkerType.trip:
        color = Theme.of(context).colorScheme.primary;
        icon = Icons.local_shipping;
        break;
      case MapMarkerType.fuel:
        color = Theme.of(context).colorScheme.secondary;
        icon = Icons.local_gas_station;
        break;
      case MapMarkerType.document:
        color = Theme.of(context).colorScheme.tertiary;
        icon = Icons.description;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Theme.of(context).colorScheme.onPrimary,
        size: 20,
      ),
    );
  }
}
