import 'package:fluent_ui/fluent_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'add_vehicle_dialog.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  List<Map<String, dynamic>> _vehicles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
  }

  Future<void> _fetchVehicles() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('vehicles')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _vehicles = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: const Text('Error Fetching Vehicles'),
              content: Text(e.toString()),
              severity: InfoBarSeverity.error,
              onClose: close,
            );
          },
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddEditDialog([Map<String, dynamic>? vehicle]) async {
    await showDialog(
      context: context,
      builder: (context) => AddVehicleDialog(
        vehicle: vehicle,
        onSaved: () {
          Navigator.pop(context); // Close dialog
          _fetchVehicles(); // Refresh list
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      content: _isLoading
          ? const Center(child: ProgressRing())
          : _vehicles.isEmpty
          ? Center(
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
            )
          : LayoutBuilder(
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
                              ..._vehicles.map((vehicle) {
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
                                          vehicle['vehicle_number'] ?? '-',
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
                                        child: Text(
                                          vehicle['vin_number'] ?? '-',
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          vehicle['dot_number'] != null &&
                                                  vehicle['dot_number']
                                                      .isNotEmpty
                                              ? 'Active'
                                              : 'Pending',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ), // Logic placeholder
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
            ),
    );
  }
}
