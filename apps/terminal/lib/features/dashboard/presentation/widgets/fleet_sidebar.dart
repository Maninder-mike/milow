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
  final Map<String, bool> _expandedSections = {
    'ACTIVE': true,
    'MAINTENANCE': true,
    'IDLE': false,
    'BREAKDOWN': false,
  };
  String _searchQuery = '';

  void _toggleSection(String title) {
    setState(() {
      _expandedSections[title] = !(_expandedSections[title] ?? false);
    });
  }

  List<Map<String, dynamic>> _getVehiclesByStatus(
    List<Map<String, dynamic>> vehicles,
    String status,
  ) {
    return vehicles.where((v) {
      final vStatus = (v['status'] as String?)?.toUpperCase() ?? 'UNKNOWN';
      final matchesStatus = vStatus == status;

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

      return matchesStatus && matchesSearch;
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
          ref.invalidate(vehiclesListProvider);
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
        : const Color(0xFF202020);
    final titleColor = isLight
        ? const Color(0xFF616161)
        : const Color(0xFFCCCCCC);

    final vehiclesAsync = ref.watch(vehiclesListProvider);

    return Acrylic(
      tint: backgroundColor,
      tintAlpha: isLight ? 0.9 : 0.8,
      luminosityAlpha: isLight ? 0.9 : 0.8,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
            height: 35,
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
                  children: [
                    IconButton(
                      icon: Icon(
                        FluentIcons.add_24_regular,
                        size: 16,
                        color: titleColor,
                      ),
                      onPressed: _showAddDialog,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        FluentIcons.more_horizontal_24_regular,
                        size: 14,
                        color: titleColor,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: TextBox(
              placeholder: 'Search Fleet...',
              placeholderStyle: GoogleFonts.inter(
                color: isLight ? Colors.grey[100] : const Color(0xFF858585),
                fontSize: 13,
              ),
              style: GoogleFonts.inter(
                color: isLight ? Colors.black : Colors.white,
                fontSize: 13,
              ),
              decoration: WidgetStateProperty.all(
                BoxDecoration(
                  color: isLight
                      ? const Color(0xFFFFFFFF)
                      : const Color(0xFF3C3C3C),
                  border: Border.all(
                    color: isLight
                        ? const Color(0xFFE0E0E0)
                        : const Color(0xFF3C3C3C),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.zero,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              cursorColor: isLight ? Colors.black : Colors.white,
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Lists
          Expanded(
            child: vehiclesAsync.when(
              data: (vehicles) {
                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildCollapsibleSection(
                      'ACTIVE',
                      isLight,
                      _getVehiclesByStatus(
                        vehicles,
                        'ACTIVE',
                      ).map((v) => _buildVehicleItem(v, isLight)).toList(),
                    ),
                    _buildCollapsibleSection(
                      'MAINTENANCE',
                      isLight,
                      _getVehiclesByStatus(
                        vehicles,
                        'MAINTENANCE',
                      ).map((v) => _buildVehicleItem(v, isLight)).toList(),
                    ),
                    _buildCollapsibleSection(
                      'IDLE',
                      isLight,
                      _getVehiclesByStatus(
                        vehicles,
                        'IDLE',
                      ).map((v) => _buildVehicleItem(v, isLight)).toList(),
                    ),
                    _buildCollapsibleSection(
                      'BREAKDOWN',
                      isLight,
                      _getVehiclesByStatus(
                        vehicles,
                        'BREAKDOWN',
                      ).map((v) => _buildVehicleItem(v, isLight)).toList(),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: ProgressRing()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSection(
    String title,
    bool isLight,
    List<Widget> children,
  ) {
    final textColor = isLight
        ? const Color(0xFF333333)
        : const Color(0xFFCCCCCC);
    final hoverColor = isLight
        ? const Color(0xFFE8E8E8)
        : const Color(0xFF2A2D2E);

    final isExpanded = _expandedSections[title] ?? false;

    return Column(
      children: [
        HoverButton(
          onPressed: () => _toggleSection(title),
          builder: (context, states) {
            return Container(
              decoration: BoxDecoration(
                color: states.isHovered ? hoverColor : Colors.transparent,
                border: Border(
                  top: BorderSide(
                    color: isLight
                        ? const Color(0xFFE5E5E5)
                        : const Color(0xFF3E3E42),
                    width: 1.0,
                  ),
                ),
              ),
              padding: const EdgeInsets.only(
                left: 4,
                right: 8,
                top: 4,
                bottom: 4,
              ),
              height: 28,
              child: Row(
                children: [
                  Icon(
                    isExpanded
                        ? FluentIcons.chevron_down_24_regular
                        : FluentIcons.chevron_right_24_regular,
                    size: 8,
                    color: textColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  // Badge count
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 0,
                    ),
                    decoration: BoxDecoration(
                      color: isLight
                          ? const Color(0xFFE0E0E0)
                          : const Color(0xFF4D4D4D),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${children.length}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (isExpanded) Column(children: children),
      ],
    );
  }

  Widget _buildVehicleItem(Map<String, dynamic> vehicle, bool isLight) {
    final textColor = isLight
        ? const Color(0xFF333333)
        : const Color(0xFFCCCCCC);
    final subTextColor = isLight
        ? const Color(0xFF666666)
        : const Color(0xFF999999);
    final hoverColor = isLight
        ? const Color(0xFFE8E8E8)
        : const Color(0xFF2A2D2E);

    final status = vehicle['status'] as String? ?? 'Unknown';
    final statusColor = _getStatusColor(status);
    final hasIssue = vehicle['mil_status'] == true;

    return HoverButton(
      onPressed: () {
        context.go('/vehicles/status', extra: vehicle);
      },
      builder: (context, states) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: states.isHovered ? hoverColor : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: states.isHovered
                    ? FluentTheme.of(context).accentColor
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon with status indicator
              Stack(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isLight ? Colors.white : const Color(0xFF2D2D2D),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isLight
                            ? const Color(0xFFE0E0E0)
                            : const Color(0xFF3C3C3C),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      vehicle['vehicle_type'] == 'Trailer'
                          ? FluentIcons.vehicle_truck_profile_24_regular
                          : FluentIcons.vehicle_truck_24_regular,
                      size: 16,
                      color: textColor,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isLight
                              ? Colors.white
                              : const Color(0xFF252526),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vehicle Number
                    Text(
                      vehicle['vehicle_number'] ?? 'Unknown',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // License Plate / Alert
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vehicle['license_plate'] ?? '-',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: subTextColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasIssue) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'ALERT',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ],
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
