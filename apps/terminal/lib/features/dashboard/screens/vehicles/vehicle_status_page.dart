import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'add_vehicle_dialog.dart';
import '../../services/vehicle_service.dart';

class VehicleStatusPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> vehicle;

  const VehicleStatusPage({super.key, required this.vehicle});

  @override
  ConsumerState<VehicleStatusPage> createState() => _VehicleStatusPageState();
}

class _VehicleStatusPageState extends ConsumerState<VehicleStatusPage> {
  late Map<String, dynamic> _vehicle;
  int _selectedTabIndex = 0;

  @override
  void didUpdateWidget(VehicleStatusPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.vehicle['id'] != oldWidget.vehicle['id']) {
      _vehicle = widget.vehicle;
    }
  }

  @override
  void initState() {
    super.initState();
    _vehicle = widget.vehicle;
  }

  Future<void> _fetchVehicleDetails() async {
    try {
      final data = await Supabase.instance.client
          .from('vehicles')
          .select()
          .eq('id', _vehicle['id'])
          .single();
      if (mounted) {
        setState(() {
          _vehicle = data;
        });
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: const Text('Error Refreshing Data'),
              content: Text(e.toString()),
              severity: InfoBarSeverity.error,
              onClose: close,
            );
          },
        );
      }
    }
  }

  Future<void> _deleteVehicle() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Delete Vehicle?'),
        content: const Text(
          'Are you sure you want to permanently delete this vehicle? This action cannot be undone.',
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('vehicles')
            .delete()
            .eq('id', _vehicle['id']);

        // Invalidate the vehicle list provider to update the sidebar
        ref.invalidate(vehiclesListProvider);

        if (mounted) {
          // Go back to the vehicles list or dashboard
          context.go('/dashboard');
        }
      } catch (e) {
        if (mounted) {
          displayInfoBar(
            context,
            builder: (context, close) {
              return InfoBar(
                title: const Text('Error Deleting Vehicle'),
                content: Text(e.toString()),
                severity: InfoBarSeverity.error,
                onClose: close,
              );
            },
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = _vehicle;
    final status = vehicle['status'] as String? ?? 'Unknown';
    final isIssue =
        status == 'Breakdown' ||
        status == 'Maintenance' ||
        vehicle['mil_status'] == true;

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: Text(
          'Vehicle Status: ${vehicle['truck_number']}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(FluentIcons.delete_24_regular, color: Colors.red),
              onPressed: _deleteVehicle,
            ),
            const SizedBox(width: 8),
            FilledButton(
              child: const Text('Edit Vehicle'),
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (context) => AddVehicleDialog(
                    vehicle: _vehicle,
                    onSaved: () async {
                      Navigator.pop(context);
                      await _fetchVehicleDetails();
                      // Refresh sidebar
                      ref.invalidate(vehiclesListProvider);
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
      children: [
        // Status Alert
        if (isIssue)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: InfoBar(
              title: Text(
                status == 'Breakdown'
                    ? 'Critical Breakdown'
                    : 'Attention Required',
              ),
              content: Text(
                vehicle['mil_status'] == true
                    ? 'Check Engine Light is ON. Diagnostics required.'
                    : 'Vehicle is currently in $status status.',
              ),
              severity: status == 'Breakdown'
                  ? InfoBarSeverity.error
                  : InfoBarSeverity.warning,
              isLong: true,
            ),
          ),

        if (status == 'Active' && !isIssue)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: InfoBar(
              title: const Text('System Normal'),
              content: const Text(
                'All systems operating within normal parameters.',
              ),
              severity: InfoBarSeverity.success,
              isLong: true,
            ),
          ),

        // Overview Section
        Text('Overview', style: FluentTheme.of(context).typography.subtitle),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildInfoCard(
                icon: FluentIcons.vehicle_truck_24_regular,
                title: 'Info',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRow('Type', vehicle['vehicle_type']),
                    _buildRow('Plate', vehicle['license_plate']),
                    _buildRow('VIN', vehicle['vin_number']),
                    _buildRow('Odometer', '${vehicle['odometer'] ?? '-'} mi'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoCard(
                icon: FluentIcons.gas_pump_24_regular,
                title: 'Fuel & Fluids',
                content: Column(
                  children: [
                    _buildProgressBar(
                      'Fuel Level',
                      vehicle['fuel_level'] ?? 0.0,
                      Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _buildProgressBar(
                      'DEF Level',
                      vehicle['def_level'] ?? 0.0,
                      Colors.teal,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: _buildAssignedDriverCard()),
          ],
        ),

        const SizedBox(height: 24),

        // Diagnostics Section
        // TabView for Documents and Diagnostics
        SizedBox(
          height: 400, // Fixed height for TabView
          child: TabView(
            tabs: [
              Tab(
                text: const Text('Documents'),
                icon: const Icon(FluentIcons.document_24_regular),
                body: _buildDocumentsTab(),
              ),
              Tab(
                text: const Text('Diagnostics-Health'),
                icon: const Icon(FluentIcons.heart_pulse_24_regular),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expander(
                        header: const Text('Engine & Powertrain'),
                        icon: const Icon(FluentIcons.beaker_24_regular),
                        initiallyExpanded: true,
                        content: Column(
                          children: [
                            _buildDiagnosticItem(
                              'Engine Oil Pressure',
                              '${vehicle['oil_pressure'] ?? 0} PSI',
                              isNormal: (vehicle['oil_pressure'] ?? 0) > 20,
                            ),
                            const Divider(),
                            _buildDiagnosticItem(
                              'Coolant Temp',
                              '${vehicle['engine_temp'] ?? 0}°F',
                              isNormal: (vehicle['engine_temp'] ?? 0) < 220,
                            ),
                            const Divider(),
                            _buildDiagnosticItem(
                              'Battery Voltage',
                              '${vehicle['battery_voltage'] ?? 0} V',
                              isNormal:
                                  (vehicle['battery_voltage'] ?? 0) > 12.0,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            currentIndex: _selectedTabIndex,
            onChanged: (index) => setState(() => _selectedTabIndex = index),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsTab() {
    // Mock Documents Data
    final documents = [
      {
        'name': 'Insurance Policy',
        'type': 'Insurance',
        'expiry': '2025-12-31',
        'status': 'Valid',
      },
      {
        'name': 'Vehicle Registration',
        'type': 'Registration',
        'expiry': '2026-06-15',
        'status': 'Valid',
      },
      {
        'name': 'Annual Inspection',
        'type': 'Inspection',
        'expiry': '2024-11-20',
        'status': 'Expired',
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        final isExpired = doc['status'] == 'Expired';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              isExpired
                  ? FluentIcons.error_circle_24_regular
                  : FluentIcons.checkmark_circle_24_regular,
              color: isExpired ? Colors.red : Colors.green,
            ),
            title: Text(doc['name'] as String),
            subtitle: Text('${doc['type']} • Expires: ${doc['expiry']}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isExpired
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isExpired
                      ? Colors.red.withValues(alpha: 0.5)
                      : Colors.green.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                doc['status'] as String,
                style: TextStyle(
                  color: isExpired ? Colors.red : Colors.green,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required Widget content,
  }) {
    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchAssignedDriver() async {
    try {
      // First get the assignment
      final assignment = await Supabase.instance.client
          .from('driver_vehicle_assignments')
          .select('driver_id')
          .eq('vehicle_id', _vehicle['id'])
          .isFilter('unassigned_at', null)
          .maybeSingle();

      if (assignment == null) return null;

      final driverId = assignment['driver_id'] as String?;
      if (driverId == null) return null;

      // Then fetch the driver profile
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name, phone, avatar_url')
          .eq('id', driverId)
          .maybeSingle();

      return profile;
    } catch (e) {
      debugPrint('Error fetching assigned driver: $e');
      return null;
    }
  }

  Widget _buildAssignedDriverCard() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchAssignedDriver(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            padding: const EdgeInsets.all(16),
            child: const Center(child: ProgressRing()),
          );
        }

        String driverName = 'Not Assigned';
        String driverPhone = '-';
        String? avatarUrl;
        bool hasDriver = false;

        if (snapshot.hasData && snapshot.data != null) {
          final data = snapshot.data!;
          hasDriver = true;
          driverName = data['full_name'] ?? 'Unknown';
          driverPhone = data['phone'] ?? '-';
          avatarUrl = data['avatar_url'] as String?;
        }

        return Card(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(FluentIcons.person_24_regular, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Assigned Driver',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if (hasDriver)
                    IconButton(
                      icon: const Icon(
                        FluentIcons.dismiss_24_regular,
                        size: 16,
                      ),
                      onPressed: () => _unassignDriver(),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (hasDriver)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null
                          ? Text(driverName[0].toUpperCase())
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driverName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            driverPhone,
                            style: TextStyle(
                              fontSize: 12,
                              color: FluentTheme.of(
                                context,
                              ).resources.textFillColorSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Center(
                  child: Column(
                    children: [
                      Icon(
                        FluentIcons.person_add_24_regular,
                        size: 32,
                        color: FluentTheme.of(
                          context,
                        ).resources.textFillColorSecondary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No driver assigned',
                        style: TextStyle(
                          color: FluentTheme.of(
                            context,
                          ).resources.textFillColorSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        child: const Text('Assign Driver'),
                        onPressed: () => _showAssignDriverDialog(),
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

  Future<void> _unassignDriver() async {
    try {
      await Supabase.instance.client
          .from('driver_vehicle_assignments')
          .update({'unassigned_at': DateTime.now().toIso8601String()})
          .eq('vehicle_id', _vehicle['id'])
          .isFilter('unassigned_at', null);

      setState(() {}); // Refresh

      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Driver Unassigned'),
            severity: InfoBarSeverity.success,
            onClose: close,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Error'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
            onClose: close,
          ),
        );
      }
    }
  }

  void _showAssignDriverDialog() {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Assign Driver'),
        content: SizedBox(
          height: 400,
          width: 400,
          child: FutureBuilder(
            future: Supabase.instance.client
                .from('profiles')
                .select('id, full_name, phone, avatar_url')
                .eq('role', 'driver')
                .order('full_name'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: ProgressRing());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final drivers = snapshot.data as List<dynamic>? ?? [];
              if (drivers.isEmpty) {
                return const Center(child: Text('No drivers found.'));
              }
              return ListView.builder(
                itemCount: drivers.length,
                itemBuilder: (context, index) {
                  final driver = drivers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: driver['avatar_url'] != null
                          ? NetworkImage(driver['avatar_url'])
                          : null,
                      child: driver['avatar_url'] == null
                          ? Text(
                              (driver['full_name'] as String? ?? '?')[0]
                                  .toUpperCase(),
                            )
                          : null,
                    ),
                    title: Text(driver['full_name'] ?? 'Unknown'),
                    subtitle: Text(driver['phone'] ?? '-'),
                    trailing: FilledButton(
                      child: const Text('Assign'),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _assignDriver(driver['id'] as String);
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _assignDriver(String driverId) async {
    try {
      // Unassign current driver if any
      await Supabase.instance.client
          .from('driver_vehicle_assignments')
          .update({'unassigned_at': DateTime.now().toIso8601String()})
          .eq('vehicle_id', _vehicle['id'])
          .isFilter('unassigned_at', null);

      // Create new assignment
      final currentUser = Supabase.instance.client.auth.currentUser;
      await Supabase.instance.client.from('driver_vehicle_assignments').insert({
        'driver_id': driverId,
        'vehicle_id': _vehicle['id'],
        'assigned_by': currentUser?.id,
      });

      setState(() {}); // Refresh

      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Driver Assigned'),
            severity: InfoBarSeverity.success,
            onClose: close,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Error'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
            onClose: close,
          ),
        );
      }
    }
  }

  Widget _buildRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: FluentTheme.of(context).resources.textFillColorSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value ?? '-',
              style: const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              '${(value * 100).toInt()}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ProgressBar(value: value * 100),
      ],
    );
  }

  Widget _buildDiagnosticItem(
    String label,
    String value, {
    bool isNormal = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            isNormal
                ? FluentIcons.checkmark_circle_24_regular
                : FluentIcons.dismiss_circle_24_regular,
            color: isNormal ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isNormal ? null : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
