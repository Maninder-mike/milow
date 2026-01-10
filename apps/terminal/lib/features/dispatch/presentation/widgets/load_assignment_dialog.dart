import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:milow_core/milow_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../features/users/data/user_repository_provider.dart';
import '../../../../features/dashboard/services/vehicle_service.dart';
import '../../domain/models/load.dart';

class LoadAssignmentDialog extends ConsumerStatefulWidget {
  final Load load;
  final Function(List<String> driverIds, String? truckId, String? trailerId)
  onAssign;

  const LoadAssignmentDialog({
    super.key,
    required this.load,
    required this.onAssign,
  });

  @override
  ConsumerState<LoadAssignmentDialog> createState() =>
      _LoadAssignmentDialogState();
}

class _LoadAssignmentDialogState extends ConsumerState<LoadAssignmentDialog> {
  final List<String> _selectedDriverIds = [];
  String? _selectedTruckId;
  String? _selectedTrailerId;
  bool _isLoadingAssignment = false;

  @override
  void initState() {
    super.initState();
    if (widget.load.assignedDriverId != null) {
      _selectedDriverIds.add(widget.load.assignedDriverId!);
    }
    _selectedTruckId = widget.load.assignedTruckId;
    _selectedTrailerId = widget.load.assignedTrailerId;
  }

  Future<void> _autoSelectTruckForDriver(String driverId) async {
    setState(() => _isLoadingAssignment = true);
    try {
      final supabase = Supabase.instance.client;

      // Fetch active assignment
      final assignment = await supabase
          .from('fleet_assignments')
          .select('resource_id')
          .eq('assignee_id', driverId)
          .eq('type', 'driver_to_vehicle')
          .isFilter('unassigned_at', null)
          .maybeSingle();

      if (assignment != null && mounted) {
        final vehicleId = assignment['resource_id'] as String?;
        if (vehicleId != null) {
          // Verify this vehicle is actually a truck before selecting
          final vehicleTypeCheck = await supabase
              .from('vehicles')
              .select('vehicle_type')
              .eq('id', vehicleId)
              .maybeSingle();

          if (vehicleTypeCheck != null && mounted) {
            final type = vehicleTypeCheck['vehicle_type']
                ?.toString()
                .toLowerCase();

            if (type == 'truck') {
              setState(() => _selectedTruckId = vehicleId);
            } else if (type == 'trailer') {
              // Less common, but possible if they assigned a trailer to a driver?
              setState(() => _selectedTrailerId = vehicleId);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error auto-selecting truck: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAssignment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch real-time providers
    final driversAsync = ref.watch(usersProvider);
    final vehiclesAsync = ref.watch(vehiclesListProvider);

    return ContentDialog(
      title: Text(
        'Assign Load #${widget.load.tripNumber.isNotEmpty ? widget.load.tripNumber : widget.load.loadReference}',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select resources to assign to this load:'),
          const SizedBox(height: 16),

          // Driver Selection
          InfoLabel(
            label: 'Driver',
            child: driversAsync.when(
              data: (users) {
                final drivers = users
                    .where((u) => u.role == UserRole.driver && u.isVerified)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selected Drivers (Tags)
                    if (_selectedDriverIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedDriverIds.map((id) {
                            final driver = drivers.firstWhere(
                              (d) => d.id == id,
                              orElse: () => const UserProfile(
                                id: '',
                                role: UserRole.driver,
                                fullName: 'Unknown',
                              ),
                            );
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: FluentTheme.of(
                                  context,
                                ).accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: FluentTheme.of(
                                    context,
                                  ).accentColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    driver.fullName ?? 'Unknown',
                                    style: TextStyle(
                                      color: FluentTheme.of(
                                        context,
                                      ).accentColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(
                                      FluentIcons.chrome_close,
                                      size: 12,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _selectedDriverIds.remove(id);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    // Driver Search Box
                    AutoSuggestBox<String>(
                      placeholder: 'Search and add drivers...',
                      items: drivers
                          .where((d) => !_selectedDriverIds.contains(d.id))
                          .map((driver) {
                            return AutoSuggestBoxItem<String>(
                              value: driver.id,
                              label: driver.fullName ?? 'Unknown Driver',
                            );
                          })
                          .toList(),
                      onSelected: (item) {
                        if (item.value != null) {
                          setState(() {
                            _selectedDriverIds.add(item.value!);
                          });
                          // Auto-select truck only for the first driver added
                          if (_selectedDriverIds.length == 1) {
                            _autoSelectTruckForDriver(item.value!);
                          }
                        }
                      },
                    ),
                  ],
                );
              },
              loading: () => const ProgressBar(),
              error: (err, _) => Text('Error loading drivers: $err'),
            ),
          ),
          const SizedBox(height: 12),

          // Truck Selection
          InfoLabel(
            label: 'Truck',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                vehiclesAsync.when(
                  data: (vehicles) {
                    final trucks = vehicles
                        .where(
                          (v) =>
                              v['vehicle_type']?.toString().toLowerCase() ==
                              'truck',
                        )
                        .toList();

                    return ComboBox<String>(
                      placeholder: const Text('Select Truck'),
                      isExpanded: true,
                      items: trucks.map((truck) {
                        final truckNum = truck['truck_number'] ?? 'N/A';
                        return ComboBoxItem<String>(
                          value: truck['id'] as String?,
                          child: Text(truckNum),
                        );
                      }).toList(),
                      value: _selectedTruckId,
                      onChanged: (value) =>
                          setState(() => _selectedTruckId = value),
                    );
                  },
                  loading: () => const ProgressBar(),
                  error: (err, _) => Text('Error loading trucks: $err'),
                ),
                if (_isLoadingAssignment)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: ProgressRing(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Checking assignments...',
                          style: FluentTheme.of(context).typography.caption,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Trailer Selection
          InfoLabel(
            label: 'Trailer',
            child: vehiclesAsync.when(
              data: (vehicles) {
                final trailers = vehicles.where((v) {
                  final type = v['vehicle_type']?.toString().toLowerCase();
                  return type == 'trailer' ||
                      type == 'dry van' ||
                      type == 'reefer';
                }).toList();

                return ComboBox<String>(
                  placeholder: const Text('Select Trailer'),
                  isExpanded: true,
                  items: trailers.map((trailer) {
                    final trailerNum = trailer['truck_number'] ?? 'N/A';
                    return ComboBoxItem<String>(
                      value: trailer['id'] as String?,
                      child: Text(trailerNum),
                    );
                  }).toList(),
                  value: _selectedTrailerId,
                  onChanged: (value) =>
                      setState(() => _selectedTrailerId = value),
                );
              },
              loading: () => const ProgressBar(),
              error: (err, _) => Text('Error loading trailers: $err'),
            ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onAssign(
              _selectedDriverIds,
              _selectedTruckId,
              _selectedTrailerId,
            );
            Navigator.pop(context);
          },
          child: const Text('Assign'),
        ),
      ],
    );
  }
}
