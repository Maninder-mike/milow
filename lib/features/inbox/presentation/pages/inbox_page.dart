import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:milow/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1a1a2e),
                  const Color(0xFF16213e),
                  const Color(0xFF0f0f1a),
                ]
              : [
                  const Color(0xFFF0F4FF),
                  const Color(0xFFFDF2F8),
                  const Color(0xFFF0FDF4),
                ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.inbox ?? 'Inbox',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Messages and notifications',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildGlassyIconButton(Icons.search, isDark, textColor),
                    const SizedBox(width: 8),
                    _buildGlassyIconButton(Icons.more_vert, isDark, textColor),
                  ],
                ),
              ],
            ),
          ),
          // Glassy Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: const Color(0xFF6C5CE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : const Color(0xFF667085),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: const [
                      Tab(text: 'All'),
                      Tab(text: 'Unread'),
                      Tab(text: 'Archived'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAnnouncementList(isDark, textColor),
                // For now, these tabs duplicate content or can be filtered later
                _buildAnnouncementList(isDark, textColor, filter: 'unread'),
                _buildAnnouncementList(isDark, textColor, filter: 'archived'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassyIconButton(IconData icon, bool isDark, Color textColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(icon, color: textColor),
            onPressed: () {},
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementList(
    bool isDark,
    Color textColor, {
    String? filter,
  }) {
    // Filter logic can be added here (e.g. tracking read state locally or in a separate table)
    // For MVP, we just show all active announcements.
    final stream = Supabase.instance.client
        .from('announcements')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final announcements = snapshot.data!;

        if (announcements.isEmpty) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildPlaceholderCard(
                isDark,
                textColor,
                'Announcements will appear here',
                Icons.notifications_none,
              ),
              const SizedBox(height: 16),
              _buildInfoCard(isDark),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: announcements.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = announcements[index];
            final title = item['title'] ?? 'New Message';
            final body = item['body'] ?? '';
            final date =
                DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now();
            // version variable removed

            return Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.5),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: const Color(
                    0xFF6C5CE7,
                  ).withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.rocket_launch,
                    color: Color(0xFF6C5CE7),
                  ),
                ),
                title: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${DateFormat.yMMMd().format(date)} ${DateFormat.jm().format(date)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlaceholderCard(
    bool isDark,
    Color textColor,
    String message,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: 0.15),
                        Colors.white.withValues(alpha: 0.05),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.9),
                        Colors.white.withValues(alpha: 0.7),
                      ],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 48, color: const Color(0xFF6C5CE7)),
                ),
                const SizedBox(height: 20),
                Text(
                  'No messages yet',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : const Color(0xFF667085),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Coming soon',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6C5CE7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF6C5CE7),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About Inbox',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6C5CE7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This is where you\'ll receive messages from dispatchers, notifications about your trips, and important updates from your company.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF6C5CE7),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Extra padding for floating bottom nav bar
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
