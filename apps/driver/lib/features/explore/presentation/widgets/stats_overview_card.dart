import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:milow/core/services/preferences_service.dart';
import 'package:milow/core/widgets/glassy_card.dart';
import 'package:milow/features/explore/presentation/providers/explore_provider.dart';
import 'package:milow/core/constants/design_tokens.dart';

class StatsOverviewCard extends StatelessWidget {
  const StatsOverviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency(decimalDigits: 0);
    final numberFormat = NumberFormat.decimalPattern();
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    return Consumer<ExploreProvider>(
      builder: (context, provider, child) {
        return GlassyCard(
          borderRadius: tokens.shapeXL,
          padding: EdgeInsets.symmetric(vertical: tokens.spacingL, horizontal: tokens.spacingS),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 20),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'MONTHLY PERFORMANCE',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    context,
                    icon: Icons.speed_rounded,
                    label: provider.unitSystem == UnitSystem.metric
                        ? 'Kilometers'
                        : 'Miles',
                    value: provider.statsTotalDistance,
                    formatter: (val) => numberFormat.format(val),
                    color: colorScheme.primary,
                  ),
                  _buildStatItem(
                    context,
                    icon: Icons.local_gas_station_rounded,
                    label: 'Fuel Cost',
                    value: provider.statsFuelCost,
                    formatter: (val) => currencyFormat.format(val),
                    color: colorScheme.secondary,
                  ),
                  _buildStatItem(
                    context,
                    icon: Icons.local_shipping_rounded,
                    label: 'Trips',
                    value: provider.statsTripCount.toDouble(),
                    formatter: (val) => val.toInt().toString(),
                    color: colorScheme.tertiary,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required double value,
    required String Function(double) formatter,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        _RollingNumber(
          value: value,
          formatter: formatter,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _RollingNumber extends StatefulWidget {
  final double value;
  final String Function(double) formatter;
  final TextStyle? style;

  const _RollingNumber({
    required this.value,
    required this.formatter,
    this.style,
  });

  @override
  State<_RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<_RollingNumber>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _oldValue = 0;

  @override
  void initState() {
    super.initState();
    _oldValue = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(_RollingNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value;
      _animation = Tween<double>(begin: _oldValue, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo),
      );
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          widget.formatter(_animation.value),
          style: widget.style,
        );
      },
    );
  }
}
