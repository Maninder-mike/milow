import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:milow/features/explore/presentation/providers/explore_provider.dart';
import 'package:milow/core/widgets/glassy_card.dart';
import 'package:milow/core/constants/design_tokens.dart';

class StateCollectorCard extends StatelessWidget {
  final VoidCallback? onTap;

  const StateCollectorCard({this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    return Consumer<ExploreProvider>(
      builder: (context, provider, child) {
        final visitedStates = provider.visitedStates;
        final count = visitedStates.length;
        const total = 50;
        final progress = count / total;

        return GlassyCard(
          onTap: onTap,
          borderRadius: tokens.shapeXL,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STATE COLLECTOR',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your trucking legacy',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.stars_rounded,
                    color: colorScheme.primary,
                    size: 28,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  SizedBox(
                    height: 80,
                    width: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 80,
                          width: 80,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 8,
                            backgroundColor:
                                colorScheme.primary.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.primary,
                            ),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$count',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: colorScheme.onSurface,
                                  ),
                            ),
                            Text(
                              'of $total',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next Milestone',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getMilestoneMessage(count),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: (count % 10) / 10,
                          backgroundColor:
                              colorScheme.primary.withValues(alpha: 0.1),
                          color: colorScheme.primary,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (visitedStates.isNotEmpty) ...[
                const SizedBox(height: 32),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: visitedStates.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final statesList = visitedStates.toList();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(tokens.shapeFull),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          statesList[index],
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _getMilestoneMessage(int count) {
    if (count < 10) return 'Collect 10 states for "Rookie Ranger"';
    if (count < 25) return 'Collect 25 states for "Highway Hero"';
    if (count < 40) return 'Collect 40 states for "Interstate Icon"';
    if (count < 50) return 'Finish the US for "Total Legend"';
    return 'You have conquered the US!';
  }
}
