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
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF667085),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    'Add Truck',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
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
                    child: Text(
                      'Save',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF007AFF),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSheetTextField(
                      controller: makeController,
                      label: 'Make *',
                      hint: 'e.g., Freightliner, Peterbilt',
                      icon: Icons.factory_outlined,
                      isDark: isDark,
                      textColor: textColor,
                    ),
                    const SizedBox(height: 16),
                    _buildSheetTextField(
                      controller: modelController,
                      label: 'Model',
                      hint: 'e.g., Cascadia, 579',
                      icon: Icons.directions_car_outlined,
                      isDark: isDark,
                      textColor: textColor,
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
                    const SizedBox(height: 16),
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
                    SizedBox(
                      height: MediaQuery.of(context).viewInsets.bottom + 32,
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
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    String selectedType = initialType;

    return StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF667085),
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      'Add Trailer',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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
                      child: Text(
                        'Save',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF007AFF),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trailer Type',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTrailerTypeSelector(
                        selectedType: selectedType,
                        onChanged: (type) {
                          setSheetState(() => selectedType = type);
                        },
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),
                      _buildSheetTextField(
                        controller: makeController,
                        label: 'Make',
                        hint: 'e.g., Wabash, Great Dane',
                        icon: Icons.factory_outlined,
                        isDark: isDark,
                        textColor: textColor,
                      ),
                      const SizedBox(height: 16),
                      _buildSheetTextField(
                        controller: modelController,
                        label: 'Model',
                        hint: 'Trailer model',
                        icon: Icons.directions_car_outlined,
                        isDark: isDark,
                        textColor: textColor,
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
                      const SizedBox(height: 16),
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
                      SizedBox(
                        height: MediaQuery.of(context).viewInsets.bottom + 32,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
                  ? const Color(0xFF007AFF)
                  : (isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF3F4F6)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF007AFF)
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
    final fillColor = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFF3F4F6);
    final hintColor = isDark
        ? const Color(0xFF6B7280)
        : const Color(0xFF9CA3AF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: GoogleFonts.outfit(fontSize: 16, color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(fontSize: 14, color: hintColor),
            prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
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
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'My Vehicles',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF007AFF),
          unselectedLabelColor: subtitleColor,
          indicatorColor: const Color(0xFF007AFF),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w500,
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
        backgroundColor: const Color(0xFF007AFF),
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
              color: const Color(0xFF007AFF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: const Color(0xFF007AFF)),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.local_shipping,
                color: Color(0xFF3B82F6),
                size: 28,
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.credit_card, size: 14, color: subtitleColor),
                      const SizedBox(width: 4),
                      Text(
                        '${truck['plate']} (${truck['plateState']})',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: subtitleColor,
                        ),
                      ),
                      if (truck['color'] != null &&
                          (truck['color'] as String).isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.palette, size: 14, color: subtitleColor),
                        const SizedBox(width: 4),
                        Text(
                          truck['color'],
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: subtitleColor,
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
              icon: Icon(Icons.delete_outline, color: Colors.red[400]),
            ),
          ],
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.rv_hookup,
                color: Color(0xFF10B981),
                size: 28,
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
                          color: const Color(0xFF10B981).withOpacity(0.1),
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.credit_card, size: 14, color: subtitleColor),
                      const SizedBox(width: 4),
                      Text(
                        '${trailer['plate']} (${trailer['plateState']})',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _deleteTrailer(trailer['id']),
              icon: Icon(Icons.delete_outline, color: Colors.red[400]),
            ),
          ],
        ),
      ),
    );
  }
}
