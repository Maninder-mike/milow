import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow_core/milow_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/driver_selection_provider.dart';

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
    final isLight = theme.brightness == Brightness.light;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page Title
          Text(
            'Driver Profile: ${driver.fullName ?? 'Unknown'}',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Top Row: Photo + Contact Info + License | Recent Activity | Safety Score
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: Photo + Contact + License stacked
                SizedBox(
                  width: 400,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo with assign button below
                      Column(
                        children: [
                          _buildPhotoCard(context, isLight),
                          const SizedBox(height: 12),
                          // Assign button
                          SizedBox(
                            width: 160,
                            child: FilledButton(
                              onPressed: () => _showAssignDialog(context),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(FluentIcons.add, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Assign',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            _buildContactCard(context, isLight),
                            const SizedBox(height: 16),
                            _buildLicenseCard(context, isLight),
                            const SizedBox(height: 16),
                            _buildStatusCard(context, isLight),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // Center: Recent Activity
                Expanded(
                  flex: 2,
                  child: _buildRecentActivityCard(context, isLight),
                ),
                const SizedBox(width: 24),

                // Right: Safety Score
                SizedBox(
                  width: 220,
                  child: _buildSafetyScoreCard(context, isLight),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Bottom Row: Nationality & Visa + Performance Stats + Earnings
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Quick Actions
              SizedBox(
                width: 400,
                child: Column(
                  children: [
                    _buildNationalityVisaCard(context, isLight),
                    const SizedBox(height: 16),
                    _buildQuickActionsRow(context, isLight),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // Center: Performance Stats
              Expanded(child: _buildPerformanceStatsCard(context, isLight)),
              const SizedBox(width: 24),

              // Right: Earnings
              SizedBox(width: 220, child: _buildEarningsCard(context, isLight)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(BuildContext context, bool isLight) {
    return Container(
      width: 160,
      height: 200,
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: driver.avatarUrl != null && driver.avatarUrl!.isNotEmpty
          ? Image.network(
              driver.avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildAvatarPlaceholder(context),
            )
          : _buildAvatarPlaceholder(context),
    );
  }

  Widget _buildAvatarPlaceholder(BuildContext context) {
    final theme = FluentTheme.of(context);
    String initials = '?';
    if (driver.fullName != null && driver.fullName!.isNotEmpty) {
      final parts = driver.fullName!.trim().split(' ');
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty) {
        initials = parts[0][0].toUpperCase();
      }
    }
    return Container(
      color: theme.accentColor.defaultBrushFor(theme.brightness),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required bool isLight,
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
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
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, bool isLight) {
    return _buildInfoCard(
      context: context,
      isLight: isLight,
      title: 'Contact Info',
      children: [
        _buildInfoRow('Phone', driver.phone ?? 'Not set'),
        const SizedBox(height: 8),
        _buildInfoRow('Email', driver.email ?? '-'),
      ],
    );
  }

  Widget _buildLicenseCard(BuildContext context, bool isLight) {
    // TODO: Implement license fields in Supabase profiles table:
    // - cdl_class (text)
    // - license_number (text)
    // - license_expiry (date)
    // Then fetch from driver profile and display real data
    final licenseExpiry = DateTime.now().add(
      const Duration(days: 365),
    ); // Placeholder - replace with driver.licenseExpiry
    final isExpiringSoon = licenseExpiry.difference(DateTime.now()).inDays < 30;

    return _buildInfoCard(
      context: context,
      isLight: isLight,
      title: 'License Details',
      trailing: isExpiringSoon
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Expiring Soon',
                style: TextStyle(fontSize: 10, color: Colors.orange),
              ),
            )
          : null,
      children: [
        _buildInfoRow('CDL Class', 'Class A'), // TODO: Real data
        const SizedBox(height: 8),
        _buildInfoRow('Exp', DateFormat('MM/yyyy').format(licenseExpiry)),
      ],
    );
  }

  Widget _buildNationalityVisaCard(BuildContext context, bool isLight) {
    // TODO: Add nationality and visa data from driver profile when available
    final visaExpiry = DateTime.now().add(
      const Duration(days: 45),
    ); // Placeholder
    final isExpiringSoon = visaExpiry.difference(DateTime.now()).inDays < 30;

    return _buildInfoCard(
      context: context,
      isLight: isLight,
      title: 'Nationality & Visa',
      trailing: isExpiringSoon
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Visa Expiring!',
                style: TextStyle(fontSize: 10, color: Colors.red),
              ),
            )
          : null,
      children: [
        _buildInfoRow('Nationality', 'Canadian'), // TODO: Real data
        const SizedBox(height: 8),
        _buildInfoRow('Visa Exp', DateFormat('MM/dd/yyyy').format(visaExpiry)),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context, bool isLight) {
    return _buildInfoCard(
      context: context,
      isLight: isLight,
      title: 'Current Status',
      children: [
        _buildInfoRow('Status', 'On Duty - Driving'), // TODO: Real data
        const SizedBox(height: 8),
        _buildInfoRow('Truck', '#4092'), // TODO: Real data
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[100])),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _showAssignDialog(BuildContext context) {
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
            // TODO: Replace with actual trip/truck selection from backend
            ListTile(
              leading: Icon(FluentIcons.open_folder_horizontal),
              title: const Text('Assign Trip'),
              subtitle: const Text('Select an available trip'),
              onPressed: () {
                Navigator.pop(context);
                // TODO: Show trip selection dialog
              },
            ),
            ListTile(
              leading: Icon(FluentIcons.car),
              title: const Text('Assign Truck'),
              subtitle: const Text('Select an available truck'),
              onPressed: () {
                Navigator.pop(context);
                // TODO: Show truck selection dialog
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

  Widget _buildQuickActionsRow(BuildContext context, bool isLight) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: () {
              // TODO: Implement call functionality
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(FluentIcons.phone, size: 16),
                const SizedBox(width: 8),
                const Text('Call Driver'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Button(
            onPressed: () => _showSendMessageDialog(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(FluentIcons.chat, size: 16),
                const SizedBox(width: 8),
                const Text('Send Message'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSendMessageDialog(BuildContext context) {
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Text('Send Message to ${driver.fullName ?? 'Driver'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextBox(
              controller: messageController,
              placeholder: 'Type your message...',
              maxLines: 5,
              minLines: 3,
            ),
          ],
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          FilledButton(
            child: const Text('Send'),
            onPressed: () async {
              if (messageController.text.trim().isNotEmpty) {
                // Send message via Supabase
                await Supabase.instance.client.from('messages').insert({
                  'receiver_id': driver.id,
                  'content': messageController.text.trim(),
                });
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard(BuildContext context, bool isLight) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
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
              Text(
                'Recent Activity',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(FluentIcons.more, size: 16),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder(
              future: Supabase.instance.client
                  .from('trips')
                  .select()
                  .eq('user_id', driver.id)
                  .order('trip_date', ascending: false)
                  .limit(5),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: ProgressRing());
                }
                final data = snapshot.data as List<dynamic>? ?? [];
                if (data.isEmpty) {
                  return const Center(child: Text('No recent activity'));
                }
                return ListView.separated(
                  itemCount: data.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final trip = data[index];
                    return _buildActivityItem(
                      'Trip #${trip['trip_number'] ?? index + 1}',
                      'Completed',
                      _timeAgo(DateTime.tryParse(trip['trip_date'] ?? '')),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String status, String timeAgo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title: $status',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  timeAgo,
                  style: TextStyle(fontSize: 11, color: Colors.grey[100]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(FluentIcons.more, size: 14),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return '-';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  Widget _buildSafetyScoreCard(BuildContext context, bool isLight) {
    // TODO: Implement real safety score data later
    const score = 92;
    final scoreColor = score >= 80
        ? Colors.green
        : (score >= 60 ? Colors.orange : Colors.red);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Safety Score',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(FluentIcons.more, size: 16),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Circular Gauge (Simple representation)
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: ProgressRing(
                    value: score.toDouble(),
                    strokeWidth: 10,
                    backgroundColor: scoreColor.withValues(alpha: 0.2),
                    activeColor: scoreColor,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    Text(
                      '/100',
                      style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Green',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scoreColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceStatsCard(BuildContext context, bool isLight) {
    // TODO: Implement real performance data later
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
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
          Text(
            'Performance Stats',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatRow('Miles Driven This Month', '8,450'),
          const Divider(),
          _buildStatRow('On-Time Delivery', '98%'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[100]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(FluentIcons.more, size: 14),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsCard(BuildContext context, bool isLight) {
    // TODO: Implement real earnings data later
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
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
          Text(
            'Earnings Summary',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '\$12,450',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'This Month',
            style: TextStyle(fontSize: 11, color: Colors.grey[100]),
          ),
        ],
      ),
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
