import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/ui_hardening.dart';
import '../../services/vehicle_service.dart';

import 'add_vehicle_dialog.dart';

class VehiclesPage extends ConsumerStatefulWidget {
  const VehiclesPage({super.key});

  @override
  ConsumerState<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends ConsumerState<VehiclesPage> {
  bool _initialActionHandled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialActionHandled) return;

    final uri = GoRouterState.of(context).uri;
    if (uri.queryParameters['action'] == 'new') {
      _initialActionHandled = true;
      Future.microtask(() {
        if (mounted) _showAddEditDialog();
      });
    }
  }

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
          if (vehicles.isEmpty) return _buildEmptyState();
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
        loading: () => const TableSkeleton(
          columnFlex: [1, 1, 1, 1, 1],
        ),
        error: (e, st) => StandardErrorState(
          message: 'Failed to load vehicles: $e',
          onRetry: () => ref.invalidate(vehiclesListProvider),
        ),

      ),
    );
  }



  Widget _buildEmptyState() {
    return StandardEmptyState(
      title: 'No Vehicles Registered',
      message: 'Your fleet is currently empty. Add your first truck or trailer to start managing your operations.',
      icon: FluentIcons.vehicle_truck_24_regular,
      action: FilledButton(
        onPressed: () => _showAddEditDialog(),
        child: const Text('Add First Vehicle'),
      ),
    );
  }
}
