import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';

class AddVehiclePage extends StatefulWidget {
  const AddVehiclePage({super.key});

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Sample data - in real app this would come from Supabase
  final List<Map<String, dynamic>> _trucks = [];
  final List<Map<String, dynamic>> _trailers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    // Load from Supabase (Mock implementation for now)
    // For now, using sample data
    if (mounted) {
      setState(() {
        _trucks.addAll([
          {
            'id': '1',
            'make': 'Freightliner',
            'model': 'Cascadia',
            'year': '2023',
            'plate': 'ABC1234',
            'plateState': 'CA',
            'color': 'White',
          },
        ]);
        _trailers.addAll([
          {
            'id': '1',
            'type': 'Dry Van',
            'make': 'Wabash',
            'model': 'DuraPlate',
            'year': '2022',
            'length': '53',
            'plate': 'TRL5678',
            'plateState': 'CA',
          },
        ]);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddTruckDialog() {
    final makeController = TextEditingController();
    final modelController = TextEditingController();
    final yearController = TextEditingController();
    final plateController = TextEditingController();
    final plateStateController = TextEditingController();
    final colorController = TextEditingController();
    final vinController = TextEditingController();
    final usdotController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddTruckSheet(
        makeController: makeController,
        modelController: modelController,
        yearController: yearController,
        plateController: plateController,
        plateStateController: plateStateController,
        colorController: colorController,
        vinController: vinController,
        usdotController: usdotController,
      ),
    ).then((_) {
      makeController.dispose();
      modelController.dispose();
      yearController.dispose();
      plateController.dispose();
      plateStateController.dispose();
      colorController.dispose();
      vinController.dispose();
      usdotController.dispose();
    });
  }

  void _showAddTrailerDialog() {
    final makeController = TextEditingController();
    final modelController = TextEditingController();
    final yearController = TextEditingController();
    final plateController = TextEditingController();
    final plateStateController = TextEditingController();
    final lengthController = TextEditingController();
    final vinController = TextEditingController();
    final String trailerType = 'Dry Van';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddTrailerSheet(
        makeController: makeController,
        modelController: modelController,
        yearController: yearController,
        plateController: plateController,
        plateStateController: plateStateController,
        lengthController: lengthController,
        vinController: vinController,
        initialType: trailerType,
      ),
    ).then((_) {
      makeController.dispose();
      modelController.dispose();
      yearController.dispose();
      plateController.dispose();
      plateStateController.dispose();
      lengthController.dispose();
      vinController.dispose();
    });
  }

  Widget _buildAddTruckSheet({
    required TextEditingController makeController,
    required TextEditingController modelController,
    required TextEditingController yearController,
    required TextEditingController plateController,
    required TextEditingController plateStateController,
    required TextEditingController colorController,
    required TextEditingController vinController,
    required TextEditingController usdotController,
  }) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: tokens.scaffoldAltBackground,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.shapeXL),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: tokens.spacingM),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: tokens.textTertiary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacingM,
              tokens.spacingS,
              tokens.spacingM,
              tokens.spacingS,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: tokens.surfaceContainer,
                    side: BorderSide(color: tokens.subtleBorderColor),
                  ),
                ),
                Text(
                  'Add Truck',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (makeController.text.isNotEmpty) {
                      setState(() {
                        _trucks.add({
                          'id': DateTime.now().millisecondsSinceEpoch
                              .toString(),
                          'make': makeController.text,
                          'model': modelController.text,
                          'year': yearController.text,
                          'plate': plateController.text,
                          'plateState': plateStateController.text,
                          'color': colorController.text,
                          'vin': vinController.text,
                          'usdot': usdotController.text,
                        });
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Truck added successfully'),
                          backgroundColor: tokens.success,
                        ),
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacingL,
                      vertical: tokens.spacingM,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.shapeM),
                    ),
                  ),
                  child: Text(
                    'Save',
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.subtleBorderColor),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(tokens.spacingM),
              child: Column(
                children: [
                  _buildSectionCard(
                    title: 'Vehicle Identity',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildSheetTextField(
                              controller: makeController,
                              label: 'Make *',
                              hint: 'Freightliner',
                              icon: Icons.factory_outlined,
                            ),
                          ),
                          SizedBox(width: tokens.spacingM),
                          Expanded(
                            child: _buildSheetTextField(
                              controller: modelController,
                              label: 'Model',
                              hint: 'Cascadia',
                              icon: Icons.directions_car_outlined,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: tokens.spacingM),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSheetTextField(
                              controller: yearController,
                              label: 'Year',
                              hint: '2024',
                              icon: Icons.calendar_today_outlined,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: tokens.spacingM),
                          Expanded(
                            child: _buildSheetTextField(
                              controller: colorController,
                              label: 'Color',
                              hint: 'White',
                              icon: Icons.palette_outlined,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Registration & Compliance',
                    children: [
                      _buildSheetTextField(
                        controller: vinController,
                        label: 'VIN',
                        hint: '17-character VIN',
                        icon: Icons.qr_code_outlined,
                        textCapitalization: TextCapitalization.characters,
                      ),
                      SizedBox(height: tokens.spacingM),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildSheetTextField(
                              controller: plateController,
                              label: 'License Plate',
                              hint: 'Plate number',
                              icon: Icons.credit_card_outlined,
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),
                          SizedBox(width: tokens.spacingM),
                          Expanded(
                            child: _buildSheetTextField(
                              controller: plateStateController,
                              label: 'State',
                              hint: 'CA',
                              icon: Icons.location_on_outlined,
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: tokens.spacingM),
                      _buildSheetTextField(
                        controller: usdotController,
                        label: 'USDOT Number',
                        hint: 'DOT number',
                        icon: Icons.numbers_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTrailerSheet({
    required TextEditingController makeController,
    required TextEditingController modelController,
    required TextEditingController yearController,
    required TextEditingController plateController,
    required TextEditingController plateStateController,
    required TextEditingController lengthController,
    required TextEditingController vinController,
    required String initialType,
  }) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    String selectedType = initialType;

    return StatefulBuilder(
      builder: (context, setSheetState) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: tokens.scaffoldAltBackground,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.shapeXL),
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: tokens.spacingM),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacingM,
                tokens.spacingS,
                tokens.spacingM,
                tokens.spacingS,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: tokens.surfaceContainer,
                      side: BorderSide(color: tokens.subtleBorderColor),
                    ),
                  ),
                  Text(
                    'Add Trailer',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      if (makeController.text.isNotEmpty ||
                          selectedType.isNotEmpty) {
                        setState(() {
                          _trailers.add({
                            'id': DateTime.now().millisecondsSinceEpoch
                                .toString(),
                            'type': selectedType,
                            'make': makeController.text,
                            'model': modelController.text,
                            'year': yearController.text,
                            'length': lengthController.text,
                            'plate': plateController.text,
                            'plateState': plateStateController.text,
                            'vin': vinController.text,
                          });
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Trailer added successfully'),
                            backgroundColor: tokens.success,
                          ),
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.spacingL,
                        vertical: tokens.spacingM,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tokens.shapeM),
                      ),
                    ),
                    child: Text(
                      'Save',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: tokens.subtleBorderColor),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(tokens.spacingM),
                child: Column(
                  children: [
                    _buildSectionCard(
                      title: 'Trailer Config',
                      children: [
                        _buildLabel('Trailer Type'),
                        _buildTrailerTypeSelector(
                          selectedType: selectedType,
                          onChanged: (type) {
                            setSheetState(() => selectedType = type);
                          },
                        ),
                      ],
                    ),
                    _buildSectionCard(
                      title: 'Vehicle Identity',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildSheetTextField(
                                controller: makeController,
                                label: 'Make',
                                hint: 'Wabash',
                                icon: Icons.factory_outlined,
                              ),
                            ),
                            SizedBox(width: tokens.spacingM),
                            Expanded(
                              child: _buildSheetTextField(
                                controller: modelController,
                                label: 'Model',
                                hint: 'DuraPlate',
                                icon: Icons.directions_car_outlined,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: tokens.spacingM),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSheetTextField(
                                controller: yearController,
                                label: 'Year',
                                hint: '2024',
                                icon: Icons.calendar_today_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            SizedBox(width: tokens.spacingM),
                            Expanded(
                              child: _buildSheetTextField(
                                controller: lengthController,
                                label: 'Length (ft)',
                                hint: '53',
                                icon: Icons.straighten_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    _buildSectionCard(
                      title: 'Registration',
                      children: [
                        _buildSheetTextField(
                          controller: vinController,
                          label: 'VIN',
                          hint: '17-character VIN',
                          icon: Icons.qr_code_outlined,
                          textCapitalization: TextCapitalization.characters,
                        ),
                        SizedBox(height: tokens.spacingM),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildSheetTextField(
                                controller: plateController,
                                label: 'License Plate',
                                hint: 'Plate number',
                                icon: Icons.credit_card_outlined,
                                textCapitalization:
                                    TextCapitalization.characters,
                              ),
                            ),
                            SizedBox(width: tokens.spacingM),
                            Expanded(
                              child: _buildSheetTextField(
                                controller: plateStateController,
                                label: 'State',
                                hint: 'CA',
                                icon: Icons.location_on_outlined,
                                textCapitalization:
                                    TextCapitalization.characters,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).viewInsets.bottom + 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: EdgeInsets.only(bottom: tokens.spacingL),
      decoration: BoxDecoration(
        color: tokens.surfaceContainer,
        borderRadius: BorderRadius.circular(tokens.shapeL),
        border: Border.all(color: tokens.subtleBorderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacingM,
              tokens.spacingM,
              tokens.spacingM,
              tokens.spacingS,
            ),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: colorScheme.primary,
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: tokens.subtleBorderColor),
          Padding(
            padding: EdgeInsets.all(tokens.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacingS, left: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: tokens.textSecondary,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
  }) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      hintText: hint,
      hintStyle: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: tokens.textTertiary),
      prefixIcon: Icon(prefixIcon, color: colorScheme.primary, size: 20),
      suffixIcon: suffixIcon != null
          ? IconButton(
              icon: Icon(suffixIcon, color: tokens.textTertiary, size: 18),
              onPressed: onSuffixTap,
            )
          : null,
      filled: true,
      fillColor: tokens.inputBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.shapeM),
        borderSide: BorderSide(color: tokens.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.shapeM),
        borderSide: BorderSide(color: tokens.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.shapeM),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: tokens.spacingM,
        vertical: tokens.spacingM,
      ),
    );
  }

  Widget _buildTrailerTypeSelector({
    required String selectedType,
    required ValueChanged<String> onChanged,
  }) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;
    final types = [
      'Dry Van',
      'Flatbed',
      'Reefer',
      'Step Deck',
      'Lowboy',
      'Tanker',
      'Container',
    ];

    return Wrap(
      spacing: tokens.spacingS,
      runSpacing: tokens.spacingS,
      children: types.map((type) {
        final isSelected = selectedType == type;
        return GestureDetector(
          onTap: () => onChanged(type),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacingM,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected ? colorScheme.primary : tokens.surfaceContainer,
              borderRadius: BorderRadius.circular(tokens.shapeL),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : tokens.subtleBorderColor,
              ),
            ),
            child: Text(
              type,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: isSelected ? colorScheme.onPrimary : tokens.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSheetTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: tokens.textPrimary),
          decoration: _inputDecoration(hint: hint, prefixIcon: icon),
        ),
      ],
    );
  }

  void _deleteTruck(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Truck',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        content: const Text('Are you sure you want to delete this truck?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _trucks.removeWhere((truck) => truck['id'] == id);
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: context.tokens.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteTrailer(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Trailer',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        content: const Text('Are you sure you want to delete this trailer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _trailers.removeWhere((trailer) => trailer['id'] == id);
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: context.tokens.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: tokens.scaffoldAltBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: tokens.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Vehicles',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: tokens.textSecondary,
          indicatorColor: colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(text: 'Trucks'),
            Tab(text: 'Trailers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Trucks Tab
          _trucks.isEmpty
              ? _buildEmptyState(
                  'No trucks added yet',
                  Icons.local_shipping_outlined,
                )
              : ListView.builder(
                  padding: EdgeInsets.all(tokens.spacingM),
                  itemCount: _trucks.length,
                  itemBuilder: (context, index) {
                    final truck = _trucks[index];
                    return _buildVehicleCard(
                      title: '${truck['make']} ${truck['model']}',
                      subtitle: '${truck['year']} • ${truck['color']}',
                      details: [
                        'Plate: ${truck['plate']} (${truck['plateState']})',
                        'VIN: ${truck['vin'] ?? 'N/A'}',
                      ],
                      onDelete: () => _deleteTruck(truck['id']),
                    );
                  },
                ),

          // Trailers Tab
          _trailers.isEmpty
              ? _buildEmptyState(
                  'No trailers added yet',
                  Icons.local_shipping_outlined,
                )
              : ListView.builder(
                  padding: EdgeInsets.all(tokens.spacingM),
                  itemCount: _trailers.length,
                  itemBuilder: (context, index) {
                    final trailer = _trailers[index];
                    return _buildVehicleCard(
                      title: '${trailer['make']} ${trailer['model']}',
                      subtitle: '${trailer['year']} • ${trailer['type']}',
                      details: [
                        'Plate: ${trailer['plate']} (${trailer['plateState']})',
                        'Length: ${trailer['length']} ft',
                      ],
                      onDelete: () => _deleteTrailer(trailer['id']),
                    );
                  },
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddTruckDialog();
          } else {
            _showAddTrailerDialog();
          }
        },
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          _tabController.index == 0 ? 'Add Truck' : 'Add Trailer',
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildVehicleCard({
    required String title,
    required String subtitle,
    required List<String> details,
    required VoidCallback onDelete,
  }) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: EdgeInsets.only(bottom: tokens.spacingM),
      padding: EdgeInsets.all(tokens.spacingM),
      decoration: BoxDecoration(
        color: tokens.surfaceContainer,
        borderRadius: BorderRadius.circular(tokens.shapeL),
        border: Border.all(color: tokens.subtleBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: tokens.error),
                onPressed: onDelete,
              ),
            ],
          ),
          SizedBox(height: tokens.spacingM),
          Wrap(
            spacing: tokens.spacingS,
            runSpacing: tokens.spacingXS,
            children: details.map((detail) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: tokens.scaffoldAltBackground,
                  borderRadius: BorderRadius.circular(tokens.shapeS),
                  border: Border.all(color: tokens.subtleBorderColor),
                ),
                child: Text(
                  detail,
                  style: textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(tokens.spacingXL),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: colorScheme.primary),
          ),
          SizedBox(height: tokens.spacingL),
          Text(
            message,
            style: textTheme.titleMedium?.copyWith(
              color: tokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
