import 'package:fluent_ui/fluent_ui.dart';
import 'package:terminal/core/constants/location_data.dart';
import 'package:terminal/core/widgets/form_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddVehicleDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? vehicle;
  final VoidCallback onSaved;

  const AddVehicleDialog({super.key, this.vehicle, required this.onSaved});

  @override
  ConsumerState<AddVehicleDialog> createState() => _AddVehicleDialogState();
}

class _AddVehicleDialogState extends ConsumerState<AddVehicleDialog> {
  bool _isLoading = false;
  String? _vehicleId;

  // Form Key
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _vehicleNumberController = TextEditingController();
  final _vinController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _plateController = TextEditingController();
  final _dotController = TextEditingController();
  final _insuranceController = TextEditingController();
  final _terminalController = TextEditingController();
  final _customTypeController = TextEditingController();

  // Dropdowns
  String _vehicleType = 'Truck'; // Default
  String _licenseProvince = 'Ontario'; // Default
  String _status = 'Active'; // Default
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    if (widget.vehicle != null) {
      _vehicleId = widget.vehicle!['id'];
      _vehicleNumberController.text = widget.vehicle!['vehicle_number'] ?? '';
      _plateController.text = widget.vehicle!['license_plate'] ?? '';
      String prov = widget.vehicle!['license_province'] ?? 'Ontario';
      // Attempt to map code to full name if it matches a key
      if (prov.length == 2) {
        final code = prov.toUpperCase();
        if (LocationData.canadianProvinces.containsKey(code)) {
          prov = LocationData.canadianProvinces[code]!;
        } else if (LocationData.usStates.containsKey(code)) {
          prov = LocationData.usStates[code]!;
        }
      }
      _licenseProvince = prov;

      _vinController.text = widget.vehicle!['vin_number'] ?? '';
      _makeController.text = widget.vehicle!['make'] ?? '';
      _modelController.text = widget.vehicle!['model'] ?? '';
      _yearController.text = widget.vehicle!['year']?.toString() ?? '';
      _status = widget.vehicle!['status'] ?? 'Active';
      _dotController.text = widget.vehicle!['dot_number'] ?? '';
      _insuranceController.text = widget.vehicle!['insurance_policy'] ?? '';
      _terminalController.text = widget.vehicle!['terminal_address'] ?? '';

      final type = widget.vehicle!['vehicle_type'] ?? 'Truck';
      const standardTypes = ['Truck', 'Trailer', 'Dry Van', 'Reefer', 'Car'];
      if (standardTypes.contains(type)) {
        _vehicleType = type;
      } else {
        _vehicleType = 'Other';
        _customTypeController.text = type;
      }
    }
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _vinController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    _dotController.dispose();
    _insuranceController.dispose();
    _terminalController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  Future<void> _saveVehicle() async {
    setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final data = {
        'vehicle_number': _vehicleNumberController.text,
        'vehicle_type': _vehicleType == 'Other'
            ? _customTypeController.text
            : _vehicleType,
        'make': _makeController.text,
        'model': _modelController.text,
        'year': int.tryParse(_yearController.text),
        'status': _status,
        'license_plate': _plateController.text,
        'license_province': _licenseProvince,
        'vin_number': _vinController.text,
        'dot_number': _dotController.text,
        'insurance_policy': _insuranceController.text,
        'terminal_address': _terminalController.text,
        if (_vehicleId == null) 'created_by': user.id,
      };

      if (_vehicleId != null) {
        await Supabase.instance.client
            .from('vehicles')
            .update(data)
            .eq('id', _vehicleId!);
      } else {
        final res = await Supabase.instance.client
            .from('vehicles')
            .insert(data)
            .select()
            .single();
        _vehicleId = res['id'];
      }

      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: const Text('Saved'),
              severity: InfoBarSeverity.success,
              onClose: close,
            );
          },
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: const Text('Error'),
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

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 1050, maxHeight: 800),
      title: Text(
        widget.vehicle == null ? 'Add New Vehicle' : 'Edit Vehicle',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      ),
      content: Column(children: [Expanded(child: _buildDetailsForm())]),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Button(
              style: ButtonStyle(
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: ButtonStyle(
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                ),
              ),
              onPressed: _isLoading ? null : _saveVehicle,
              child: _isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: ProgressRing(strokeWidth: 2.5),
                    )
                  : const Text(
                      'Save Vehicle',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailsForm() {
    return Form(
      key: _formKey,
      autovalidateMode: _autovalidateMode,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24), // Standard Windows dialog padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FluentSectionHeader(
              title: 'Identification',
              icon: FluentIcons.return_key,
              showDivider: true,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FluentLabeledInput(
                    label: 'Vehicle ID / Unit #',
                    controller: _vehicleNumberController,
                    placeholder: 'e.g. 101',
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16), // Standard gutter
                Expanded(
                  child: FluentLabeledInput(
                    label: 'VIN Number',
                    controller: _vinController,
                    placeholder: '17-digit VIN',
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 4),
                        child: Text(
                          'Vehicle Type',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors
                                .grey, // Approximate, matching shared widget
                          ),
                        ),
                      ),
                      ComboBox<String>(
                        value: _vehicleType,
                        items:
                            [
                                  'Truck',
                                  'Trailer',
                                  'Dry Van',
                                  'Reefer',
                                  'Car',
                                  'Other',
                                ]
                                .map(
                                  (e) => ComboBoxItem(value: e, child: Text(e)),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => _vehicleType = v!),
                        isExpanded: true,
                      ),
                      if (_vehicleType == 'Other') ...[
                        const SizedBox(height: 8),
                        TextFormBox(
                          controller: _customTypeController,
                          placeholder: 'Specify Type',
                          validator: (v) =>
                              _vehicleType == 'Other' &&
                                  (v == null || v.isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            const FluentSectionHeader(
              title: 'Specifications',
              icon: FluentIcons.info,
              showDivider: true,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FluentLabeledInput(
                    label: 'Year',
                    controller: _yearController,
                    placeholder: 'YYYY',
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FluentLabeledInput(
                    label: 'Make',
                    controller: _makeController,
                    placeholder: 'e.g. Freightliner',
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FluentLabeledInput(
                    label: 'Model',
                    controller: _modelController,
                    placeholder: 'e.g. Cascadia',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            const FluentSectionHeader(
              title: 'Registration & Compliance',
              icon: FluentIcons.certificate,
              showDivider: true,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FluentLabeledInput(
                    label: 'License Plate',
                    controller: _plateController,
                    placeholder: 'Plate Number',
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 4),
                        child: Text(
                          'Jurisdiction',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      ComboBox<String>(
                        value: _licenseProvince,
                        items: [
                          // Canada
                          ...LocationData.canadianProvinces.entries.map(
                            (e) => ComboBoxItem(
                              value: e.value,
                              child: Text('${e.key} - ${e.value}'),
                            ),
                          ),
                          // USA
                          ...LocationData.usStates.entries.map(
                            (e) => ComboBoxItem(
                              value: e.value,
                              child: Text('${e.key} - ${e.value}'),
                            ),
                          ),
                        ].toList(),
                        onChanged: (v) => setState(() => _licenseProvince = v!),
                        isExpanded: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FluentLabeledInput(
                    label: 'DOT Number',
                    controller: _dotController,
                    placeholder: 'USDOT or Carrier ID',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            const FluentSectionHeader(
              title: 'Status & Insurance',
              icon: FluentIcons.health,
              showDivider: true,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 4),
                        child: Text(
                          'Current Status',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      ComboBox<String>(
                        value: _status,
                        items: ['Active', 'Maintenance', 'Idle', 'Breakdown']
                            .map((e) => ComboBoxItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => _status = v!),
                        isExpanded: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2, // Wider for insurance
                  child: FluentLabeledInput(
                    label: 'Insurance Policy',
                    controller: _insuranceController,
                    placeholder: 'Policy Number',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FluentLabeledInput(
              label: 'Terminal Address',
              controller: _terminalController,
              placeholder: 'Full garaging address',
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
          ],
        ),
      ),
    );
  }
}
