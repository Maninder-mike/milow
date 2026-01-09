import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';

class DashboardMapWidget extends StatefulWidget {
  const DashboardMapWidget({super.key});

  @override
  State<DashboardMapWidget> createState() => _DashboardMapWidgetState();
}

class _DashboardMapWidgetState extends State<DashboardMapWidget> {
  final List<UserProfile> _drivers = [];
  final Map<String, DriverLocation> _locations = {};
  RealtimeChannel? _channel;
  bool _isLoading = true;
  String? _companyId;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 1. Get current user's company_id
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) {
        _companyId = profile['company_id'] as String?;
      }

      if (_companyId != null) {
        // 2. Fetch data in parallel
        await Future.wait([_fetchDrivers(), _fetchLocations()]);
        // 3. Subscribe to location updates
        _subscribeToRealtime();
      }
    } catch (e) {
      debugPrint('Error initializing map data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDrivers() async {
    if (_companyId == null) return;
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('role', 'driver')
          .eq('company_id', _companyId!);

      if (mounted) {
        setState(() {
          _drivers.clear();
          for (final row in response) {
            _drivers.add(UserProfile.fromJson(row));
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching drivers: $e');
    }
  }

  Future<void> _fetchLocations() async {
    if (_companyId == null) return;
    try {
      final response = await Supabase.instance.client
          .from('driver_locations')
          .select()
          .eq('company_id', _companyId!);

      if (mounted) {
        setState(() {
          _locations.clear();
          for (final row in response) {
            final loc = DriverLocation.fromJson(row);
            _locations[loc.driverId] = loc;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching locations: $e');
    }
  }

  void _subscribeToRealtime() {
    if (_companyId == null) return;

    _channel = Supabase.instance.client
        .channel('public:driver_locations:$_companyId')
        .onPostgresChanges(
          event: PostgresChangeEvent
              .all, // Listen to all to handle inserts/updates
          schema: 'public',
          table: 'driver_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: _companyId!,
          ),
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) {
              // Optionally handle deletes
            } else {
              // Insert or Update
              // For newer Supabase libraries, 'newRecord' is strictly non-null for these events
              final newRecord = payload.newRecord;
              if (newRecord != null) {
                _updateLocation(DriverLocation.fromJson(newRecord));
              }
            }
          },
        )
        .subscribe();
  }

  void _updateLocation(DriverLocation location) {
    if (!mounted) return;
    setState(() {
      _locations[location.driverId] = location;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Default to US center
    final initialCenter = const LatLng(39.8283, -98.5795);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 4.5,
              minZoom: 3.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.milow.terminal',
              ),
              MarkerLayer(
                markers: _locations.values.map((loc) {
                  // Find driver info
                  final driver = _drivers.firstWhere(
                    (d) => d.id == loc.driverId,
                    orElse: () => UserProfile(
                      id: loc.driverId,
                      role: UserRole.driver,
                      fullName: 'Unknown Driver',
                    ),
                  );

                  return Marker(
                    point: LatLng(loc.latitude, loc.longitude),
                    width: 40,
                    height: 40,
                    child: Tooltip(
                      message:
                          '${driver.fullName ?? "Driver"}\nUpdated: ${_formatTime(loc.updatedAt)}',
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        // Using Material Icon to be safe
                        child: Icon(
                          material.Icons.local_shipping_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          if (_isLoading)
            const Positioned(top: 16, right: 16, child: ProgressRing()),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
