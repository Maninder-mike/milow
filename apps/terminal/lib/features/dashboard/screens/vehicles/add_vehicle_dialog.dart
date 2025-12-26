import 'package:fluent_ui/fluent_ui.dart';
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
  String _licenseProvince = 'ON'; // Default
  String _status = 'Active'; // Default

  @override
  void initState() {
    super.initState();
    if (widget.vehicle != null) {
      _vehicleId = widget.vehicle!['id'];
      _vehicleNumberController.text = widget.vehicle!['vehicle_number'] ?? '';
      _plateController.text = widget.vehicle!['license_plate'] ?? '';
      _licenseProvince = widget.vehicle!['license_province'] ?? 'ON';
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
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24), // Standard Windows dialog padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Identification', FluentIcons.return_key),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'Vehicle ID / Unit #',
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    child: _WindowsStyledInput(
                      controller: _vehicleNumberController,
                      placeholder: 'e.g. 101',
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                ),
                const SizedBox(width: 16), // Standard gutter
                Expanded(
                  child: InfoLabel(
                    label: 'VIN Number',
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    child: _WindowsStyledInput(
                      controller: _vinController,
                      placeholder: '17-digit VIN',
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoLabel(
                    label: 'Vehicle Type',
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                    (e) =>
                                        ComboBoxItem(value: e, child: Text(e)),
                                  )
                                  .toList(),
                          onChanged: (v) => setState(() => _vehicleType = v!),
                          isExpanded: true,
                        ),
                        if (_vehicleType == 'Other') ...[
                          const SizedBox(height: 8),
                          _WindowsStyledInput(
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
                ),
              ],
            ),
            const SizedBox(height: 32),

            _buildSectionHeader('Specifications', FluentIcons.info),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'Year',
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    child: _WindowsStyledInput(
                      controller: _yearController,
                      placeholder: 'YYYY',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoLabel(
                    label: 'Make',
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    child: _WindowsStyledInput(
                      controller: _makeController,
                      placeholder: 'e.g. Freightliner',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoLabel(
                    label: 'Model',
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    child: _WindowsStyledInput(
                      controller: _modelController,
                      placeholder: 'e.g. Cascadia',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            _buildSectionHeader(
              'Registration & Compliance',
              FluentIcons.certificate,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'License Plate',
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    child: _WindowsStyledInput(
                      controller: _plateController,
                      placeholder: 'Plate Number',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoLabel(
                    label: 'Jurisdiction',
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    child: ComboBox<String>(
                      value: _licenseProvince,
                      items: ['ON', 'BC', 'AB', 'QC', 'NY', 'MI', 'TX', 'CA']
                          .map((e) => ComboBoxItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() => _licenseProvince = v!),
                      isExpanded: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoLabel(
                    label: 'DOT Number',
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    child: _WindowsStyledInput(
                      controller: _dotController,
                      placeholder: 'USDOT or Carrier ID',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            _buildSectionHeader('Status & Insurance', FluentIcons.health),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'Current Status',
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    child: ComboBox<String>(
                      value: _status,
                      items: ['Active', 'Maintenance', 'Inactive']
                          .map((e) => ComboBoxItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() => _status = v!),
                      isExpanded: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2, // Wider for insurance
                  child: InfoLabel(
                    label: 'Insurance Policy',
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    child: _WindowsStyledInput(
                      controller: _insuranceController,
                      placeholder: 'Policy Number',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            InfoLabel(
              label: 'Terminal Address',
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              child: _WindowsStyledInput(
                controller: _terminalController,
                placeholder: 'Full garaging address',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: FluentTheme.of(context).accentColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: FluentTheme.of(context).resources.textFillColorPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 1,
          color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
        ),
      ],
    );
  }
}

class _WindowsStyledInput extends StatefulWidget {
  final TextEditingController controller;
  final String? placeholder;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const _WindowsStyledInput({
    required this.controller,
    this.placeholder,
    this.validator,
    this.keyboardType,
  });

  @override
  State<_WindowsStyledInput> createState() => _WindowsStyledInputState();
}

class _WindowsStyledInputState extends State<_WindowsStyledInput> {
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;

    final bgColor = isLight ? Colors.white : const Color(0xFF2D2D2D);
    final borderColor = isLight
        ? const Color(0xFFE5E5E5)
        : const Color(0xFF404040);
    final focusBorderColor = theme.accentColor;
    final placeholderColor = isLight
        ? const Color(0xFF6E6E6E)
        : const Color(0xFF9E9E9E);

    return FormField<String>(
      validator: widget.validator,
      initialValue: widget.controller.text,
      builder: (FormFieldState<String> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 32,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: state.hasError
                      ? Colors.red
                      : (_isFocused ? focusBorderColor : borderColor),
                  width: _isFocused || state.hasError ? 1.5 : 1,
                ),
              ),
              child: TextBox(
                controller: widget.controller,
                focusNode: _focusNode,
                keyboardType: widget.keyboardType,
                style: TextStyle(
                  color: isLight ? Colors.black : Colors.white,
                  fontSize: 13,
                ),
                placeholder: widget.placeholder,
                placeholderStyle: TextStyle(
                  color: placeholderColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: WidgetStateProperty.all(
                  BoxDecoration(
                    color: Colors.transparent,
                    border: Border.fromBorderSide(BorderSide.none),
                  ),
                ),
                highlightColor: Colors.transparent,
                unfocusedColor: Colors.transparent,
                onChanged: (text) {
                  state.didChange(text);
                },
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 2),
                child: Text(
                  state.errorText!,
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
