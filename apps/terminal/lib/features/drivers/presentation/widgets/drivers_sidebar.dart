import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow_core/milow_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../users/data/user_repository_provider.dart';
import 'package:go_router/go_router.dart';

import '../providers/driver_selection_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class DriversSidebar extends ConsumerStatefulWidget {
  const DriversSidebar({super.key});

  @override
  ConsumerState<DriversSidebar> createState() => _DriversSidebarState();
}

class _DriversSidebarState extends ConsumerState<DriversSidebar> {
  final Map<String, bool> _expandedSections = {
    'ACTIVE DRIVERS': true,
    'ON RESET': false,
    'OFF DUTY': false,
    'INACTIVE': false,
  };
  String _searchQuery = '';

  void _toggleSection(String title) {
    setState(() {
      _expandedSections[title] = !(_expandedSections[title] ?? false);
    });
  }

  // Keyboard Navigation
  final FocusNode _listFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final FlyoutController _flyoutController = FlyoutController();
  int? _focusedIndex;

  @override
  void dispose() {
    _listFocusNode.dispose();
    _scrollController.dispose();
    _flyoutController.dispose();
    super.dispose();
  }

  List<UserProfile> _filterDrivers(List<UserProfile> users) {
    return users.where((u) => u.role == UserRole.driver && u.isVerified).where((
      u,
    ) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return (u.fullName?.toLowerCase().contains(query) ?? false) ||
          (u.email?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  List<dynamic> _buildFlatList(List<UserProfile> activeDrivers) {
    final items = <dynamic>[];

    // ACTIVE DRIVERS
    items.add('ACTIVE DRIVERS');
    if (_expandedSections['ACTIVE DRIVERS'] == true) {
      items.addAll(activeDrivers);
    }

    // ON RESET (Empty for now)
    items.add('ON RESET');
    if (_expandedSections['ON RESET'] == true) {
      items.addAll([]);
    }

    // OFF DUTY (Empty for now)
    items.add('OFF DUTY');
    if (_expandedSections['OFF DUTY'] == true) {
      items.addAll([]);
    }

    // INACTIVE
    items.add('INACTIVE');
    if (_expandedSections['INACTIVE'] == true) {
      items.addAll([]);
    }

    return items;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      ref.read(usersProvider).whenData((users) {
        final activeDrivers = _filterDrivers(users);
        final items = _buildFlatList(activeDrivers);
        if (items.isEmpty) return;

        setState(() {
          if (_focusedIndex == null || _focusedIndex! >= items.length - 1) {
            _focusedIndex = 0;
          } else {
            _focusedIndex = _focusedIndex! + 1;
          }
        });
        _scrollToFocused();
      });
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      ref.read(usersProvider).whenData((users) {
        final activeDrivers = _filterDrivers(users);
        final items = _buildFlatList(activeDrivers);
        if (items.isEmpty) return;

        setState(() {
          if (_focusedIndex == null || _focusedIndex! <= 0) {
            _focusedIndex = items.length - 1;
          } else {
            _focusedIndex = _focusedIndex! - 1;
          }
        });
        _scrollToFocused();
      });
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_focusedIndex != null) {
        ref.read(usersProvider).whenData((users) {
          final activeDrivers = _filterDrivers(users);
          final items = _buildFlatList(activeDrivers);
          if (_focusedIndex! < items.length) {
            final item = items[_focusedIndex!];
            if (item is String) {
              _toggleSection(item);
            } else if (item is UserProfile) {
              ref.read(selectedDriverProvider.notifier).select(item);
              context.go('/drivers/${item.id}');
            }
          }
        });
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _scrollToFocused() {
    if (_focusedIndex == null) return;
    final offset = _focusedIndex! * 50.0; // Rough guess
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final backgroundColor = theme.resources.solidBackgroundFillColorTertiary;
    final titleColor = theme.resources.textFillColorSecondary;

    final usersAsync = ref.watch(usersProvider);
    final selectedDriver = ref.watch(selectedDriverProvider);

    return Acrylic(
      tint: backgroundColor,
      tintAlpha: isLight ? 0.95 : 0.75,
      luminosityAlpha: isLight ? 0.98 : 0.88,
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
                  'DRIVERS',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(FluentIcons.more, size: 14, color: titleColor),
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
              placeholder: 'Search Drivers...',
              placeholderStyle: GoogleFonts.outfit(
                color: isLight ? Colors.grey[100] : const Color(0xFF858585),
                fontSize: 13,
              ),
              style: GoogleFonts.outfit(
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
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Lists
          Expanded(
            child: usersAsync.when(
              data: (users) {
                final activeDrivers = _filterDrivers(users);
                final items = _buildFlatList(activeDrivers);

                return Focus(
                  focusNode: _listFocusNode,
                  onKeyEvent: _handleKeyEvent,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isFocused = index == _focusedIndex;

                      if (item is String) {
                        // Section Header
                        int count = 0;
                        if (item == 'ACTIVE DRIVERS') {
                          count = activeDrivers.length;
                        }
                        return _buildSectionHeader(
                          item,
                          isLight,
                          count,
                          isFocused,
                        );
                      } else if (item is UserProfile) {
                        return _buildUserItem(
                          item,
                          isLight,
                          selectedDriver,
                          isFocused,
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
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

  Widget _buildSectionHeader(
    String title,
    bool isLight,
    int count,
    bool isFocused,
  ) {
    final textColor = isLight
        ? const Color(0xFF333333)
        : const Color(0xFFCCCCCC);
    final hoverColor = isLight
        ? const Color(0xFFE8E8E8)
        : const Color(0xFF2A2D2E);

    final isExpanded = _expandedSections[title] ?? false;

    return HoverButton(
      onPressed: () => _toggleSection(title),
      builder: (context, states) {
        return Container(
          decoration: BoxDecoration(
            color: states.isHovered
                ? hoverColor
                : (isLight
                      ? const Color(0xFFFAFAFA)
                      : const Color(0xFF252526)), // Subtle bg or transparent
            border: Border(
              top: BorderSide(
                color: isLight
                    ? const Color(0xFFE5E5E5)
                    : const Color(
                        0xFF3E3E42,
                      ), // VS Code sidebar toggle border color
                width: 1.0,
              ),
              left: isFocused
                  ? BorderSide(
                      color: FluentTheme.of(context).accentColor,
                      width: 3,
                    )
                  : BorderSide.none,
            ),
          ),
          padding: const EdgeInsets.only(left: 4, right: 8, top: 4, bottom: 4),
          height: 28,
          child: Row(
            children: [
              Icon(
                isExpanded
                    ? FluentIcons.chevron_down
                    : FluentIcons.chevron_right,
                size: 8,
                color: textColor,
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const Spacer(),
              // Badge count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                decoration: BoxDecoration(
                  color: isLight
                      ? const Color(0xFFE0E0E0)
                      : const Color(0xFF4D4D4D),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.outfit(
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
    );
  }

  Widget _buildUserItem(
    UserProfile driver,
    bool isLight,
    UserProfile? selectedDriver,
    bool isFocused,
  ) {
    final textColor = isLight
        ? const Color(0xFF333333)
        : const Color(0xFFCCCCCC);
    final subTextColor = isLight
        ? const Color(0xFF666666)
        : const Color(0xFF999999);
    final hoverColor = isLight
        ? const Color(0xFFE8E8E8)
        : const Color(0xFF2A2D2E);
    final selectedColor = isLight
        ? const Color(0xFFE8E8E8)
        : const Color(0xFF37373D);

    final isSelected = selectedDriver?.id == driver.id;

    // We'll use a FutureBuilder to fetch the active assignment for this driver
    // This might be slightly expensive for a long list, but for a sidebar it's acceptable
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchActiveTrip(driver.id),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final tripNumber = data?['trip_number'] as String?;
        final assignedTruckNumber = data?['assigned_truck_number'] as String?;
        final source = data?['source'] as String?;

        // Build route display based on data source
        String currentTrip;
        if (source == 'load') {
          // For loads: show shipper → receiver
          final shipper = data?['shipper_name'] as String? ?? 'Unknown';
          final receiver = data?['receiver_name'] as String? ?? 'Unknown';
          currentTrip = '$shipper → $receiver';
        } else if (data?['pickup_locations'] != null) {
          // For trips: show city/state
          currentTrip =
              '${_extractCityState(data!['pickup_locations'])} → ${_extractCityState(data['delivery_locations'])}';
        } else if (assignedTruckNumber != null) {
          currentTrip = 'Assigned to Trk $assignedTruckNumber';
        } else {
          currentTrip = 'No active assignment';
        }

        final statusColor = (tripNumber != null || assignedTruckNumber != null)
            ? Colors.green
            : Colors.grey; // Active if assigned

        return HoverButton(
          onPressed: () {
            ref.read(selectedDriverProvider.notifier).select(driver);
            context.go('/drivers');
          },
          builder: (context, states) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? selectedColor
                    : (states.isHovered ? hoverColor : Colors.transparent),
                border: Border(
                  left: BorderSide(
                    color: isSelected || isFocused
                        ? FluentTheme.of(context).accentColor
                        : Colors.transparent,
                    width: isFocused && !isSelected ? 4 : 3,
                  ),
                ),
              ),
              child: FlyoutTarget(
                controller: _flyoutController,
                child: GestureDetector(
                  onSecondaryTapUp: (details) {
                    _showContextMenu(context, driver, details);
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar with status indicator
                      Stack(
                        children: [
                          _buildAvatar(driver),
                          Positioned(
                            right: 0,
                            bottom: 0,
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
                            // Name row
                            Text(
                              driver.fullName ?? 'Unknown',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Trip info row
                            Row(
                              children: [
                                if (tripNumber != null) ...[
                                  // Trip number badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isLight
                                          ? const Color(0xFFE0E0E0)
                                          : const Color(0xFF4D4D4D),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      tripNumber,
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: subTextColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (assignedTruckNumber != null) ...[
                                  // Truck number badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: FluentTheme.of(
                                        context,
                                      ).accentColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      assignedTruckNumber,
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: FluentTheme.of(
                                          context,
                                        ).accentColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    currentTrip,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: subTextColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Assign button on hover
                      if (states.isHovered)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Tooltip(
                            message: 'Assign Trip/Truck',
                            child: IconButton(
                              icon: Icon(
                                FluentIcons.add,
                                size: 18,
                                color: FluentTheme.of(context).accentColor,
                              ),
                              onPressed: () {
                                _showAssignDialog(context, driver);
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showContextMenu(
    BuildContext context,
    UserProfile driver,
    TapUpDetails details,
  ) {
    _flyoutController.showFlyout(
      builder: (context) {
        return MenuFlyout(
          items: [
            MenuFlyoutItem(
              text: const Text('View Details'),
              leading: const Icon(FluentIcons.contact),
              onPressed: () {
                _flyoutController.close();
                ref.read(selectedDriverProvider.notifier).select(driver);
                context.go('/drivers/${driver.id}');
              },
            ),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              text: const Text('Assign Trip'),
              leading: const Icon(FluentIcons.open_folder_horizontal),
              onPressed: () {
                _flyoutController.close();
                _showTripSelectionDialog(context, driver);
              },
            ),
            MenuFlyoutItem(
              text: const Text('Assign Truck'),
              leading: const Icon(FluentIcons.car),
              onPressed: () {
                _flyoutController.close();
                _showTruckSelectionDialog(context, driver);
              },
            ),
            // Potential future actions
            // const MenuFlyoutSeparator(),
            // MenuFlyoutItem(
            //   text: const Text('Message'),
            //   leading: const Icon(FluentIcons.chat),
            //   onPressed: () {},
            // ),
          ],
        );
      },
      dismissOnPointerMoveAway: false,
      autoModeConfiguration: FlyoutAutoConfiguration(
        preferredMode: FlyoutPlacementMode.bottomRight,
      ),
    );
  }

  void _showAssignDialog(BuildContext context, UserProfile driver) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Text('Assign to ${driver.fullName ?? 'Driver'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select what to assign:'),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(FluentIcons.open_folder_horizontal),
              title: const Text('Assign Trip'),
              subtitle: const Text('Select an available trip'),
              onPressed: () {
                Navigator.pop(context);
                _showTripSelectionDialog(context, driver);
              },
            ),
            ListTile(
              leading: Icon(FluentIcons.car),
              title: const Text('Assign Truck'),
              subtitle: const Text('Select an available truck'),
              onPressed: () {
                Navigator.pop(context);
                _showTruckSelectionDialog(context, driver);
              },
            ),
          ],
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showTripSelectionDialog(BuildContext context, UserProfile driver) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Select Trip'),
        content: SizedBox(
          height: 300,
          width: 400,
          child: FutureBuilder(
            future: Supabase.instance.client
                .from('trips')
                .select()
                .filter('user_id', 'is', null)
                .order('created_at', ascending: false)
                .limit(20),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: ProgressRing());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final trips = snapshot.data as List<dynamic>? ?? [];
              if (trips.isEmpty) {
                return const Center(child: Text('No unassigned trips found.'));
              }
              return ListView.builder(
                itemCount: trips.length,
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  return ListTile(
                    title: Text('Trip #${trip['trip_number'] ?? 'N/A'}'),
                    subtitle: Text(
                      '${trip['trip_date'] != null ? DateFormat('MM/dd/yyyy').format(DateTime.parse(trip['trip_date'])) : ''} • ${trip['truck_number'] ?? 'No Truck'}',
                    ),
                    trailing: Button(
                      child: const Text('Assign'),
                      onPressed: () async {
                        try {
                          await Supabase.instance.client
                              .from('trips')
                              .update({'user_id': driver.id})
                              .eq('id', trip['id']);
                          if (context.mounted) {
                            Navigator.pop(context);
                            displayInfoBar(
                              context,
                              builder: (context, close) => InfoBar(
                                title: const Text('Success'),
                                content: const Text('Trip assigned to driver'),
                                severity: InfoBarSeverity.success,
                                onClose: close,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            displayInfoBar(
                              context,
                              builder: (context, close) => InfoBar(
                                title: const Text('Error'),
                                content: Text(e.toString()),
                                severity: InfoBarSeverity.error,
                                onClose: close,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          Button(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showTruckSelectionDialog(BuildContext context, UserProfile driver) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Assign Vehicle'),
        content: SizedBox(
          height: 400,
          width: 500,
          child: FutureBuilder(
            future: Supabase.instance.client
                .from('vehicles')
                .select('id, truck_number, vehicle_type, license_plate')
                .order('truck_number'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: ProgressRing());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final vehicles = snapshot.data as List<dynamic>? ?? [];
              if (vehicles.isEmpty) {
                return const Center(child: Text('No vehicles found.'));
              }
              return ListView.builder(
                itemCount: vehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = vehicles[index];
                  final vehicleId = vehicle['id'] as String?;
                  final truckNumber =
                      vehicle['truck_number'] as String? ?? 'N/A';
                  final vehicleType =
                      vehicle['vehicle_type'] as String? ?? 'Unknown';
                  return ListTile(
                    leading: Icon(
                      FluentIcons.car,
                      color: FluentTheme.of(context).accentColor,
                    ),
                    title: Text('$truckNumber - $vehicleType'),
                    subtitle: Text(
                      'Plate: ${vehicle['license_plate'] ?? 'N/A'}',
                    ),
                    trailing: FilledButton(
                      child: const Text('Assign'),
                      onPressed: vehicleId == null
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await _assignVehicleToDriver(
                                context,
                                driver,
                                vehicleId,
                                truckNumber,
                              );
                            },
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _assignVehicleToDriver(
    BuildContext context,
    UserProfile driver,
    String vehicleId,
    String vehicleNumber,
  ) async {
    try {
      // 1. Unassign any current vehicle for this driver
      await Supabase.instance.client
          .from('fleet_assignments')
          .update({'unassigned_at': DateTime.now().toIso8601String()})
          .eq('assignee_id', driver.id)
          .eq('type', 'driver_to_vehicle')
          .isFilter('unassigned_at', null);

      // 2. Create new assignment
      final currentUser = Supabase.instance.client.auth.currentUser;
      await Supabase.instance.client.from('fleet_assignments').insert({
        'assignee_id': driver.id,
        'resource_id': vehicleId,
        'type': 'driver_to_vehicle',
        'assigned_by': currentUser?.id,
      });

      if (context.mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Vehicle Assigned'),
            content: Text(
              'Truck $vehicleNumber has been assigned to ${driver.fullName ?? 'driver'}.',
            ),
            severity: InfoBarSeverity.success,
            onClose: close,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Assignment Failed'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
            onClose: close,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchActiveTrip(String driverId) async {
    try {
      final supabase = Supabase.instance.client;

      // Fetch assigned load (higher priority than trips)
      final loadResponse = await supabase
          .from('loads')
          .select('''
            id, trip_number, assigned_truck_id, broker_name,
            vehicles:assigned_truck_id(truck_number),
            stops(sequence, type, company_name)
          ''')
          .eq('assigned_driver_id', driverId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      debugPrint('Load query for driver $driverId: $loadResponse');

      // If we have an assigned load, use it
      if (loadResponse != null) {
        final vehicle = loadResponse['vehicles'] as Map<String, dynamic>?;
        final stops = loadResponse['stops'] as List<dynamic>? ?? [];

        // Find pickup (shipper) and delivery (receiver) from stops
        String? shipperName;
        String? receiverName;
        for (final stop in stops) {
          final stopMap = stop as Map<String, dynamic>;
          final type = stopMap['type'] as String?;
          final companyName = stopMap['company_name'] as String?;
          if (type == 'pickup' && shipperName == null) {
            shipperName = companyName;
          } else if (type == 'delivery' && receiverName == null) {
            receiverName = companyName;
          }
        }

        return {
          'trip_number': loadResponse['trip_number'] as String?,
          'shipper_name': shipperName ?? loadResponse['broker_name'] as String?,
          'receiver_name': receiverName,
          'assigned_truck_number': vehicle?['truck_number'] as String?,
          'source': 'load',
        };
      }

      // Fallback: Fetch active trip
      final tripResponse = await supabase
          .from('trips')
          .select('trip_number, pickup_locations, delivery_locations')
          .eq('user_id', driverId)
          .isFilter('deleted_at', null)
          .order('trip_date', ascending: false)
          .limit(1)
          .maybeSingle();

      // Fetch assigned vehicle
      final assignmentResponse = await supabase
          .from('fleet_assignments')
          .select('resource_id, vehicles:resource_id(truck_number)')
          .eq('assignee_id', driverId)
          .eq('type', 'driver_to_vehicle')
          .isFilter('unassigned_at', null)
          .maybeSingle();

      // Combine results
      final result = <String, dynamic>{};

      if (tripResponse != null) {
        result.addAll(tripResponse);
        result['source'] = 'trip';
      }

      if (assignmentResponse != null) {
        final vehicle = assignmentResponse['vehicles'] as Map<String, dynamic>?;
        result['assigned_truck_number'] = vehicle?['truck_number'] as String?;
      }

      return result.isNotEmpty ? result : null;
    } catch (e) {
      debugPrint('Error fetching active trip for driver $driverId: $e');
      return null;
    }
  }

  String _extractCityState(dynamic locationData) {
    if (locationData is List && locationData.isNotEmpty) {
      final loc = locationData.first;
      if (loc is Map) {
        final address = loc['address'] as String?;
        if (address != null) {
          final parts = address.split(',');
          if (parts.length >= 2) {
            // Basic parsing: "City, State, Zip" -> "City, State"
            return '${parts[parts.length - 3].trim()}, ${parts[parts.length - 2].trim().split(' ').first}';
          }
          return address;
        }
      }
    }
    return 'Unknown';
  }

  Widget _buildAvatar(UserProfile driver) {
    if (driver.avatarUrl != null && driver.avatarUrl!.isNotEmpty) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          driver.avatarUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildInitialsAvatar(driver),
        ),
      );
    }
    return _buildInitialsAvatar(driver);
  }

  Widget _buildInitialsAvatar(UserProfile driver) {
    String initials = '?';
    if (driver.fullName != null && driver.fullName!.isNotEmpty) {
      final parts = driver.fullName!.trim().split(' ');
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty) {
        initials = parts[0][0].toUpperCase();
      }
    } else if (driver.email != null && driver.email!.isNotEmpty) {
      initials = driver.email![0].toUpperCase();
    }

    final theme = FluentTheme.of(context);

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: theme.accentColor.defaultBrushFor(theme.brightness),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
