import 'package:fluent_ui/fluent_ui.dart';
import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AddVehicleDialog extends StatefulWidget {
  final Map<String, dynamic>? vehicle;
  final VoidCallback onSaved;

  const AddVehicleDialog({super.key, this.vehicle, required this.onSaved});

  @override
  State<AddVehicleDialog> createState() => _AddVehicleDialogState();
}

class _AddVehicleDialogState extends State<AddVehicleDialog> {
  int _currentIndex = 0;
  bool _isLoading = false;
  String? _vehicleId; // Set if editing or after creation

  // Form Key
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _vehicleNumberController = TextEditingController();
  final _vinController = TextEditingController();
  final _plateController = TextEditingController();
  final _dotController = TextEditingController();
  final _insuranceController = TextEditingController();
  final _terminalController = TextEditingController();

  // Dropdowns
  String _vehicleType = 'Truck'; // Default
  String _licenseProvince = 'ON'; // Default

  // Documents
  List<Map<String, dynamic>> _documents = [];
  bool _isLoadingDocs = false;

  @override
  void initState() {
    super.initState();
    if (widget.vehicle != null) {
      _vehicleId = widget.vehicle!['id'];
      _vehicleNumberController.text = widget.vehicle!['vehicle_number'] ?? '';
      _vehicleType = widget.vehicle!['vehicle_type'] ?? 'Truck';
      _plateController.text = widget.vehicle!['license_plate'] ?? '';
      _licenseProvince = widget.vehicle!['license_province'] ?? 'ON';
      _vinController.text = widget.vehicle!['vin_number'] ?? '';
      _dotController.text = widget.vehicle!['dot_number'] ?? '';
      _insuranceController.text = widget.vehicle!['insurance_policy'] ?? '';
      _terminalController.text = widget.vehicle!['terminal_address'] ?? '';

      _fetchDocuments();
    }
  }

  Future<void> _fetchDocuments() async {
    if (_vehicleId == null) return;
    setState(() => _isLoadingDocs = true);
    try {
      final docs = await Supabase.instance.client
          .from('vehicle_documents')
          .select()
          .eq('vehicle_id', _vehicleId!)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _documents = List<Map<String, dynamic>>.from(docs);
        });
      }
    } catch (e) {
      debugPrint('Error fetching docs: $e');
    } finally {
      if (mounted) setState(() => _isLoadingDocs = false);
    }
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) {
      if (mounted) {
        // Validation failed, switch to first tab
        setState(() => _currentIndex = 0);
        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: const Text('Validation Error'),
              content: const Text(
                'Please check the Vehicle Details tab for errors.',
              ),
              severity: InfoBarSeverity.warning,
              onClose: close,
            );
          },
        );
      }
      return;
    }
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Fetch company_id from profile (or let trigger handle it, but better explicit if possible,
      // but we relied on trigger in SQL plan. Let's rely on trigger/RLS).
      // Trigger set_vehicle_company_id will handle company_id.

      final data = {
        'vehicle_number': _vehicleNumberController.text,
        'vehicle_type': _vehicleType,
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
        // If we were on Tab 0 creating, inform user and maybe switch tab or close
        if (widget.vehicle == null) {
          // New vehicle created
          displayInfoBar(
            context,
            builder: (context, close) {
              return InfoBar(
                title: const Text('Vehicle Saved'),
                content: const Text('You can now add documents.'),
                severity: InfoBarSeverity.success,
                onClose: close,
              );
            },
          );
          setState(() {}); // refresh UI to enable Docs tab
          // Optional: Auto switch to documents tab
          // setState(() => _currentIndex = 1);
        } else {
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
          // Close dialog if just editing
          widget.onSaved();
          return;
        }
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

  Future<void> _uploadDocument() async {
    if (_vehicleId == null) return;

    final type = await showDialog<String>(
      context: context,
      builder: (context) => _DocumentTypeDialog(),
    );
    if (type == null) return;

    const XTypeGroup typeGroup = XTypeGroup(
      label: 'documents',
      extensions: <String>['pdf', 'jpg', 'png', 'jpeg'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[typeGroup],
    );

    if (file != null) {
      setState(() => _isLoadingDocs = true);
      try {
        final bytes = await file.readAsBytes();
        final ext = file.name.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';

        // Fetch company_id first
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('company_id')
            .eq('id', Supabase.instance.client.auth.currentUser!.id)
            .single();
        final companyId = profile['company_id'];

        final path = '$companyId/$_vehicleId/$fileName';

        await Supabase.instance.client.storage
            .from('vehicle_documents')
            .uploadBinary(path, bytes);

        // Insert record
        await Supabase.instance.client.from('vehicle_documents').insert({
          'vehicle_id': _vehicleId,
          'company_id': companyId,
          'document_type': type,
          'file_path': path,
        });

        if (mounted) {
          displayInfoBar(
            context,
            builder: (context, close) {
              return InfoBar(
                title: const Text('Upload Success'),
                severity: InfoBarSeverity.success,
                onClose: close,
              );
            },
          );
        }

        _fetchDocuments();
      } catch (e) {
        if (mounted) {
          displayInfoBar(
            context,
            builder: (context, close) {
              return InfoBar(
                title: const Text('Upload Error'),
                content: Text(e.toString()),
                severity: InfoBarSeverity.error,
                onClose: close,
              );
            },
          );
        }
      } finally {
        if (mounted) setState(() => _isLoadingDocs = false);
      }
    }
  }

  Future<void> _deleteDocument(String id, String path) async {
    setState(() => _isLoadingDocs = true);
    try {
      await Supabase.instance.client.storage.from('vehicle_documents').remove([
        path,
      ]);
      await Supabase.instance.client
          .from('vehicle_documents')
          .delete()
          .eq('id', id);
      _fetchDocuments();
    } catch (e) {
      debugPrint('Error deleting doc: $e');
    } finally {
      if (mounted) setState(() => _isLoadingDocs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Text(widget.vehicle == null ? 'Add New Vehicle' : 'Edit Vehicle'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 500),
        child: Column(
          children: [
            Expanded(
              child: TabView(
                currentIndex: _currentIndex,
                onChanged: (index) => setState(() => _currentIndex = index),
                tabs: [
                  Tab(
                    text: const Text('Vehicle Details'),
                    body: _buildDetailsForm(),
                  ),
                  Tab(
                    text: const Text('Documents'),
                    body: _vehicleId == null
                        ? const Center(
                            child: Text(
                              'Please save the vehicle first to add documents.',
                            ),
                          )
                        : _buildDocumentsList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        Button(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _saveVehicle,
          child: _isLoading ? const ProgressRing() : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildDetailsForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'Vehicle (Unit) Number',
                    child: TextFormBox(
                      controller: _vehicleNumberController,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoLabel(
                    label: 'Vehicle Type',
                    child: ComboBox<String>(
                      value: _vehicleType,
                      items:
                          [
                                'Truck',
                                'Tractor',
                                'Trailer',
                                'Dry Van',
                                'Reefer',
                                'Car',
                              ]
                              .map(
                                (e) => ComboBoxItem(value: e, child: Text(e)),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _vehicleType = v!),
                      isExpanded: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'License Plate',
                    child: TextFormBox(controller: _plateController),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoLabel(
                    label: 'Province/State',
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
              ],
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'VIN Number',
              child: TextFormBox(
                controller: _vinController,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'DOT Number (Optional)',
              child: TextFormBox(controller: _dotController),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Insurance Policy (Optional)',
              child: TextFormBox(controller: _insuranceController),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Terminal Address',
              child: TextFormBox(controller: _terminalController),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsList() {
    if (_isLoadingDocs) {
      return const Center(child: ProgressRing());
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton(
            onPressed: _uploadDocument,
            child: const Text('Upload Document'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _documents.isEmpty
                ? const Center(child: Text('No documents found.'))
                : ListView.builder(
                    itemCount: _documents.length,
                    itemBuilder: (context, index) {
                      final doc = _documents[index];
                      return ListTile(
                        leading: const Icon(FluentIcons.pdf),
                        title: Text(doc['document_type'] ?? 'Document'),
                        subtitle: Text(
                          DateFormat(
                            'MMM d, yyyy',
                          ).format(DateTime.parse(doc['created_at'])),
                        ),
                        trailing: IconButton(
                          icon: const Icon(FluentIcons.delete),
                          onPressed: () =>
                              _deleteDocument(doc['id'], doc['file_path']),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DocumentTypeDialog extends StatefulWidget {
  @override
  State<_DocumentTypeDialog> createState() => _DocumentTypeDialogState();
}

class _DocumentTypeDialogState extends State<_DocumentTypeDialog> {
  String _type = 'Registration';
  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Select Document Type'),
      content: ComboBox<String>(
        value: _type,
        items: [
          'Registration',
          'Insurance',
          'Inspection',
          'Other',
        ].map((e) => ComboBoxItem(value: e, child: Text(e))).toList(),
        onChanged: (v) => setState(() => _type = v!),
        isExpanded: true,
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _type),
          child: const Text('Select'),
        ),
      ],
    );
  }
}
