import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';

class VehicleStatusPage extends StatefulWidget {
  final Map<String, dynamic> vehicle;

  const VehicleStatusPage({super.key, required this.vehicle});

  @override
  State<VehicleStatusPage> createState() => _VehicleStatusPageState();
}

class _VehicleStatusPageState extends State<VehicleStatusPage> {
  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    final status = vehicle['status'] as String? ?? 'Unknown';
    final isIssue =
        status == 'Breakdown' ||
        status == 'Maintenance' ||
        vehicle['mil_status'] == true;

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: Text(
          'Vehicle Status: ${vehicle['vehicle_number']}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        commandBar: FilledButton(
          child: const Text('Edit Vehicle'),
          onPressed: () {
            // TODO: Implement Edit
          },
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
          ],
        ),

        const SizedBox(height: 24),

        // Diagnostics Section
        Text('Diagnostics', style: FluentTheme.of(context).typography.subtitle),
        const SizedBox(height: 8),
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
                isNormal: (vehicle['battery_voltage'] ?? 0) > 12.0,
              ),
            ],
          ),
        ),
      ],
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
          Text(
            value ?? '-',
            style: const TextStyle(fontWeight: FontWeight.w500),
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
