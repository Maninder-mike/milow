import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_elevation.dart';
import '../../domain/models/settlement_summary.dart';

class SettlementKPICards extends StatelessWidget {
  final SettlementSummary summary;

  const SettlementKPICards({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: r'$');

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns = 4;
        if (width < 1000) columns = 2;
        if (width < 600) columns = 1;

        final spacing = 16.0;
        final cardWidth = (width - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildCard(
                context: context,
                title: 'Total Pending',
                value: currencyFormat.format(summary.totalPending),
                icon: FluentIcons.money,
                color: Colors.orange,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildCard(
                context: context,
                title: 'Total Paid',
                value: currencyFormat.format(summary.totalPaid),
                icon: FluentIcons.check_mark,
                color: Colors.green,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildCard(
                context: context,
                title: 'Average Payout',
                value: currencyFormat.format(summary.averagePayout),
                icon: FluentIcons.bar_chart4,
                color: Colors.blue,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildCard(
                context: context,
                title: 'Unsettled Items',
                value: summary.unsettledItemsCount.toString(),
                icon: FluentIcons.warning,
                color: summary.unsettledItemsCount > 0
                    ? Colors.red
                    : Colors.grey,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = FluentTheme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    // Create a subtle border and background tint using the semantic color
    final bgColor = isDark ? theme.cardColor : theme.cardColor;
    final borderColor = color.withValues(alpha: isDark ? 0.3 : 0.4);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: AppElevation.shadow2(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: theme.resources.textFillColorSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.resources.textFillColorPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
