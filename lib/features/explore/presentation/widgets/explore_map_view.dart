import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:milow/features/explore/presentation/utils/explore_map_helper.dart';
import 'package:milow/core/widgets/glassy_card.dart';

class ExploreMapView extends StatefulWidget {
  final List<ExploreMapMarker> markers;
  final Function(ExploreMapMarker)? onMarkerTap;
  final bool isDark;

  const ExploreMapView({
    required this.markers,
    required this.isDark,
    this.onMarkerTap,
    super.key,
  });

  @override
  State<ExploreMapView> createState() => _ExploreMapViewState();
}

class _ExploreMapViewState extends State<ExploreMapView> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: GlassyCard(
        padding: EdgeInsets.zero,
        borderRadius: 16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
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
                    urlTemplate: widget.isDark
                        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.maninder.milow',
                  ),
                  // PolylineLayer removed as per request
                  MarkerLayer(
                    markers: widget.markers.map((marker) {
                      return Marker(
                        point: marker.point,
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => widget.onMarkerTap?.call(marker),
                          child: _buildMarkerIcon(marker),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              // Legend / Controls Overlay
              Positioned(
                right: 8,
                top: 8,
                child: Column(
                  children: [
                    _MapControlBtn(
                      icon: Icons.add,
                      onTap: () {
                        _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom + 1,
                        );
                      },
                      isDark: widget.isDark,
                    ),
                    const SizedBox(height: 8),
                    _MapControlBtn(
                      icon: Icons.remove,
                      onTap: () {
                        _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom - 1,
                        );
                      },
                      isDark: widget.isDark,
                    ),
                    const SizedBox(height: 8),
                    _MapControlBtn(
                      icon: Icons.refresh,
                      onTap: () {
                        _mapController.move(
                          const LatLng(39.8283, -98.5795),
                          3.5,
                        );
                      },
                      isDark: widget.isDark,
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

  Widget _buildMarkerIcon(ExploreMapMarker marker) {
    Color color;
    IconData icon;

    switch (marker.type) {
      case MapMarkerType.trip:
        color = const Color(0xFF2E86DE); // Stronger Blue
        icon = Icons.local_shipping;
        break;
      case MapMarkerType.fuel:
        color = const Color(0xFFFF9F43); // Orange
        icon = Icons.local_gas_station;
        break;
      case MapMarkerType.document:
        color = const Color(0xFF1DD1A1); // Green
        icon = Icons.description;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

class _MapControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _MapControlBtn({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? Colors.grey[800] : Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            icon,
            size: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
