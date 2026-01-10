import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/quote_providers.dart';
import '../../domain/models/quote.dart';
import '../../../../core/constants/app_colors.dart';

class QuotesPage extends ConsumerStatefulWidget {
  const QuotesPage({super.key});

  @override
  ConsumerState<QuotesPage> createState() => _QuotesPageState();
}

class _QuotesPageState extends ConsumerState<QuotesPage> {
  String _statusFilter = 'All';
  final List<String> _statusOptions = ['All', 'draft', 'sent', 'won', 'lost'];

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final quotesAsync = ref.watch(quotesListProvider);

    return ScaffoldPage(
      header: null,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with filter
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Row(
              children: [
                Text(
                  'Quotes',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 150,
                  child: ComboBox<String>(
                    value: _statusFilter,
                    items: _statusOptions
                        .map(
                          (s) => ComboBoxItem<String>(
                            value: s,
                            child: Text(
                              s == 'All' ? 'All Statuses' : s.toUpperCase(),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _statusFilter = v ?? 'All'),
                    isExpanded: true,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(FluentIcons.arrow_sync_24_regular),
                  onPressed: () => ref.invalidate(quotesListProvider),
                ),
              ],
            ),
          ),
          // Quotes Table
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: quotesAsync.when(
                data: (allQuotes) {
                  final quotes = _statusFilter == 'All'
                      ? allQuotes
                      : allQuotes
                            .where((q) => q.status == _statusFilter)
                            .toList();

                  if (quotes.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildQuotesTable(quotes, theme);
                },
                loading: () => const Center(child: ProgressRing()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotesTable(List<Quote> quotes, FluentThemeData theme) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.resources.surfaceStrokeColorDefault.withValues(
            alpha: 0.05,
          ),
        ),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: theme.resources.surfaceStrokeColorDefault.withValues(
                alpha: 0.03,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildHeaderCell('Load Ref', flex: 2),
                _buildHeaderCell('Status', flex: 2),
                _buildHeaderCell('Total', flex: 2),
                _buildHeaderCell('Expires', flex: 2),
                _buildHeaderCell('Created', flex: 2),
                _buildHeaderCell('Actions', flex: 1),
              ],
            ),
          ),
          // Table Rows
          Expanded(
            child: ListView.separated(
              itemCount: quotes.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final quote = quotes[index];
                return Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Load Ref
                      Expanded(
                        flex: 2,
                        child: Text(
                          quote.loadReference.isNotEmpty
                              ? quote.loadReference
                              : 'N/A',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Status
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              quote.status,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            quote.status.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(quote.status),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      // Total
                      Expanded(
                        flex: 2,
                        child: Text(
                          '\$${quote.total.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            color: theme.accentColor,
                          ),
                        ),
                      ),
                      // Expires
                      Expanded(
                        flex: 2,
                        child: Text(
                          quote.expiresOn != null
                              ? dateFormat.format(quote.expiresOn!)
                              : '—',
                          style: GoogleFonts.outfit(
                            color: theme.resources.textFillColorSecondary,
                          ),
                        ),
                      ),
                      // Created
                      Expanded(
                        flex: 2,
                        child: Text(
                          quote.createdAt != null
                              ? dateFormat.format(quote.createdAt!)
                              : '—',
                          style: GoogleFonts.outfit(
                            color: theme.resources.textFillColorSecondary,
                          ),
                        ),
                      ),
                      // Actions
                      Expanded(
                        flex: 1,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                FluentIcons.delete_24_regular,
                                size: 18,
                                color: AppColors.error,
                              ),
                              onPressed: () => _deleteQuote(quote),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: FluentTheme.of(context).resources.textFillColorSecondary,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(FluentIcons.document_24_regular, size: 48),
          const SizedBox(height: 16),
          Text(
            'No quotes found',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Quotes created from loads will appear here.'),
        ],
      ),
    );
  }

  Future<void> _deleteQuote(Quote quote) async {
    await ref.read(quoteControllerProvider.notifier).deleteQuote(quote.id);
    if (!mounted) return;
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: const Text('Quote Deleted'),
        content: Text('Quote for ${quote.loadReference} deleted.'),
        severity: InfoBarSeverity.success,
        onClose: close,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return AppColors.neutral;
      case 'sent':
        return AppColors.info;
      case 'won':
        return AppColors.success;
      case 'lost':
        return AppColors.error;
      default:
        return AppColors.neutral;
    }
  }
}
