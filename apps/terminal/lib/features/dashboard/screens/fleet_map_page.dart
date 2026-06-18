import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:milow_core/milow_core.dart';
import 'package:terminal/features/dashboard/presentation/providers/driver_locations_provider.dart';
import '../../../core/widgets/ui_hardening.dart';

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
              icon: const Icon(FluentIcons.arrow_clockwise_24_regular),
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
              loading: () => _buildSidebarSkeleton(theme),
              error: (e, _) => Center(
                child: StandardErrorState(
                  title: 'Failed to load drivers',
                  message: e.toString(),
                  onRetry: () => ref.refresh(driverLocationsProvider),
                ),
              ),
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
                            child: Icon(
                              FluentIcons.vehicle_truck_24_regular,
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

  Widget _buildSidebarSkeleton(FluentThemeData theme) {
    return ListView.builder(
      itemCount: 10,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: theme.resources.controlFillColorSecondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 140,
                      height: 12,
                      decoration: BoxDecoration(
                        color: theme.resources.controlFillColorSecondary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 100,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.resources.controlFillColorSecondary.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
