import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:milow_core/milow_core.dart';
import 'package:terminal/features/dashboard/presentation/providers/driver_locations_provider.dart';

class FleetMapPage extends ConsumerStatefulWidget {
  const FleetMapPage({super.key});

  @override
  ConsumerState<FleetMapPage> createState() => _FleetMapPageState();
}

class _FleetMapPageState extends ConsumerState<FleetMapPage> {
  final MapController _mapController = MapController();
  
  // Default center (can be tuned to company HQ)
  final LatLng _initialCenter = const LatLng(37.0902, -95.7129); // USA Center

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(driverLocationsProvider);
    final theme = FluentTheme.of(context);

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Live Fleet Map'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('Refresh'),
              onPressed: () => ref.invalidate(driverLocationsProvider),
            ),
          ],
        ),
      ),
      content: Row(
        children: [
          // 1. Sidebar: Active Drivers List
          SizedBox(
            width: 300,
            child: locationsAsync.when(
              data: (locations) => ListView.builder(
                itemCount: locations.length,
                itemBuilder: (context, index) {
                  final loc = locations[index];
                  final profile = loc.metadata?['profiles'] as Map<String, dynamic>?;
                  final String driverName = profile?['full_name'] ?? 'Driver ${loc.driverId.substring(0, 5)}';
                  final String status = profile?['driver_status'] ?? 'Active';
                  
                  return ListTile(
                    leading: _buildStatusIndicator(loc, status),
                    title: Text(driverName),
                    subtitle: Text('Status: $status • Updated ${loc.updatedAt.toLocal().toString().substring(11, 16)}'),
                    onPressed: () {
                      _mapController.move(LatLng(loc.latitude, loc.longitude), 12);
                    },
                  );
                },
              ),
              loading: () => const Center(child: ProgressRing()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          
          const Divider(direction: Axis.vertical),
          
          // 2. Main Area: Map
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: 4,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.milow.terminal',
                ),
                locationsAsync.maybeWhen(
                  data: (locations) => MarkerLayer(
                    markers: locations.map((loc) => Marker(
                      point: LatLng(loc.latitude, loc.longitude),
                      width: 40,
                      height: 40,
                      child: Tooltip(
                        message: 'Driver ${loc.driverId}',
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _getStatusColor(loc, theme).withValues(alpha: 0.8),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 4,
                                  color: Colors.black.withValues(alpha: 0.26),
                                ),
                              ],
                            ),
                            child: const Icon(
                              FluentIcons.delivery_truck,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(DriverLocation loc, String status) {
    final color = status.toLowerCase() == 'active' ? Colors.green : Colors.orange;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Color _getStatusColor(DriverLocation loc, FluentThemeData theme) {
    // This will be expanded when we have dynamic_color or driver_status joined
    return Colors.blue; 
  }
}
