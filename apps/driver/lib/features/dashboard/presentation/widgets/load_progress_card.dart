import 'package:flutter/material.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/services/load_repository.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/widgets/m3_spring_button.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class LoadProgressCard extends StatelessWidget {
  final Load load;
  final VoidCallback onRefresh;

  const LoadProgressCard({
    required this.load,
    required this.onRefresh,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;

    // Determine current active stop
    final nextStop = load.stops.firstWhere(
      (s) => !s.isCompleted,
      orElse: () => load.stops.last,
    );

    final bool isArrived = nextStop.arrivedAt != null;
    final int completedStops = load.stops.where((s) => s.isCompleted).length;
    final double progress = load.stops.isEmpty
        ? 0
        : completedStops / load.stops.length;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.shapeL),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/load-details/${load.id}'),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Load # and Type
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACTIVE LOAD',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        '#${load.tripNumber}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  _buildStatusBadge(context, load.status),
                ],
              ),
              const SizedBox(height: 16),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(tokens.shapeFull),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$completedStops of ${load.stops.length} stops completed',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
              ),
              const SizedBox(height: 20),

              // Next Stop Info
              Container(
                padding: EdgeInsets.all(tokens.spacingM),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(tokens.shapeM),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isArrived
                            ? tokens.warning.withValues(alpha: 0.1)
                            : colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isArrived ? Icons.location_on : Icons.near_me_outlined,
                        size: 20,
                        color: isArrived ? tokens.warning : colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArrived ? 'Currently At' : 'Next Stop',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: tokens.textTertiary),
                          ),
                          Text(
                            nextStop.location.city,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (nextStop.appointmentTime != null)
                            Text(
                              'Appt: ${DateFormat.Hm().format(nextStop.appointmentTime!)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    M3SpringButton(
                      onTap: () async {
                        if (isArrived) {
                          await LoadRepository.updateStopStatus(
                            nextStop.id,
                            load.id,
                            true,
                          );
                        } else {
                          await LoadRepository.updateStopArrival(
                            nextStop.id,
                            load.id,
                            DateTime.now(),
                          );
                        }
                        onRefresh();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isArrived
                              ? tokens.success
                              : colorScheme.primary,
                          borderRadius: BorderRadius.circular(tokens.shapeFull),
                        ),
                        child: Text(
                          isArrived ? 'DONE' : 'ARRIVED',
                          style: TextStyle(
                            color: isArrived
                                ? Colors.white
                                : colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, LoadStatus status) {
    final tokens = context.tokens;
    Color color = tokens.textTertiary;
    if (status == LoadStatus.enRoute) color = Colors.orange;
    if (status == LoadStatus.atStop) color = tokens.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(tokens.shapeS),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
