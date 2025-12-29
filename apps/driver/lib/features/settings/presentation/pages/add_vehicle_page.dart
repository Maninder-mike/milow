import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? const Color(0xFF1E293B)
                        : Colors.white,
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                Text(
                  'Add Truck',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
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
                        const SnackBar(
                          content: Text('Truck added successfully'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
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
                              isDark: isDark,
                              textColor: textColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSheetTextField(
                              controller: modelController,
                              label: 'Model',
                              hint: 'Cascadia',
                              icon: Icons.directions_car_outlined,
                              isDark: isDark,
                              textColor: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSheetTextField(
                              controller: yearController,
                              label: 'Year',
                              hint: '2024',
                              icon: Icons.calendar_today_outlined,
                              isDark: isDark,
                              textColor: textColor,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSheetTextField(
                              controller: colorController,
                              label: 'Color',
                              hint: 'White',
                              icon: Icons.palette_outlined,
                              isDark: isDark,
                              textColor: textColor,
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
                        isDark: isDark,
                        textColor: textColor,
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildSheetTextField(
                              controller: plateController,
                              label: 'License Plate',
                              hint: 'Plate number',
                              icon: Icons.credit_card_outlined,
                              isDark: isDark,
                              textColor: textColor,
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSheetTextField(
                              controller: plateStateController,
                              label: 'State',
                              hint: 'CA',
                              icon: Icons.location_on_outlined,
                              isDark: isDark,
                              textColor: textColor,
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSheetTextField(
                        controller: usdotController,
                        label: 'USDOT Number',
                        hint: 'DOT number',
                        icon: Icons.numbers_outlined,
                        isDark: isDark,
                        textColor: textColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    String selectedType = initialType;

    return StatefulBuilder(
      builder: (context, setSheetState) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  Text(
                    'Add Trailer',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
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
                          const SnackBar(
                            content: Text('Trailer added successfully'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Save',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
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
                          isDark: isDark,
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
                                isDark: isDark,
                                textColor: textColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSheetTextField(
                                controller: modelController,
                                label: 'Model',
                                hint: 'DuraPlate',
                                icon: Icons.directions_car_outlined,
                                isDark: isDark,
                                textColor: textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSheetTextField(
                                controller: yearController,
                                label: 'Year',
                                hint: '2024',
                                icon: Icons.calendar_today_outlined,
                                isDark: isDark,
                                textColor: textColor,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSheetTextField(
                                controller: lengthController,
                                label: 'Length (ft)',
                                hint: '53',
                                icon: Icons.straighten_outlined,
                                isDark: isDark,
                                textColor: textColor,
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
                          isDark: isDark,
                          textColor: textColor,
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildSheetTextField(
                                controller: plateController,
                                label: 'License Plate',
                                hint: 'Plate number',
                                icon: Icons.credit_card_outlined,
                                isDark: isDark,
                                textColor: textColor,
                                textCapitalization:
                                    TextCapitalization.characters,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSheetTextField(
                                controller: plateStateController,
                                label: 'State',
                                hint: 'CA',
                                icon: Icons.location_on_outlined,
                                isDark: isDark,
                                textColor: textColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: const Color(0xFF3B82F6),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.all(16),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(
        fontSize: 15,
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
      ),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF3B82F6), size: 20),
      suffixIcon: suffixIcon != null
          ? IconButton(
              icon: Icon(suffixIcon, color: const Color(0xFF64748B), size: 18),
              onPressed: onSuffixTap,
            )
          : null,
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildTrailerTypeSelector({
    required String selectedType,
    required ValueChanged<String> onChanged,
    required bool isDark,
  }) {
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
      spacing: 8,
      runSpacing: 8,
      children: types.map((type) {
        final isSelected = selectedType == type;
        return GestureDetector(
          onTap: () => onChanged(type),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : (isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF3F4F6)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : (isDark
                          ? const Color(0xFF404040)
                          : const Color(0xFFE5E7EB)),
              ),
            ),
            child: Text(
              type,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : const Color(0xFF374151)),
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
    required bool isDark,
    required Color textColor,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: GoogleFonts.outfit(fontSize: 16, color: textColor),
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
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete this truck?',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: const Color(0xFF667085)),
            ),
          ),
          TextButton(
            onPressed: () {
              _trucks.removeWhere((t) => (t['id'] as String) == id);
              Navigator.pop(context);
            },
            child: Text('Delete', style: GoogleFonts.outfit(color: Colors.red)),
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
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete this trailer?',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: const Color(0xFF667085)),
            ),
          ),
          TextButton(
            onPressed: () {
              _trailers.removeWhere((t) => (t['id'] as String) == id);
              Navigator.pop(context);
            },
            child: Text('Delete', style: GoogleFonts.outfit(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF9FAFB);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final subtitleColor = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF667085);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? const Color(0xFF334155).withValues(alpha: 0.5)
                  : const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => context.pop(),
          ),
        ),
        title: Text(
          'My Vehicles',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF3B82F6),
              unselectedLabelColor: subtitleColor,
              indicatorColor: const Color(0xFF3B82F6),
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'Trucks'),
                Tab(text: 'Trailers'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTrucksList(cardColor, textColor, subtitleColor, isDark),
          _buildTrailersList(cardColor, textColor, subtitleColor, isDark),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddTruckDialog();
          } else {
            _showAddTrailerDialog();
          }
        },
        backgroundColor: const Color(0xFF3B82F6),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTrucksList(
    Color cardColor,
    Color textColor,
    Color subtitleColor,
    bool isDark,
  ) {
    if (_trucks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.local_shipping_outlined,
        title: 'No Trucks Added',
        subtitle: 'Tap the + button to add your first truck',
        isDark: isDark,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _trucks.length,
      itemBuilder: (context, index) {
        final truck = _trucks[index];
        return _buildTruckCard(
          truck,
          cardColor,
          textColor,
          subtitleColor,
          isDark,
        );
      },
    );
  }

  Widget _buildTrailersList(
    Color cardColor,
    Color textColor,
    Color subtitleColor,
    bool isDark,
  ) {
    if (_trailers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.rv_hookup,
        title: 'No Trailers Added',
        subtitle: 'Tap the + button to add your first trailer',
        isDark: isDark,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _trailers.length,
      itemBuilder: (context, index) {
        final trailer = _trailers[index];
        return _buildTrailerCard(
          trailer,
          cardColor,
          textColor,
          subtitleColor,
          isDark,
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF101828),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTruckCard(
    Map<String, dynamic> truck,
    Color cardColor,
    Color textColor,
    Color subtitleColor,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: InkWell(
        onTap: () {}, // For future view details
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.local_shipping,
                  color: Color(0xFF3B82F6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${truck['year']} ${truck['make']} ${truck['model']}',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.credit_card,
                                size: 14,
                                color: subtitleColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${truck['plate']} (${truck['plateState']})',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (truck['color'] != null &&
                            (truck['color'] as String).isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.palette,
                                  size: 14,
                                  color: subtitleColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  truck['color'],
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _deleteTruck(truck['id']),
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.red.shade400,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.shade50.withValues(
                    alpha: isDark ? 0.1 : 1,
                  ),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrailerCard(
    Map<String, dynamic> trailer,
    Color cardColor,
    Color textColor,
    Color subtitleColor,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.rv_hookup,
                  color: Color(0xFF10B981),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            trailer['type'] ?? 'Unknown',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                        if (trailer['length'] != null &&
                            (trailer['length'] as String).isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            "${trailer['length']}' ft",
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: subtitleColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${trailer['year']} ${trailer['make']} ${trailer['model']}',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.credit_card,
                            size: 14,
                            color: subtitleColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${trailer['plate']} (${trailer['plateState']})',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _deleteTrailer(trailer['id']),
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.red.shade400,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.shade50.withValues(
                    alpha: isDark ? 0.1 : 1,
                  ),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
