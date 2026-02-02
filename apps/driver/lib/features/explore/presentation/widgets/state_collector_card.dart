import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:milow/features/explore/presentation/providers/explore_provider.dart';

class StateCollectorCard extends StatelessWidget {
  final VoidCallback? onTap;

  const StateCollectorCard({this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<ExploreProvider>(
      builder: (context, provider, child) {
        final visitedStates = provider.visitedStates;
        final count = visitedStates.length;
        const total = 50;
        final progress = count / total;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
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
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your trucking legacy',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
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
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '$count',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '/ $total',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${(progress * 100).toInt()}%',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.primary,
                    ),
                    minHeight: 10,
                  ),
                ),
                if (visitedStates.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: visitedStates.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final statesList = visitedStates.toList();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: Text(
                            statesList[index],
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
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
          ),
        );
      },
    );
  }
}
