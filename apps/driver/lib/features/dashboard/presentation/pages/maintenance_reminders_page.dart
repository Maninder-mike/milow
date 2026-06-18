import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/maintenance_repository.dart';
import 'package:milow_core/milow_core.dart';
import 'package:uuid/uuid.dart';

class MaintenanceRemindersPage extends StatefulWidget {
  const MaintenanceRemindersPage({super.key});

  @override
  State<MaintenanceRemindersPage> createState() => _MaintenanceRemindersPageState();
}

class _MaintenanceRemindersPageState extends State<MaintenanceRemindersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Vehicle> _vehicles = [];
  Vehicle? _selectedVehicle;
  int _currentOdometer = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadVehicles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    final result = await MaintenanceRepository.getVehicles();
    result.fold(
      (failure) {
        if (mounted) setState(() => _isLoading = false);
      },
      (vehicles) {
        if (vehicles.isNotEmpty) {
          // Default current odometer from last trip odometer or standard default
          // Let's check if there's any database record or default to 0
          if (mounted) {
            setState(() {
              _vehicles = vehicles;
              _selectedVehicle = vehicles.first;
              _isLoading = false;
            });
            unawaited(_loadOdometerForVehicle(vehicles.first.id));
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      },
    );
  }

  Future<void> _loadOdometerForVehicle(String vehicleId) async {
    // Simply fetch records for this vehicle to find the max odometer as a default odometer reading
    final recordsResult = await MaintenanceRepository.getRecords(vehicleId);
    recordsResult.fold(
      (_) {},
      (records) {
        if (records.isNotEmpty && mounted) {
          final maxOdo = records
              .map((r) => r.odometerAtService ?? 0)
              .fold(0, (max, odo) => odo > max ? odo : max);
          setState(() {
            _currentOdometer = maxOdo;
          });
        }
      },
    );
  }

  void _showLogServiceDialog() {
    if (_selectedVehicle == null) return;

    final formKey = GlobalKey<FormState>();
    MaintenanceServiceType selectedType = MaintenanceServiceType.oilChange;
    final odoController = TextEditingController(text: _currentOdometer > 0 ? _currentOdometer.toString() : '');
    final descriptionController = TextEditingController();
    final costController = TextEditingController();
    final performedByController = TextEditingController();
    final notesController = TextEditingController();
    DateTime performedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.tokens.shapeL),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                context.tokens.spacingM,
                context.tokens.spacingM,
                context.tokens.spacingM,
                MediaQuery.of(context).viewInsets.bottom + context.tokens.spacingM,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Log Maintenance Service',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      SizedBox(height: context.tokens.spacingM),
                      DropdownButtonFormField<MaintenanceServiceType>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Service Type',
                          border: OutlineInputBorder(),
                        ),
                        items: MaintenanceServiceType.values
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type.displayName),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedType = val);
                          }
                        },
                      ),
                      SizedBox(height: context.tokens.spacingM),
                      TextFormField(
                        controller: odoController,
                        decoration: const InputDecoration(
                          labelText: 'Odometer Reading',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Odometer is required';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Odometer must be a valid integer';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: context.tokens.spacingM),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      SizedBox(height: context.tokens.spacingM),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: costController,
                              decoration: const InputDecoration(
                                labelText: 'Cost (USD, Optional)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          SizedBox(width: context.tokens.spacingM),
                          Expanded(
                            child: TextFormField(
                              controller: performedByController,
                              decoration: const InputDecoration(
                                labelText: 'Service Shop (Optional)',
                                border: OutlineInputBorder(),
                              ),
                              textCapitalization: TextCapitalization.words,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: context.tokens.spacingM),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Performed Date: ${DateFormat('MMM d, yyyy').format(performedDate)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.calendar_today_rounded, size: 16),
                            label: const Text('Pick Date'),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: performedDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setModalState(() => performedDate = picked);
                              }
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: context.tokens.spacingM),
                      TextFormField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'Additional Notes (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      SizedBox(height: context.tokens.spacingL),
                      FilledButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;

                          final odo = int.parse(odoController.text);
                          final cost = double.tryParse(costController.text);

                          final record = MaintenanceRecord(
                            id: const Uuid().v4(),
                            vehicleId: _selectedVehicle!.id,
                            serviceType: selectedType,
                            odometerAtService: odo,
                            cost: cost,
                            performedBy: performedByController.text.trim().isEmpty
                                ? null
                                : performedByController.text.trim(),
                            performedAt: performedDate,
                            description: descriptionController.text.trim().isEmpty
                                ? null
                                : descriptionController.text.trim(),
                            notes: notesController.text.trim().isEmpty
                                ? null
                                : notesController.text.trim(),
                          );

                          await MaintenanceRepository.createRecord(record);

                          if (context.mounted) {
                            setState(() {
                              _currentOdometer = odo;
                            });
                            Navigator.pop(context);
                          }
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(context.tokens.shapeFull),
                          ),
                        ),
                        child: const Text('Log Service'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Maintenance',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectedVehicle == null ? null : _showLogServiceDialog,
        icon: const Icon(Icons.build_rounded),
        label: const Text('Log Service'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(tokens.spacingXL),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.directions_car_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        SizedBox(height: tokens.spacingM),
                        Text(
                          'No vehicles loaded',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        SizedBox(height: tokens.spacingXS),
                        Text(
                          'Vehicle profiles are synchronized from the dispatch portal.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: Column(
                    children: [
                      // Vehicle Picker Header
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: tokens.spacingM),
                        child: Row(
                          children: [
                            Text(
                              'Vehicle: ',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: tokens.textSecondary,
                                  ),
                            ),
                            const Spacer(),
                            DropdownButton<Vehicle>(
                              value: _selectedVehicle,
                              underline: const SizedBox(),
                              items: _vehicles
                                  .map((v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(
                                          'Truck #${v.truckNumber}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedVehicle = val;
                                  });
                                  _loadOdometerForVehicle(val.id);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      // Tab Bar
                      TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'Schedules & Reminders'),
                          Tab(text: 'Service History'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildSchedulesTab(),
                            _buildHistoryTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSchedulesTab() {
    if (_selectedVehicle == null) return const SizedBox.shrink();
    final tokens = context.tokens;

    return StreamBuilder<List<MaintenanceSchedule>>(
      stream: MaintenanceRepository.watchSchedules(_selectedVehicle!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final schedules = snapshot.data ?? [];

        if (schedules.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.playlist_add_check_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                SizedBox(height: tokens.spacingM),
                Text(
                  'No schedules set',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                SizedBox(height: tokens.spacingXS),
                Text(
                  'There are no active recurring reminders set.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(tokens.spacingM),
          itemCount: schedules.length,
          itemBuilder: (context, index) {
            final schedule = schedules[index];
            final isDue = schedule.isDue(currentOdometer: _currentOdometer);
            final dueInfo = schedule.getNextDueInfo(currentOdometer: _currentOdometer);

            return Card(
              key: ValueKey(schedule.id),
              elevation: 0,
              margin: EdgeInsets.only(bottom: tokens.spacingM),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.shapeM),
                side: BorderSide(
                  color: isDue
                      ? Theme.of(context).colorScheme.error.withValues(alpha: 0.5)
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: isDue ? 1.5 : 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(tokens.spacingM),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDue
                            ? Theme.of(context).colorScheme.errorContainer
                            : Theme.of(context).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(tokens.shapeM),
                      ),
                      child: Icon(
                        isDue ? Icons.warning_amber_rounded : Icons.schedule_rounded,
                        color: isDue
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(width: tokens.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            schedule.serviceType.displayName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          SizedBox(height: tokens.spacingXS),
                          Text(
                            isDue ? 'Due: $dueInfo' : 'Next due in: $dueInfo',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isDue
                                      ? Theme.of(context).colorScheme.error
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: isDue ? FontWeight.bold : FontWeight.normal,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    if (_selectedVehicle == null) return const SizedBox.shrink();
    final tokens = context.tokens;

    return StreamBuilder<List<MaintenanceRecord>>(
      stream: MaintenanceRepository.watchRecords(_selectedVehicle!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = snapshot.data ?? [];

        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                SizedBox(height: tokens.spacingM),
                Text(
                  'No service logs yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                SizedBox(height: tokens.spacingXS),
                Text(
                  'Tap "Log Service" below to record a service entry.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
            tokens.spacingM,
            tokens.spacingM,
            tokens.spacingM,
            tokens.spacingXL + 48,
          ),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            final dateStr = DateFormat('MMM d, yyyy').format(record.performedAt);
            final costStr = record.cost != null ? '\$${record.cost!.toStringAsFixed(2)}' : 'Free / N/A';

            return Card(
              key: ValueKey(record.id),
              elevation: 0,
              margin: EdgeInsets.only(bottom: tokens.spacingM),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.shapeM),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(tokens.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          record.serviceType.displayName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          costStr,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                        ),
                      ],
                    ),
                    if (record.description != null && record.description!.isNotEmpty) ...[
                      SizedBox(height: tokens.spacingS),
                      Text(
                        record.description!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    SizedBox(height: tokens.spacingM),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$dateStr  •  ${record.odometerAtService} mi',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (record.performedBy != null)
                          Text(
                            'Shop: ${record.performedBy}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
