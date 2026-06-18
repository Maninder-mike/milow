import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/incident_repository.dart';
import 'package:milow_core/milow_core.dart';
import 'package:uuid/uuid.dart';

class IncidentReportPage extends StatefulWidget {
  const IncidentReportPage({super.key});

  @override
  State<IncidentReportPage> createState() => _IncidentReportPageState();
}

class _IncidentReportPageState extends State<IncidentReportPage> {
  int _currentStep = 0;
  final _formKey1 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  // Step 1 controllers
  DateTime _incidentDate = DateTime.now();
  TimeOfDay _incidentTime = TimeOfDay.now();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _fetchingLocation = false;

  // Step 2 state
  final List<String> _photoPaths = [];
  final _picker = ImagePicker();

  // Step 3 controllers
  final _reportNumberController = TextEditingController();
  final _departmentController = TextEditingController();
  final _thirdPartyNameController = TextEditingController();
  final _thirdPartyPhoneController = TextEditingController();
  final _thirdPartyInsuranceController = TextEditingController();
  final _thirdPartyPolicyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _autofillLocation();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    _reportNumberController.dispose();
    _departmentController.dispose();
    _thirdPartyNameController.dispose();
    _thirdPartyPhoneController.dispose();
    _thirdPartyInsuranceController.dispose();
    _thirdPartyPolicyController.dispose();
    super.dispose();
  }

  Future<void> _autofillLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
        setState(() {
          _locationController.text = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        });
      }
    } catch (_) {}
    setState(() => _fetchingLocation = false);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 70);
      if (file != null) {
        setState(() {
          _photoPaths.add(file.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture photo: $e')),
        );
      }
    }
  }

  void _submitReport() async {
    if (!_formKey3.currentState!.validate()) return;

    final date = DateTime(
      _incidentDate.year,
      _incidentDate.month,
      _incidentDate.day,
      _incidentTime.hour,
      _incidentTime.minute,
    );

    final thirdPartyInfo = {
      'name': _thirdPartyNameController.text.trim(),
      'phone': _thirdPartyPhoneController.text.trim(),
      'insurance_company': _thirdPartyInsuranceController.text.trim(),
      'policy_number': _thirdPartyPolicyController.text.trim(),
    };

    final incident = Incident(
      id: const Uuid().v4(),
      userId: '', // Populated by repository
      incidentDate: date,
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      description: _descriptionController.text.trim(),
      policeReportNumber: _reportNumberController.text.trim().isEmpty ? null : _reportNumberController.text.trim(),
      policeDepartment: _departmentController.text.trim().isEmpty ? null : _departmentController.text.trim(),
      thirdPartyInfo: thirdPartyInfo,
      photos: _photoPaths,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final result = await IncidentRepository.createIncident(incident);

    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save report: ${failure.message}')),
          );
        }
      },
      (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incident report filed successfully!')),
          );
          Navigator.pop(context);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;

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
          'Report Incident',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            _buildStepperProgress(),
            Expanded(
              child: _buildCurrentStepView(),
            ),
            _buildNavigationRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperProgress() {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacingM,
        vertical: tokens.spacingS,
      ),
      child: Row(
        children: List.generate(3, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;

          return Expanded(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Theme.of(context).colorScheme.primary
                        : isCurrent
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCompleted
                            ? Theme.of(context).colorScheme.onPrimary
                            : isCurrent
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
                if (index < 2)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: index < _currentStep
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Info();
      case 1:
        return _buildStep2Photos();
      case 2:
        return _buildStep3ThirdParty();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1Info() {
    final tokens = context.tokens;
    return Form(
      key: _formKey1,
      child: ListView(
        padding: EdgeInsets.all(tokens.spacingM),
        children: [
          Text(
            'Step 1: Incident details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: tokens.spacingM),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range_rounded),
                  label: Text(DateFormat('MMM d, yyyy').format(_incidentDate)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _incidentDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 90)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _incidentDate = picked);
                    }
                  },
                ),
              ),
              SizedBox(width: tokens.spacingM),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.access_time_rounded),
                  label: Text(_incidentTime.format(context)),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _incidentTime,
                    );
                    if (picked != null) {
                      setState(() => _incidentTime = picked);
                    }
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacingM),
          TextFormField(
            controller: _locationController,
            decoration: InputDecoration(
              labelText: 'Location / Address',
              border: const OutlineInputBorder(),
              suffixIcon: _fetchingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.my_location_rounded),
                      onPressed: _autofillLocation,
                    ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Location is required';
              }
              return null;
            },
          ),
          SizedBox(height: tokens.spacingM),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'What happened?',
              alignLabelWithHint: true,
              hintText: 'Provide a brief explanation of the incident...',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Description is required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Photos() {
    final tokens = context.tokens;
    return ListView(
      padding: EdgeInsets.all(tokens.spacingM),
      children: [
        Text(
          'Step 2: Photo evidence',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        SizedBox(height: tokens.spacingS),
        Text(
          'Capture photos of the vehicles, damage, road conditions, and licence plates.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        SizedBox(height: tokens.spacingL),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Take Photo'),
                onPressed: () => _pickImage(ImageSource.camera),
              ),
            ),
            SizedBox(width: tokens.spacingM),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('From Gallery'),
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.spacingL),
        if (_photoPaths.isEmpty)
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(tokens.shapeM),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                style: BorderStyle.solid,
              ),
            ),
            child: const Center(
              child: Text(
                'No photos added yet',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: tokens.spacingS,
              mainAxisSpacing: tokens.spacingS,
            ),
            itemCount: _photoPaths.length,
            itemBuilder: (context, index) {
              final path = _photoPaths[index];
              return Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(tokens.shapeS),
                      child: Image.file(
                        File(path),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _photoPaths.removeAt(index);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildStep3ThirdParty() {
    final tokens = context.tokens;
    return Form(
      key: _formKey3,
      child: ListView(
        padding: EdgeInsets.all(tokens.spacingM),
        children: [
          Text(
            'Step 3: Police & third party details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: tokens.spacingM),
          TextFormField(
            controller: _reportNumberController,
            decoration: const InputDecoration(
              labelText: 'Police Report Number (Optional)',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          SizedBox(height: tokens.spacingM),
          TextFormField(
            controller: _departmentController,
            decoration: const InputDecoration(
              labelText: 'Police Department / Precinct (Optional)',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          SizedBox(height: tokens.spacingM),
          const Divider(),
          SizedBox(height: tokens.spacingM),
          Text(
            'Third Party / Other Driver',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: tokens.spacingM),
          TextFormField(
            controller: _thirdPartyNameController,
            decoration: const InputDecoration(
              labelText: 'Driver Name (Optional)',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          SizedBox(height: tokens.spacingM),
          TextFormField(
            controller: _thirdPartyPhoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number (Optional)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          SizedBox(height: tokens.spacingM),
          TextFormField(
            controller: _thirdPartyInsuranceController,
            decoration: const InputDecoration(
              labelText: 'Insurance Provider (Optional)',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          SizedBox(height: tokens.spacingM),
          TextFormField(
            controller: _thirdPartyPolicyController,
            decoration: const InputDecoration(
              labelText: 'Policy Number (Optional)',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRow() {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.all(tokens.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: () {
                setState(() => _currentStep--);
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              child: const Text('Back'),
            )
          else
            const SizedBox.shrink(),
          FilledButton(
            onPressed: () {
              if (_currentStep == 0) {
                if (_formKey1.currentState!.validate()) {
                  setState(() => _currentStep++);
                }
              } else if (_currentStep == 1) {
                setState(() => _currentStep++);
              } else {
                _submitReport();
              }
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            child: Text(_currentStep < 2 ? 'Next' : 'Submit'),
          ),
        ],
      ),
    );
  }
}
