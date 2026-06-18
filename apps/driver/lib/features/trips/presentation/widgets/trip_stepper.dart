import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/widgets/custom_autocomplete_field.dart';
import 'package:milow/core/widgets/load_details_section.dart';
import 'package:milow_core/milow_core.dart';

class TripStepper extends StatefulWidget {
  final VoidCallback onSave;
  final bool isSaving;
  final bool tripNumberExists;
  
  // Step 1: Core
  final TextEditingController tripNumberController;
  final TextEditingController truckNumberController;
  final FocusNode truckFocusNode;
  final TextEditingController tripDateController;
  final VoidCallback onPickDate;
  final Future<Iterable<String>> Function(String) getVehicleSuggestions;
  
  // Step 2: Logistics
  final List<TextEditingController> pickupControllers;
  final List<FocusNode> pickupFocusNodes;
  final List<TextEditingController> deliveryControllers;
  final List<FocusNode> deliveryFocusNodes;
  final List<Detention?> pickupDetention;
  final List<Detention?> deliveryDetention;
  final VoidCallback onAddPickup;
  final Function(int) onRemovePickup;
  final VoidCallback onAddDelivery;
  final Function(int) onRemoveDelivery;
  final Function(int, bool) onUpdateDetention;
  final Function(TextEditingController) onGetLocation;
  final Future<Iterable<String>> Function(String) getLocationSuggestions;

  // Step 3: Cargo
  final List<TextEditingController> trailerControllers;
  final List<FocusNode> trailerFocusNodes;
  final TextEditingController commodityController;
  final TextEditingController weightController;
  final TextEditingController piecesController;
  final String weightUnit;
  final List<TextEditingController> referenceNumberControllers;
  final VoidCallback onAddReferenceNumber;
  final Function(int) onRemoveReferenceNumber;
  final Function(String) onWeightUnitChanged;
  final VoidCallback onAddTrailer;
  final Function(int) onRemoveTrailer;

  // Step 4: Tracking
  final TextEditingController startOdometerController;
  final TextEditingController endOdometerController;
  final TextEditingController borderCrossingController;
  final TextEditingController notesController;
  final TextEditingController revenueController;
  final TextEditingController ratePerMileController;
  final String distanceUnit;
  final bool isEmptyLeg;
  final Function(bool) onEmptyLegChanged;
  final VoidCallback onShowAddBorderCrossing;

  const TripStepper({
    required this.onSave,
    required this.isSaving,
    required this.tripNumberExists,
    required this.tripNumberController,
    required this.truckNumberController,
    required this.truckFocusNode,
    required this.tripDateController,
    required this.onPickDate,
    required this.getVehicleSuggestions,
    required this.pickupControllers,
    required this.pickupFocusNodes,
    required this.deliveryControllers,
    required this.deliveryFocusNodes,
    required this.pickupDetention,
    required this.deliveryDetention,
    required this.onAddPickup,
    required this.onRemovePickup,
    required this.onAddDelivery,
    required this.onRemoveDelivery,
    required this.onUpdateDetention,
    required this.onGetLocation,
    required this.getLocationSuggestions,
    required this.trailerControllers,
    required this.trailerFocusNodes,
    required this.commodityController,
    required this.weightController,
    required this.piecesController,
    required this.weightUnit,
    required this.referenceNumberControllers,
    required this.onAddReferenceNumber,
    required this.onRemoveReferenceNumber,
    required this.onWeightUnitChanged,
    required this.onAddTrailer,
    required this.onRemoveTrailer,
    required this.startOdometerController,
    required this.endOdometerController,
    required this.borderCrossingController,
    required this.notesController,
    required this.revenueController,
    required this.ratePerMileController,
    required this.distanceUnit,
    required this.isEmptyLeg,
    required this.onEmptyLegChanged,
    required this.onShowAddBorderCrossing,
    super.key,
  });

  @override
  State<TripStepper> createState() => _TripStepperState();
}

class _TripStepperState extends State<TripStepper> {
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    widget.revenueController.addListener(_calculateRate);
    widget.startOdometerController.addListener(_calculateRate);
    widget.endOdometerController.addListener(_calculateRate);
    // Initial calculation if editing
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateRate());
  }

  @override
  void dispose() {
    widget.revenueController.removeListener(_calculateRate);
    widget.startOdometerController.removeListener(_calculateRate);
    widget.endOdometerController.removeListener(_calculateRate);
    super.dispose();
  }

  void _calculateRate() {
    if (!mounted) return;
    final revenue = double.tryParse(widget.revenueController.text.replaceAll(',', '')) ?? 0.0;
    final startOdo = double.tryParse(widget.startOdometerController.text.replaceAll(',', '')) ?? 0.0;
    final endOdo = double.tryParse(widget.endOdometerController.text.replaceAll(',', '')) ?? 0.0;

    if (revenue > 0 && endOdo > startOdo) {
      final rate = revenue / (endOdo - startOdo);
      widget.ratePerMileController.text = rate.toStringAsFixed(2);
    } else {
      widget.ratePerMileController.text = '';
    }
  }

  bool _validateStep(int step) {
    if (step == 0) {
      if (widget.tripNumberController.text.isEmpty) return false;
      if (widget.truckNumberController.text.isEmpty) return false;
    }
    if (step == 1) {
      if (widget.pickupControllers.every((c) => c.text.isEmpty)) return false;
      if (widget.deliveryControllers.every((c) => c.text.isEmpty)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    
    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      child: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        physics: const ClampingScrollPhysics(),
        onStepTapped: (step) {
          if (step < _currentStep || _validateStep(_currentStep)) {
            setState(() => _currentStep = step);
          }
        },
        onStepContinue: () {
          if (_currentStep < 3) {
            if (_validateStep(_currentStep)) {
              setState(() => _currentStep += 1);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please complete the required fields in this step'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } else {
            widget.onSave();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        controlsBuilder: (context, controls) {
          return Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: controls.onStepContinue,
                    icon: Icon(_isSaving ? null : (_currentStep == 3 ? Icons.save : Icons.arrow_forward)),
                    label: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_currentStep == 3 ? 'Finish & Save' : 'Next Step'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tokens.shapeL),
                      ),
                    ),
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: controls.onStepCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(tokens.shapeL),
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: Text('Trip Summary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            subtitle: const Text('Basics and vehicle identification'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.editing,
            content: Column(
              children: [
                SwitchListTile(
                  value: widget.isEmptyLeg,
                  onChanged: widget.onEmptyLegChanged,
                  title: const Text('Deadhead / Empty Leg'),
                  subtitle: const Text('No cargo for this movement'),
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(Icons.no_luggage_outlined,
                      color: widget.isEmptyLeg
                          ? Theme.of(context).colorScheme.primary
                          : null),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: widget.tripNumberController,
                  decoration: InputDecoration(
                    labelText: 'Trip Number *',
                    hintText: 'e.g. T-9921',
                    prefixIcon: const Icon(Icons.confirmation_number_outlined),
                    errorText: widget.tripNumberExists ? 'This trip number already exists' : null,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                CustomAutocompleteField(
                  controller: widget.truckNumberController,
                  focusNode: widget.truckFocusNode,
                  label: 'Truck Number *',
                  hint: 'e.g. 104',
                  prefixIcon: Icons.local_shipping_outlined,
                  optionsBuilder: (v) => widget.getVehicleSuggestions(v.text),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: widget.tripDateController,
                  decoration: const InputDecoration(
                    labelText: 'Start Date & Time',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  readOnly: true,
                  onTap: widget.onPickDate,
                ),
              ],
            ),
          ),
          Step(
            title: Text('Logistics (Stops)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            subtitle: const Text('Add pickup and delivery points'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.editing,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader('Pickups'),
                ..._buildLocationFields(true),
                const SizedBox(height: 24),
                _buildSectionHeader('Deliveries'),
                ..._buildLocationFields(false),
              ],
            ),
          ),
          Step(
            title: Text('Cargo & Manifest', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            subtitle: const Text('Trailers and cargo descriptions'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.editing,
            content: Column(
              children: [
                _buildSectionHeader('Equipment'),
                ..._buildTrailerFields(),
                const SizedBox(height: 24),
                LoadDetailsSection(
                  commodityController: widget.commodityController,
                  weightController: widget.weightController,
                  weightUnit: widget.weightUnit,
                  piecesController: widget.piecesController,
                  referenceNumberControllers: widget.referenceNumberControllers,
                  onAddReferenceNumber: widget.onAddReferenceNumber,
                  onRemoveReferenceNumber: widget.onRemoveReferenceNumber,
                  onWeightUnitChanged: widget.onWeightUnitChanged,
                ),
              ],
            ),
          ),
          Step(
            title: Text('Finalization', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            subtitle: const Text('Odometer readings and notes'),
            isActive: _currentStep >= 3,
            state: StepState.editing,
            content: Column(
              children: [
                _buildSectionHeader('Distance Monitoring'),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: widget.startOdometerController,
                        decoration: InputDecoration(
                          labelText: 'Start ODO',
                          suffixText: widget.distanceUnit,
                          prefixIcon: const Icon(Icons.speed_outlined),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: widget.endOdometerController,
                        decoration: InputDecoration(
                          labelText: 'End ODO',
                          suffixText: widget.distanceUnit,
                          prefixIcon: const Icon(Icons.flag_outlined),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('Financials'),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: widget.revenueController,
                        decoration: const InputDecoration(
                          labelText: 'Revenue / Pay',
                          prefixIcon: Icon(Icons.attach_money_rounded),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: widget.ratePerMileController,
                        decoration: InputDecoration(
                          labelText: 'Rate per ${widget.distanceUnit}',
                          prefixIcon: const Icon(Icons.calculate_outlined),
                        ),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('Crossing & Documentation'),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: widget.borderCrossingController,
                        decoration: const InputDecoration(
                          labelText: 'Border Crossing',
                          prefixIcon: Icon(Icons.public_outlined),
                        ),
                        readOnly: true,
                        onTap: widget.onShowAddBorderCrossing,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: widget.notesController,
                  decoration: const InputDecoration(
                    labelText: 'Trip Notes',
                    hintText: 'Any specific instructions or delays...',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _isSaving => widget.isSaving;

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLocationFields(bool isPickup) {
    final controllers = isPickup ? widget.pickupControllers : widget.deliveryControllers;
    final detentions = isPickup ? widget.pickupDetention : widget.deliveryDetention;
    final focusNodes = isPickup ? widget.pickupFocusNodes : widget.deliveryFocusNodes;
    
    return List.generate(controllers.length, (index) {
      final isLast = index == controllers.length - 1;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CustomAutocompleteField(
                controller: controllers[index],
                focusNode: focusNodes[index],
                label: '${isPickup ? "Stop" : "Unload"} ${index + 1}',
                hint: 'City, State',
                prefixIcon: Icons.location_on_outlined,
                suffixIcon: Icons.my_location,
                onSuffixTap: () => widget.onGetLocation(controllers[index]),
                optionsBuilder: (v) => widget.getLocationSuggestions(v.text),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                detentions[index] != null ? Icons.timer : Icons.timer_outlined,
                color: detentions[index] != null ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
              ),
              onPressed: () => widget.onUpdateDetention(index, isPickup),
              tooltip: 'Add Detention',
            ),
            if (controllers.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: Theme.of(context).colorScheme.error,
                onPressed: () => isPickup ? widget.onRemovePickup(index) : widget.onRemoveDelivery(index),
              ),
            if (isLast && controllers.length < 5)
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: Theme.of(context).colorScheme.primary,
                onPressed: isPickup ? widget.onAddPickup : widget.onAddDelivery,
              ),
          ],
        ),
      );
    });
  }

  List<Widget> _buildTrailerFields() {
    return List.generate(widget.trailerControllers.length, (index) {
      final isLast = index == widget.trailerControllers.length - 1;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: widget.trailerControllers[index],
                focusNode: widget.trailerFocusNodes[index],
                decoration: InputDecoration(
                  labelText: index == 0 ? 'Primary Trailer' : 'Secondary Trailer',
                  prefixIcon: const Icon(Icons.local_shipping_outlined),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ),
            if (widget.trailerControllers.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: Theme.of(context).colorScheme.error,
                onPressed: () => widget.onRemoveTrailer(index),
              ),
            if (isLast && widget.trailerControllers.length < 3)
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: Theme.of(context).colorScheme.primary,
                onPressed: widget.onAddTrailer,
              ),
          ],
        ),
      );
    });
  }
}
