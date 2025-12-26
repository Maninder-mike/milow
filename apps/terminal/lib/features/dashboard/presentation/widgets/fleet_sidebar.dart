import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../services/vehicle_service.dart';
import '../../screens/vehicles/add_vehicle_dialog.dart';

class FleetSidebar extends ConsumerStatefulWidget {
  const FleetSidebar({super.key});

  @override
  ConsumerState<FleetSidebar> createState() => _FleetSidebarState();
}

class _FleetSidebarState extends ConsumerState<FleetSidebar> {
  String _selectedFilter = 'All'; // All, Active, Maintenance, Idle, Breakdown
  String _searchQuery = '';
  List<Map<String, dynamic>> _allVehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    final service = ref.read(vehicleServiceProvider);
    final vehicles = await service.getVehicles();
    if (mounted) {
      setState(() {
        _allVehicles = vehicles;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredVehicles {
    return _allVehicles.where((v) {
      final matchesFilter =
          _selectedFilter == 'All' ||
          (v['status'] as String?)?.toLowerCase() ==
              _selectedFilter.toLowerCase();

      final matchesSearch =
          _searchQuery.isEmpty ||
          (v['vehicle_number'] as String?)?.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ==
              true ||
          (v['license_plate'] as String?)?.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ==
              true;

      return matchesFilter && matchesSearch;
    }).toList();
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'maintenance':
        return Colors.orange;
      case 'idle':
        return Colors.blue;
      case 'breakdown':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showAddDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AddVehicleDialog(
        onSaved: () {
          Navigator.pop(context);
          _loadVehicles();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;
    // Sidebar colors - matching the lighter terminal theme
    final backgroundColor = isLight
        ? const Color(0xFFF3F3F3)
        : const Color(0xFF252526);
    final titleColor = isLight
        ? const Color(0xFF616161)
        : const Color(0xFFBBBBBB);

    return Container(
      color: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            height: 40,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FLEET',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        FluentIcons.add_24_regular,
                        size: 16,
                        color: titleColor,
                      ),
                      onPressed: _showAddDialog,
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      FluentIcons.filter_24_regular,
                      size: 16,
                      color: titleColor,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _SidebarSearchBar(
              isLight: isLight,
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Filters (Chips)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('All'),
                const SizedBox(width: 8),
                _buildFilterChip('Active'),
                const SizedBox(width: 8),
                _buildFilterChip('Maintenance'),
                const SizedBox(width: 8),
                _buildFilterChip('Idle'),
                const SizedBox(width: 8),
                _buildFilterChip('Breakdown'),
              ],
            ),
          ),

          const Divider(),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: ProgressRing())
                : _filteredVehicles.isEmpty
                ? Center(
                    child: Text(
                      'No vehicles found',
                      style: TextStyle(color: titleColor),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _filteredVehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = _filteredVehicles[index];
                      return _buildVehicleItem(vehicle, isLight);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? FluentTheme.of(context).accentColor
              : FluentTheme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : FluentTheme.of(context).resources.dividerStrokeColorDefault,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isSelected ? Colors.white : null,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleItem(Map<String, dynamic> vehicle, bool isLight) {
    final textColor = isLight
        ? const Color(0xFF333333)
        : const Color(0xFFCCCCCC);
    final hoverColor = isLight
        ? const Color(0xFFE8E8E8)
        : const Color(0xFF2A2D2E);

    return HoverButton(
      onPressed: () {
        context.go('/vehicles/status', extra: vehicle);
      },
      builder: (context, states) {
        final isHovering = states.isHovered;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isHovering ? hoverColor : Colors.transparent,
          child: Row(
            children: [
              // Status Dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _getStatusColor(vehicle['status']),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              // Icon
              Icon(
                vehicle['vehicle_type'] == 'Trailer'
                    ? FluentIcons.vehicle_truck_profile_24_regular
                    : FluentIcons.vehicle_truck_24_regular,
                size: 16,
                color: textColor,
              ),
              const SizedBox(width: 12),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle['vehicle_number'] ?? 'Unknown',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      vehicle['license_plate'] ?? '-',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SidebarSearchBar extends StatefulWidget {
  final bool isLight;
  final ValueChanged<String> onChanged;

  const _SidebarSearchBar({required this.isLight, required this.onChanged});

  @override
  State<_SidebarSearchBar> createState() => _SidebarSearchBarState();
}

class _SidebarSearchBarState extends State<_SidebarSearchBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isFocused = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    // Windows 11 style colors
    final bgColor = widget.isLight ? Colors.white : const Color(0xFF2D2D2D);
    final borderColor = widget.isLight
        ? const Color(0xFFE5E5E5)
        : const Color(0xFF404040);
    final focusBorderColor = theme.accentColor;
    final placeholderColor = widget.isLight
        ? const Color(0xFF6E6E6E)
        : const Color(0xFF9E9E9E);
    final foregroundColor = widget.isLight
        ? const Color(0xFF333333)
        : const Color(0xFFFFFFFF);

    return SizedBox(
      height: 32,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _isFocused ? focusBorderColor : borderColor,
            width: _isFocused ? 1.5 : 1,
          ),
        ),
        child: Focus(
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          child: Row(
            children: [
              Expanded(
                child: TextBox(
                  controller: _controller,
                  placeholder: 'Search...',
                  placeholderStyle: TextStyle(
                    color: placeholderColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  style: TextStyle(color: foregroundColor, fontSize: 13),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: WidgetStateProperty.all(
                    const BoxDecoration(
                      color: Colors.transparent,
                      border: Border.fromBorderSide(BorderSide.none),
                    ),
                  ),
                  unfocusedColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onChanged: widget.onChanged,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  FluentIcons.search_24_regular,
                  size: 16,
                  color: placeholderColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
