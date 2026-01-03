import 'package:fluent_ui/fluent_ui.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/vehicle_service.dart';
import 'add_vehicle_dialog.dart';

class VehiclesPage extends ConsumerStatefulWidget {
  const VehiclesPage({super.key});

  @override
  ConsumerState<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends ConsumerState<VehiclesPage> {
  Future<void> _showAddEditDialog([Map<String, dynamic>? vehicle]) async {
    await showDialog(
      context: context,
      builder: (context) => AddVehicleDialog(
        vehicle: vehicle,
        onSaved: () {
          Navigator.pop(context); // Close dialog
          ref.invalidate(vehiclesListProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehiclesListProvider);

    return ScaffoldPage(
      header: PageHeader(
        title: Text(
          'Vehicles',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        commandBar: FilledButton(
          child: const Text('+ Add Vehicle'),
          onPressed: () => _showAddEditDialog(),
        ),
      ),
      content: vehiclesAsync.when(
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No vehicles found'),
                  const SizedBox(height: 16),
                  Button(
                    onPressed: () => _showAddEditDialog(),
                    child: const Text('Add your first vehicle'),
                  ),
                ],
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth < 800
                          ? 800
                          : constraints.maxWidth,
                      maxWidth: constraints.maxWidth < 800
                          ? 800
                          : constraints.maxWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: FluentTheme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: FluentTheme.of(
                              context,
                            ).resources.dividerStrokeColorDefault,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header Row
                            Row(
                              children: const [
                                Expanded(
                                  child: Text(
                                    'Vehicle #',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Type',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Plate',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'VIN',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Status',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    'Actions',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Divider(),
                            // List Rows
                            ...vehicles.map((vehicle) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: FluentTheme.of(
                                        context,
                                      ).resources.dividerStrokeColorDefault,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        vehicle['truck_number'] ??
                                            vehicle['vehicle_number'] ??
                                            '-',
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        vehicle['vehicle_type'] ?? '-',
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        vehicle['license_plate'] ?? '-',
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(vehicle['vin_number'] ?? '-'),
                                    ),
                                    Expanded(
                                      child: Text(
                                        vehicle['status'] ?? 'Active',
                                        style: TextStyle(
                                          color: vehicle['status'] == 'Active'
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: Button(
                                        child: const Text('Edit'),
                                        onPressed: () =>
                                            _showAddEditDialog(vehicle),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: ProgressRing()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
