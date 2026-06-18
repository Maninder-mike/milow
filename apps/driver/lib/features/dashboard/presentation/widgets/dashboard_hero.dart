import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/utils/responsive_layout.dart';
import 'package:milow/core/services/announcements_provider.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/features/dashboard/presentation/widgets/active_trip_card.dart';
import 'package:milow/features/dashboard/presentation/widgets/load_progress_card.dart';
import 'package:milow/features/dashboard/presentation/widgets/dashboard_card.dart';

class DashboardHero extends StatelessWidget {
  final Trip? activeTrip;
  final List<Load> assignedLoads;
  final Future<void> Function() onRefresh;
  final void Function(BuildContext, Trip, Offset) onShowActivityMenu;
  final Widget announcementBanner;
  final Widget? availableLoadBanner;
  final double margin;

  const DashboardHero({
    required this.assignedLoads, required this.onRefresh, required this.onShowActivityMenu, required this.announcementBanner, required this.margin, super.key,
    this.activeTrip,
    this.availableLoadBanner,
  });

  @override
  Widget build(BuildContext context) {
    // ENTERPRISE PATTERN: Capture nullable state in local final variable
    final trip = activeTrip;
    final bool showStartTrip = trip == null || trip.allDeliveriesCompleted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Content
        Padding(
          padding: EdgeInsets.fromLTRB(margin, 4, margin, 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Show Announcement Banner if available
              announcementBanner,

              if (context.watch<AnnouncementsProvider>().latestAnnouncement !=
                  null)
                SizedBox(height: context.tokens.spacingM),

              // Show 'Available Load' if there are assigned loads
              if (assignedLoads.any((l) => l.status == LoadStatus.assigned)) ...[
                ?availableLoadBanner,
                SizedBox(height: context.tokens.spacingM),
              ],

              // Show 'Start Trip' if no active trip OR active trip is completed
              if (showStartTrip) ...[
                Text(
                  'Track Your Journey',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: context.tokens.spacingM),
                // Hero Search Pill -> Replaced with "Start Trip" Button
                SizedBox(
                  width: double.infinity,
                  height: 56, // Tall button for easy tapping
                  child: FilledButton.icon(
                    onPressed: () async {
                      final result = await context.push('/add-entry');
                      if (result == true) {
                        unawaited(onRefresh());
                      }
                    },
                    icon: Icon(
                      Icons.add,
                      color: Theme.of(context).colorScheme.primary,
                      // Using primary color for icon on white/surface button
                    ),
                    label: Text(
                      'Start Trip',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white, // White against gradient
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          context.tokens.shapeFull,
                        ),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                SizedBox(height: context.tokens.spacingL),
              ],

              // Phase 3: Load Progress Tracking
              if (assignedLoads.any(
                (l) =>
                    l.status == LoadStatus.enRoute ||
                    l.status == LoadStatus.atStop,
              ))
                LoadProgressCard(
                  load: assignedLoads.firstWhere(
                    (l) =>
                        l.status == LoadStatus.enRoute ||
                        l.status == LoadStatus.atStop,
                  ),
                  onRefresh: onRefresh,
                ),

              // Only show active trip card if trip exists AND deliveries are pending
              if (trip != null && !trip.allDeliveriesCompleted)
                Padding(
                  padding: EdgeInsets.only(
                    top:
                        assignedLoads.any(
                          (l) =>
                              l.status == LoadStatus.enRoute ||
                              l.status == LoadStatus.atStop,
                        )
                        ? context.tokens.spacingM
                        : 0,
                  ),
                  child: GestureDetector(
                    onLongPressStart: (details) {
                      onShowActivityMenu(context, trip, details.globalPosition);
                    },
                    child: ActiveTripCard(
                      trip: trip,
                      onComplete: () async {
                        final result = await context.push(
                          '/add-entry',
                          extra: {'editingTrip': trip},
                        );
                        if (result == true) {
                          unawaited(onRefresh());
                        }
                      },
                    ),
                  ),
                )
              else
                // No active trip or trip is complete - show "Track Your Journey" + Pill
                const SizedBox.shrink(),
              SizedBox(height: context.tokens.spacingL),
            ],
          ),
        ),

        Padding(
          padding: EdgeInsets.symmetric(horizontal: margin),
          child: ResponsiveRow(
            // Use gutter for horizontal spacing (default),
            // and regular spacing for vertical run spacing matching prior design
            runSpacing: context.tokens.spacingM,
            children: [
              ResponsiveColumn(
                xs: 2, // 2 items per row on phone (4 cols total / 2)
                sm: 2, // 4 items per row on tablet (8 cols total / 2) -> Wait, 8/2 = 4 items? Yes.
                md: 3, // 4 items per row on desktop (12 cols total / 3) -> Yes.
                child: DashboardCard(
                  title: 'Inspections',
                  subtitle: 'Pre/Post Trip',
                  icon: Icons.checklist,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  onTap: () => context.push('/inspections'),
                ),
              ),
              ResponsiveColumn(
                xs: 2,
                sm: 2,
                md: 3,
                child: DashboardCard(
                  title: 'Documents',
                  subtitle: 'Permits & Regs',
                  icon: Icons.folder_open,
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  onTap: () => context.push(
                    '/scan-document',
                    extra: <String, dynamic>{},
                  ),
                ),
              ),
              ResponsiveColumn(
                xs: 2,
                sm: 2,
                md: 3,
                child: DashboardCard(
                  title: 'Expenses',
                  subtitle: 'Receipts & Logs',
                  icon: Icons.receipt_long_outlined,
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  onTap: () => context.push('/expenses'),
                ),
              ),
              ResponsiveColumn(
                xs: 2,
                sm: 2,
                md: 3,
                child: DashboardCard(
                  title: 'Explore',
                  subtitle: 'Analytics & Map',
                  icon: Icons.explore_outlined,
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  onTap: () => context.go('/explore'),
                ),
              ),
              ResponsiveColumn(
                xs: 2,
                sm: 2,
                md: 3,
                child: DashboardCard(
                  title: 'Inbox',
                  subtitle: 'Messages',
                  icon: Icons.chat_bubble_outline,
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  onTap: () => ResponsiveLayout.isMobile(context)
                      ? context.push('/inbox')
                      : context.go('/inbox'),
                ),
              ),
              ResponsiveColumn(
                xs: 2,
                sm: 2,
                md: 3,
                child: DashboardCard(
                  title: 'Settings',
                  subtitle: 'App Prefs',
                  icon: Icons.settings_outlined,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  onTap: () => context.go('/settings'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
