import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow_core/milow_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/driver_selection_provider.dart';
import 'widgets/driver_chat_widget.dart';

class DriversPage extends ConsumerStatefulWidget {
  const DriversPage({super.key});

  @override
  ConsumerState<DriversPage> createState() => _DriversPageState();
}

class _DriversPageState extends ConsumerState<DriversPage> {
  @override
  Widget build(BuildContext context) {
    final selectedDriver = ref.watch(selectedDriverProvider);

    return ScaffoldPage(
      content: selectedDriver == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FluentIcons.contact,
                    size: 64,
                    color: FluentTheme.of(
                      context,
                    ).resources.controlStrokeColorDefault,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select a driver to view details',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      color: FluentTheme.of(
                        context,
                      ).typography.body?.color?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(right: 24, bottom: 24),
              child: _DriverDetailPanel(driver: selectedDriver),
            ),
    );
  }
}

class _DriverDetailPanel extends StatefulWidget {
  final UserProfile driver;

  const _DriverDetailPanel({required this.driver});

  @override
  State<_DriverDetailPanel> createState() => _DriverDetailPanelState();
}

class _DriverDetailPanelState extends State<_DriverDetailPanel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Custom Navigation Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          child: Row(
            children: [
              _buildNavButton(0, 'Overview', FluentIcons.contact),
              const SizedBox(width: 24),
              _buildNavButton(1, 'Trips', FluentIcons.delivery_truck),
              const SizedBox(width: 24),
              _buildNavButton(2, 'Fuel', FluentIcons.drop),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Content Body
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildBody(),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _OverviewTab(driver: widget.driver);
      case 1:
        return _TripsTab(driver: widget.driver);
      case 2:
        return _FuelTab(driver: widget.driver);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNavButton(int index, String label, IconData icon) {
    final isSelected = _currentIndex == index;
    final theme = FluentTheme.of(context);
    final activeColor = theme.accentColor;
    final inactiveColor = theme.resources.textFillColorSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? theme.typography.body?.color
                        : inactiveColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Active Indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: isSelected ? 24 : 0,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final UserProfile driver;
  const _OverviewTab({required this.driver});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final dateFormat = DateFormat('MMMM d, yyyy');

    return Card(
      padding: EdgeInsets.zero, // Padding moved to container inside scroll
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _buildAvatar(context, driver, 64),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.fullName ?? 'Unknown Driver',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.accentColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          driver.role.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),

            // Main Body: Row with Details (Left) and Chat (Right)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Details
                Expanded(
                  flex: 4, // 40% width
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact Information',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        context,
                        FluentIcons.mail,
                        'Email Address',
                        driver.email ?? '-',
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Account Details',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        context,
                        FluentIcons.calendar,
                        'Joined Date',
                        driver.createdAt != null
                            ? dateFormat.format(driver.createdAt!)
                            : '-',
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        context,
                        FluentIcons.verified_brand,
                        'Verification Status',
                        driver.isVerified ? 'Verified' : 'Pending',
                        valueColor: driver.isVerified
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ],
                  ),
                ),

                // Vertical Divider
                Container(
                  width: 1,
                  height: 400, // Roughly matching chat height or flexible?
                  // Better to let it flexible but Row crossAxia is start.
                  // Let's us a simple SizedBox or Divider.
                  // Or let layout handle it.
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  color: theme.resources.dividerStrokeColorDefault,
                ),

                // Right Column: Chat
                Expanded(
                  flex: 6, // 60% width
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // No title needed really as Chat Widget has header, but user wants clear separation.
                      DriverChatWidget(
                        driverId: driver.id,
                        driverName: driver.fullName ?? 'Driver',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: FluentTheme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: FluentTheme.of(
                context,
              ).resources.dividerStrokeColorDefault,
            ),
          ),
          child: Icon(
            icon,
            size: 14,
            color: FluentTheme.of(context).accentColor,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: FluentTheme.of(context).typography.caption?.color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TripsTab extends StatelessWidget {
  final UserProfile driver;
  const _TripsTab({required this.driver});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Supabase.instance.client
          .from('trips')
          .select()
          .eq('user_id', driver.id)
          .order('trip_date', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: ProgressRing());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error or No Access: ${snapshot.error}'));
        }

        final data = snapshot.data as List<dynamic>? ?? [];
        if (data.isEmpty) {
          return const Center(child: Text('No trips found.'));
        }

        final trips = data.map((e) => Trip.fromJson(e)).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: trips.length,
          itemBuilder: (context, index) {
            final trip = trips[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _TripCard(trip: trip),
            );
          },
        );
      },
    );
  }
}

class _FuelTab extends StatelessWidget {
  final UserProfile driver;
  const _FuelTab({required this.driver});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Supabase.instance.client
          .from('fuel_entries')
          .select()
          .eq('user_id', driver.id)
          .order('fuel_date', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: ProgressRing());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error or No Access: ${snapshot.error}'));
        }

        final data = snapshot.data as List<dynamic>? ?? [];
        if (data.isEmpty) {
          return const Center(child: Text('No fuel entries found.'));
        }

        final entries = data.map((e) => FuelEntry.fromJson(e)).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _FuelCard(entry: entry),
            );
          },
        );
      },
    );
  }
}

// ==========================================
// EXPANDABLE CARD WIDGETS
// ==========================================

class _TripCard extends StatefulWidget {
  final Trip trip;
  const _TripCard({required this.trip});

  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final cardColor = theme.cardColor;
    final borderColor = theme.resources.dividerStrokeColorDefault;
    final textColor = theme.typography.body?.color ?? Colors.black;
    final secondaryTextColor = theme.typography.caption?.color ?? Colors.grey;
    final accentColor = theme.accentColor;

    final trip = widget.trip;
    final distanceStr = trip.totalDistance != null
        ? '${trip.totalDistance!.toStringAsFixed(0)} ${trip.distanceUnitLabel}'
        : null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isExpanded
                  ? accentColor.withValues(alpha: 0.3)
                  : borderColor,
            ),
            boxShadow: _isExpanded
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      FluentIcons.delivery_truck,
                      color: accentColor,
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
                            Text(
                              'Trip #${trip.tripNumber}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            if (distanceStr != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      theme.resources.controlFillColorSecondary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  distanceStr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Text(
                              DateFormat('MMM d, yyyy').format(trip.tripDate),
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Quick Route Summary (Collapsed View)
                        if (!_isExpanded)
                          Text(
                            trip.pickupLocations.isNotEmpty &&
                                    trip.deliveryLocations.isNotEmpty
                                ? '${_extractCityState(trip.pickupLocations.first)} → ${_extractCityState(trip.deliveryLocations.last)}'
                                : 'View Details',
                            style: TextStyle(
                              fontSize: 13,
                              color: secondaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      FluentIcons.chevron_down,
                      size: 16,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),

              // Expanded Content
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    // 1. Route Timeline
                    _buildSectionTitle('Route Timeline'),
                    const SizedBox(height: 16),
                    _buildTimeline(trip, textColor, secondaryTextColor),
                    const SizedBox(height: 24),

                    // 2. Trip Stats Grid
                    _buildSectionTitle('Trip Stats'),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Wrap(
                          spacing: 24,
                          runSpacing: 16,
                          children: [
                            _buildStatItem(
                              'Truck',
                              trip.truckNumber,
                              FluentIcons.delivery_truck,
                              textColor,
                              secondaryTextColor,
                            ),
                            if (trip.trailers.isNotEmpty)
                              _buildStatItem(
                                'Trailer(s)',
                                trip.trailers.join(', '),
                                FluentIcons.link,
                                textColor,
                                secondaryTextColor,
                              ),
                            if ((trip.startOdometer != null))
                              _buildStatItem(
                                'Odometer Start',
                                '${trip.startOdometer!.toStringAsFixed(0)} ${trip.distanceUnitLabel}',
                                FluentIcons.speed_high,
                                textColor,
                                secondaryTextColor,
                              ),
                            if ((trip.endOdometer != null))
                              _buildStatItem(
                                'Odometer End',
                                '${trip.endOdometer!.toStringAsFixed(0)} ${trip.distanceUnitLabel}',
                                FluentIcons.flag,
                                textColor,
                                secondaryTextColor,
                              ),
                          ],
                        );
                      },
                    ),

                    // 3. Notes
                    if (trip.notes != null && trip.notes!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle('Notes'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.resources.controlFillColorSecondary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          trip.notes!,
                          style: TextStyle(color: textColor, fontSize: 13),
                        ),
                      ),
                    ],
                  ],
                ),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
        color: FluentTheme.of(context).resources.textFillColorSecondary,
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color textColor,
    Color subColor,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: FluentTheme.of(
              context,
            ).resources.controlFillColorSecondary.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: subColor),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: subColor)),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeline(Trip trip, Color textColor, Color subColor) {
    final steps = <Map<String, dynamic>>[];
    for (var l in trip.pickupLocations) {
      steps.add({'type': 'pickup', 'location': l});
    }
    for (var l in trip.deliveryLocations) {
      steps.add({'type': 'delivery', 'location': l});
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;
        final isPickup = step['type'] == 'pickup';

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isPickup ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: FluentTheme.of(
                            context,
                          ).resources.cardBackgroundFillColorDefault,
                          width: 2,
                        ),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: FluentTheme.of(
                            context,
                          ).resources.dividerStrokeColorDefault,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPickup ? 'PICKUP' : 'DELIVERY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isPickup ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step['location'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _FuelCard extends StatefulWidget {
  final FuelEntry entry;
  const _FuelCard({required this.entry});

  @override
  State<_FuelCard> createState() => _FuelCardState();
}

class _SendMessageCard extends StatefulWidget {
  final String driverId;
  const _SendMessageCard({required this.driverId});

  @override
  State<_SendMessageCard> createState() => _SendMessageCardState();
}

class _SendMessageCardState extends State<_SendMessageCard> {
  final _messageController = TextEditingController();
  bool _isSending = false;

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw Exception('Not logged in');

      await Supabase.instance.client.from('messages').insert({
        'content': content,
        'receiver_id': widget.driverId,
        'sender_id': currentUser.id,
        // 'is_read': false, // Default is usually false in DB
        // 'created_at': now, // DB handles this usually
      });

      if (mounted) {
        _messageController.clear();
        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: const Text('Message Sent'),
              content: const Text(
                'The driver will receive your message shortly.',
              ),
              severity: InfoBarSeverity.success,
              onClose: close,
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: const Text('Error Sending Message'),
              content: Text(e.toString()),
              severity: InfoBarSeverity.error,
              onClose: close,
            );
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoLabel(
            label: 'Message Content',
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.resources.textFillColorSecondary,
            ),
            child: TextFormBox(
              controller: _messageController,
              placeholder: 'Type your message here...',
              minLines: 3,
              maxLines: 5,
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSending ? null : _sendMessage,
              style: ButtonStyle(
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              child: _isSending
                  ? const ProgressRing(strokeWidth: 2.5)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(FluentIcons.send, size: 16),
                        SizedBox(width: 8),
                        Text('Send Message'),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FuelCardState extends State<_FuelCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final cardColor = theme.cardColor;
    final borderColor = theme.resources.dividerStrokeColorDefault;
    final textColor = theme.typography.body?.color ?? Colors.black;
    final secondaryTextColor = theme.typography.caption?.color ?? Colors.grey;

    final entry = widget.entry;

    // Determine colors based on fuel type
    final typeColor = entry.isTruckFuel ? Colors.blue : Colors.orange;
    final typeIcon = entry.isTruckFuel
        ? FluentIcons.delivery_truck
        : FluentIcons.snow;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isExpanded
                  ? typeColor.withValues(alpha: 0.3)
                  : borderColor,
            ),
            boxShadow: _isExpanded
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(typeIcon, color: typeColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              entry.fuelType.toUpperCase(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                entry.isTruckFuel
                                    ? (entry.truckNumber ?? 'Unknown')
                                    : (entry.reeferNumber ?? 'Unknown'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: typeColor,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat('MMM d, yyyy').format(entry.fuelDate),
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Summary Text (Collapsed)
                        if (!_isExpanded)
                          Row(
                            children: [
                              Text(
                                '${entry.fuelQuantity.toStringAsFixed(1)} ${entry.fuelUnitLabel}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Icon(
                                  FluentIcons.circle_fill,
                                  size: 4,
                                  color: secondaryTextColor,
                                ),
                              ),
                              Text(
                                entry.formattedTotalCost,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      FluentIcons.chevron_down,
                      size: 16,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),

              // Expanded Content
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    // 1. Key Metrics (Quantity & Total Cost)
                    Row(
                      children: [
                        Expanded(
                          child: _buildBigStat(
                            'Quantity',
                            '${entry.fuelQuantity.toStringAsFixed(1)} ${entry.fuelUnitLabel}',
                            FluentIcons.drop,
                            Colors.blue,
                            theme,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildBigStat(
                            'Total Cost',
                            entry.formattedTotalCost,
                            FluentIcons.money,
                            Colors.green,
                            theme,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 2. Location
                    if (entry.location != null) ...[
                      _buildSectionTitle(context, 'Location'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            FluentIcons.location,
                            color: Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            entry.location!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // 3. Details Grid
                    _buildSectionTitle(context, 'Details'),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      children: [
                        _buildDetailItem(
                          context,
                          'Price per Unit',
                          entry.formattedPricePerUnit,
                          FluentIcons.calculator_addition,
                        ),
                        if (entry.isTruckFuel && entry.odometerReading != null)
                          _buildDetailItem(
                            context,
                            'Odometer',
                            '${entry.odometerReading!.toStringAsFixed(0)} ${entry.distanceUnitLabel}',
                            FluentIcons.speed_high,
                          ),
                        if (!entry.isTruckFuel && entry.reeferHours != null)
                          _buildDetailItem(
                            context,
                            'Reefer Hours',
                            entry.reeferHours!.toStringAsFixed(1),
                            FluentIcons.clock,
                          ),
                      ],
                    ),
                  ],
                ),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
        color: FluentTheme.of(context).resources.textFillColorSecondary,
      ),
    );
  }

  Widget _buildBigStat(
    String label,
    String value,
    IconData icon,
    Color color,
    FluentThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.resources.controlFillColorSecondary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.resources.dividerStrokeColorDefault.withValues(
            alpha: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.typography.body?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = FluentTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.resources.textFillColorSecondary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.resources.textFillColorSecondary,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.typography.body?.color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _extractCityState(String address) {
  final parts = address.split(',');
  if (parts.length >= 3) {
    return '${parts[parts.length - 3].trim()}, ${parts[parts.length - 2].trim().split(' ')[0]}';
  } else if (parts.length == 2) {
    return '${parts[0].trim()}, ${parts[1].trim().split(' ')[0]}';
  }
  return address;
}

Widget _buildAvatar(BuildContext context, UserProfile driver, double size) {
  if (driver.avatarUrl != null && driver.avatarUrl!.isNotEmpty) {
    return ClipOval(
      child: Image.network(
        driver.avatarUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildInitialsAvatar(context, driver, size);
        },
      ),
    );
  }
  return _buildInitialsAvatar(context, driver, size);
}

Widget _buildInitialsAvatar(
  BuildContext context,
  UserProfile driver,
  double size,
) {
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

  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: FluentTheme.of(context).accentColor,
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Text(
      initials,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: size * 0.4,
      ),
    ),
  );
}
