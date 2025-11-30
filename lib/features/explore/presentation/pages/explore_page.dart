import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/widgets/app_scaffold.dart';
import 'package:milow/core/constants/design_tokens.dart';

// Dummy data widgets (must be above _ExplorePageState)
class DummyRouteCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const DummyRouteCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: Color(0xFF007AFF), size: 32),
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, style: GoogleFonts.inter()),
      ),
    );
  }
}

class DummyDestinationCard extends StatelessWidget {
  final String city;
  final String description;
  final IconData icon;
  const DummyDestinationCard({
    required this.city,
    required this.description,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: Color(0xFF007AFF), size: 32),
        title: Text(
          city,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(description, style: GoogleFonts.inter()),
      ),
    );
  }
}

class DummyActivityCard extends StatelessWidget {
  final String activity;
  final String time;
  final IconData icon;
  const DummyActivityCard({
    required this.activity,
    required this.time,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: Color(0xFF007AFF), size: 32),
        title: Text(
          activity,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(time, style: GoogleFonts.inter()),
      ),
    );
  }
}

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF9FAFB);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return AppScaffold(
      currentIndex: 0,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: backgroundColor,
            elevation: 0,
            floating: true,
            snap: true,
            title: Text(
              'Explore',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.search, color: textColor),
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(Icons.filter_list, color: textColor),
                onPressed: () {},
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(label: 'CATEGORIES'),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryChip('All Routes', Icons.route, true),
                        const SizedBox(width: 8),
                        _buildCategoryChip(
                          'Long Haul',
                          Icons.local_shipping,
                          false,
                        ),
                        const SizedBox(width: 8),
                        _buildCategoryChip(
                          'Regional',
                          Icons.map_outlined,
                          false,
                        ),
                        const SizedBox(width: 8),
                        _buildCategoryChip(
                          'Local',
                          Icons.location_on_outlined,
                          false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionHeaderRow(title: 'Featured Routes', onAction: () {}),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      DummyRouteCard(
                        title: 'Highway Express',
                        subtitle: 'Delhi → Mumbai',
                        icon: Icons.local_shipping,
                      ),
                      SizedBox(height: 10),
                      DummyRouteCard(
                        title: 'Coastal Runner',
                        subtitle: 'Chennai → Goa',
                        icon: Icons.directions_boat,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionHeaderRow(
                    title: 'Popular Destinations',
                    onAction: () {},
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      DummyDestinationCard(
                        city: 'Jaipur',
                        description: 'The Pink City',
                        icon: Icons.location_city,
                      ),
                      SizedBox(height: 10),
                      DummyDestinationCard(
                        city: 'Bangalore',
                        description: 'Tech Hub',
                        icon: Icons.apartment,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionHeaderRow(title: 'Recent Activity', onAction: () {}),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      DummyActivityCard(
                        activity: 'You booked Highway Express',
                        time: '2 hours ago',
                        icon: Icons.check_circle_outline,
                      ),
                      SizedBox(height: 10),
                      DummyActivityCard(
                        activity: 'New destination added: Goa',
                        time: 'Yesterday',
                        icon: Icons.new_releases,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, IconData icon, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF007AFF)
            : Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF007AFF)
              : Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF3A3A3A)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.white : const Color(0xFF667085),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF101828),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCard(
    Color cardColor,
    Color textColor,
    String message,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: const Color(0xFF007AFF)),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF667085),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Coming soon',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF007AFF),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<DesignTokens>() ?? DesignTokens.light;
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: tokens.sectionLabelColor,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SectionHeaderRow extends StatelessWidget {
  final String title;
  final VoidCallback? onAction;
  const _SectionHeaderRow({required this.title, this.onAction});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        if (onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              'See all',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF007AFF),
              ),
            ),
          ),
      ],
    );
  }
}
