import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../providers/quote_providers.dart';
import '../providers/load_providers.dart';
import '../widgets/load_quote_dialog.dart' hide QuoteLineItem;
import '../../domain/models/quote.dart';
import '../../domain/models/load.dart';
import '../../../../core/constants/app_colors.dart';

class QuotesPage extends ConsumerStatefulWidget {
  const QuotesPage({super.key});

  @override
  ConsumerState<QuotesPage> createState() => _QuotesPageState();
}

class _QuotesPageState extends ConsumerState<QuotesPage> {
  // Filters
  String _statusFilter = 'All';
  final List<String> _statusOptions = ['All', 'draft', 'sent', 'won', 'lost'];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Sorting
  String _sortColumn = 'createdAt';
  bool _sortAscending = false;

  // Bulk selection
  final Set<String> _selectedIds = {};
  bool _selectAll = false;

  // Cached loads for route/customer info
  Map<String, Load> _loadCache = {};

  // Keyboard Navigation
  final FocusNode _listFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  int? _focusedIndex;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      ref.read(quotesListProvider).whenData((quotes) {
        final filtered = _filterQuotes(
          quotes,
        ); // We need to operate on filtered list
        if (filtered.isEmpty) return;

        setState(() {
          if (_focusedIndex == null || _focusedIndex! >= filtered.length - 1) {
            _focusedIndex = 0;
          } else {
            _focusedIndex = _focusedIndex! + 1;
          }
        });
        _scrollToFocused();
      });
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      ref.read(quotesListProvider).whenData((quotes) {
        final filtered = _filterQuotes(quotes);
        if (filtered.isEmpty) return;

        setState(() {
          if (_focusedIndex == null || _focusedIndex! <= 0) {
            _focusedIndex = filtered.length - 1;
          } else {
            _focusedIndex = _focusedIndex! - 1;
          }
        });
        _scrollToFocused();
      });
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_focusedIndex != null) {
        ref.read(quotesListProvider).whenData((quotes) {
          final filtered = _filterQuotes(quotes);
          if (_focusedIndex! < filtered.length) {
            _editQuote(filtered[_focusedIndex!]);
          }
        });
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.space) {
      if (_focusedIndex != null) {
        ref.read(quotesListProvider).whenData((quotes) {
          final filtered = _filterQuotes(quotes);
          if (_focusedIndex! < filtered.length) {
            final id = filtered[_focusedIndex!].id;
            final isSelected = _selectedIds.contains(id);
            _toggleSelection(id, !isSelected);
          }
        });
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _scrollToFocused() {
    if (_focusedIndex == null) return;
    // Simple scrolling: assumed item height 56 + separator 1 ~ 57 approx
    // Better to use AutoScrollController but simple math works for fixed height
    const itemHeight = 57.0;
    final offset = _focusedIndex! * itemHeight;

    // Check if visible
    final minScroll = _scrollController.position.pixels;
    final maxScroll = minScroll + _scrollController.position.viewportDimension;

    if (offset < minScroll) {
      _scrollController.jumpTo(offset);
    } else if (offset + itemHeight > maxScroll) {
      _scrollController.jumpTo(
        offset + itemHeight - _scrollController.position.viewportDimension,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final quotesAsync = ref.watch(quotesListProvider);
    final loadsAsync = ref.watch(loadsListProvider);

    // Cache loads for quick lookup
    loadsAsync.whenData((loads) {
      _loadCache = {for (var l in loads) l.id: l};
    });

    return ScaffoldPage(
      header: null,
      content: quotesAsync.when(
        data: (allQuotes) {
          // Apply filters
          var quotes = _filterQuotes(allQuotes);
          // Apply sorting
          quotes = _sortQuotes(quotes);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stats Row
              _buildStatsRow(allQuotes, theme, isLight),
              const SizedBox(height: 16),
              // Header with search and filters
              _buildHeader(theme),
              const SizedBox(height: 8),

              // Table
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: quotes.isEmpty
                      ? _buildEmptyState()
                      : _buildQuotesTable(quotes, theme, isLight),
                ),
              ),
            ],
          );
        },
        loading: () => _buildLoadingState(theme),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOADING SKELETON
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLoadingState(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stats Row Skeleton
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: List.generate(3, (index) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: index == 0 ? 0 : 16),
                  child: Container(
                    height: 80,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.resources.surfaceStrokeColorDefault
                            .withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.resources.controlFillColorSecondary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 12,
                              decoration: BoxDecoration(
                                color:
                                    theme.resources.controlFillColorSecondary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 120,
                              height: 20,
                              decoration: BoxDecoration(
                                color:
                                    theme.resources.controlFillColorSecondary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        // Header Skeleton
        _buildHeader(theme),
        const SizedBox(height: 8),
        // Table Skeleton
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Container(
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
                      color: theme.resources.surfaceStrokeColorDefault
                          .withValues(alpha: 0.03),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          child: Center(
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color:
                                      theme.resources.controlFillColorSecondary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        for (var flex in [1, 2, 3, 1, 2, 2, 2])
                          Expanded(
                            flex: flex,
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(
                                end: 16,
                              ),
                              child: Container(
                                height: 14,
                                decoration: BoxDecoration(
                                  color:
                                      theme.resources.controlFillColorSecondary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Rows
                  Expanded(
                    child: ListView.separated(
                      itemCount: 10,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        return Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: Center(
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: theme
                                            .resources
                                            .controlFillColorSecondary
                                            .withValues(alpha: 0.5),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              for (var flex in [1, 2, 3, 1, 2, 2, 2])
                                Expanded(
                                  flex: flex,
                                  child: Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      end: 16,
                                    ),
                                    child: Container(
                                      height: 16,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: theme
                                            .resources
                                            .controlFillColorSecondary
                                            .withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
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
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATS ROW
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStatsRow(
    List<Quote> allQuotes,
    FluentThemeData theme,
    bool isLight,
  ) {
    final totalValue = allQuotes.fold(0.0, (sum, q) => sum + q.total);
    final openQuotes = allQuotes
        .where((q) => q.status == 'draft' || q.status == 'sent')
        .length;
    final wonQuotes = allQuotes.where((q) => q.status == 'won').length;
    final winRate = allQuotes.isNotEmpty
        ? (wonQuotes / allQuotes.length * 100).toStringAsFixed(1)
        : '0.0';
    final now = DateTime.now();
    final expiringSoon = allQuotes.where((q) {
      if (q.expiresOn == null) return false;
      final daysUntil = q.expiresOn!.difference(now).inDays;
      return daysUntil >= 0 && daysUntil <= 3 && q.status != 'won';
    }).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Value',
              '\$${NumberFormat('#,##0.00').format(totalValue)}',
              FluentIcons.money_24_regular,
              theme.accentColor,
              theme,
              isLight,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Open Quotes',
              openQuotes.toString(),
              FluentIcons.document_24_regular,
              AppColors.info,
              theme,
              isLight,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Win Rate',
              '$winRate%',
              FluentIcons.trophy_24_regular,
              AppColors.success,
              theme,
              isLight,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Expiring Soon',
              expiringSoon.toString(),
              FluentIcons.warning_24_regular,
              expiringSoon > 0 ? AppColors.warning : AppColors.neutral,
              theme,
              isLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    FluentThemeData theme,
    bool isLight,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.resources.surfaceStrokeColorDefault.withValues(
            alpha: 0.1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER WITH SEARCH & FILTERS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(FluentThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
          // Search
          SizedBox(
            width: 250,
            child: TextBox(
              controller: _searchController,
              placeholder: 'Search quotes...',
              prefix: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(FluentIcons.search_24_regular, size: 16),
              ),
              suffix: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        FluentIcons.dismiss_24_regular,
                        size: 14,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          // Status filter
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
              onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
              isExpanded: true,
            ),
          ),
          if (_selectedIds.isNotEmpty) ...[
            const SizedBox(width: 16),
            Container(
              height: 20,
              width: 1,
              color: theme.resources.surfaceStrokeColorDefault,
            ),
            const SizedBox(width: 16),
            Button(onPressed: _clearSelection, child: const Text('Clear')),
            const SizedBox(width: 8),
            ComboBox<String>(
              placeholder: const Text('Change Status'),
              items: ['draft', 'sent', 'won', 'lost']
                  .map(
                    (s) => ComboBoxItem<String>(
                      value: s,
                      child: Text(s.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) _bulkChangeStatus(v);
              },
            ),
            const SizedBox(width: 8),
            Button(
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(
                  AppColors.error.withValues(alpha: 0.1),
                ),
              ),
              onPressed: _bulkDelete,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    FluentIcons.delete_24_regular,
                    size: 16,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Text('Delete', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
          const Spacer(),
          // Refresh
          IconButton(
            icon: const Icon(FluentIcons.arrow_sync_24_regular),
            onPressed: () => ref.invalidate(quotesListProvider),
          ),
          const SizedBox(width: 8),
          // Export CSV
          Button(
            onPressed: _selectedIds.isEmpty ? null : _exportToCsv,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FluentIcons.arrow_download_24_regular, size: 16),
                const SizedBox(width: 6),
                const Text('Export'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // QUOTES TABLE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildQuotesTable(
    List<Quote> quotes,
    FluentThemeData theme,
    bool isLight,
  ) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final now = DateTime.now();

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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Checkbox
                SizedBox(
                  width: 40,
                  child: Checkbox(
                    checked: _selectAll,
                    onChanged: (v) => _toggleSelectAll(quotes, v ?? false),
                  ),
                ),
                const SizedBox(width: 12),
                _buildSortableHeader('Trip #', 'tripNumber', flex: 1),
                _buildSortableHeader('Customer', 'customer', flex: 2),
                _buildSortableHeader('Route', 'route', flex: 3),
                _buildSortableHeader('Status', 'status', flex: 1),
                _buildSortableHeader('Total', 'total', flex: 2),
                _buildSortableHeader('Expires', 'expiresOn', flex: 2),
                _buildSortableHeader('Created', 'createdAt', flex: 2),
              ],
            ),
          ),
          // Table Rows
          Expanded(
            child: Focus(
              focusNode: _listFocusNode,
              onKeyEvent: _handleKeyEvent,
              child: ListView.separated(
                controller: _scrollController,
                itemCount: quotes.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final quote = quotes[index];
                  final load = _loadCache[quote.loadId];
                  final isSelected = _selectedIds.contains(quote.id);
                  final isFocused = index == _focusedIndex;

                  return _QuoteTableRow(
                    quote: quote,
                    load: load,
                    isSelected: isSelected,
                    isFocused: isFocused,
                    now: now,
                    theme: theme,
                    dateFormat: dateFormat,
                    onToggleSelection: (v) => _toggleSelection(quote.id, v),
                    onEdit: () => _editQuote(quote),
                    onClone: () => _cloneQuote(quote),
                    onChangeStatus: (status) =>
                        _changeQuoteStatus(quote, status),
                    onDelete: () => _deleteQuote(quote, load),
                    getStatusColor: _getStatusColor,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortableHeader(String text, String column, {int flex = 1}) {
    final isActive = _sortColumn == column;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => _onSort(column),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Row(
            children: [
              Text(
                text,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isActive
                      ? FluentTheme.of(context).accentColor
                      : FluentTheme.of(
                          context,
                        ).resources.textFillColorSecondary,
                ),
              ),
              if (isActive)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    _sortAscending
                        ? FluentIcons.arrow_up_24_regular
                        : FluentIcons.arrow_down_24_regular,
                    size: 12,
                    color: FluentTheme.of(context).accentColor,
                  ),
                ),
            ],
          ),
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

  // ─────────────────────────────────────────────────────────────────────────
  // FILTERING & SORTING
  // ─────────────────────────────────────────────────────────────────────────
  List<Quote> _filterQuotes(List<Quote> quotes) {
    var filtered = quotes;

    // Status filter
    if (_statusFilter != 'All') {
      filtered = filtered.where((q) => q.status == _statusFilter).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((q) {
        final load = _loadCache[q.loadId];
        final loadRef = q.loadReference.toLowerCase();
        final customer = (load?.brokerName ?? '').toLowerCase();
        final origin = load != null
            ? '${load.pickup.city} ${load.pickup.state}'.toLowerCase()
            : '';
        final dest = load != null
            ? '${load.delivery.city} ${load.delivery.state}'.toLowerCase()
            : '';
        return loadRef.contains(_searchQuery) ||
            customer.contains(_searchQuery) ||
            origin.contains(_searchQuery) ||
            dest.contains(_searchQuery);
      }).toList();
    }

    return filtered;
  }

  List<Quote> _sortQuotes(List<Quote> quotes) {
    final sorted = List<Quote>.from(quotes);
    sorted.sort((a, b) {
      int comparison = 0;
      switch (_sortColumn) {
        case 'loadReference':
          comparison = a.loadReference.compareTo(b.loadReference);
        case 'customer':
          final aCustomer = _loadCache[a.loadId]?.brokerName ?? '';
          final bCustomer = _loadCache[b.loadId]?.brokerName ?? '';
          comparison = aCustomer.compareTo(bCustomer);
        case 'total':
          comparison = a.total.compareTo(b.total);
        case 'status':
          comparison = a.status.compareTo(b.status);
        case 'expiresOn':
          final aDate = a.expiresOn ?? DateTime(2099);
          final bDate = b.expiresOn ?? DateTime(2099);
          comparison = aDate.compareTo(bDate);
        case 'createdAt':
        default:
          final aDate = a.createdAt ?? DateTime(2000);
          final bDate = b.createdAt ?? DateTime(2000);
          comparison = aDate.compareTo(bDate);
      }
      return _sortAscending ? comparison : -comparison;
    });
    return sorted;
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BULK OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────
  void _toggleSelectAll(List<Quote> quotes, bool selected) {
    setState(() {
      _selectAll = selected;
      if (selected) {
        _selectedIds.addAll(quotes.map((q) => q.id));
      } else {
        _selectedIds.clear();
      }
    });
  }

  void _toggleSelection(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
        _selectAll = false;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _selectAll = false;
    });
  }

  Future<void> _bulkDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Delete Selected Quotes'),
        content: Text(
          'Are you sure you want to delete ${_selectedIds.length} quotes? This action cannot be undone.',
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(AppColors.error),
            ),
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final id in _selectedIds) {
        await ref.read(quoteControllerProvider.notifier).deleteQuote(id);
      }
      _clearSelection();
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Quotes Deleted'),
            severity: InfoBarSeverity.success,
            onClose: close,
          ),
        );
      }
    }
  }

  Future<void> _bulkChangeStatus(String status) async {
    for (final id in _selectedIds) {
      await ref
          .read(quoteControllerProvider.notifier)
          .updateQuoteStatus(id, status);
    }
    _clearSelection();
    if (mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: Text(
            '${_selectedIds.length} quotes updated to ${status.toUpperCase()}',
          ),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    }
  }

  void _exportToCsv() async {
    final quotesAsync = ref.read(quotesListProvider);
    final List<Quote> quotes = quotesAsync.maybeWhen(
      data: (data) => data,
      orElse: () => [],
    );

    if (quotes.isEmpty) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('No quotes to export'),
          severity: InfoBarSeverity.warning,
          onClose: close,
        ),
      );
      return;
    }

    // Build CSV content
    final buffer = StringBuffer();

    // Header row
    buffer.writeln('Load Ref,Customer,Route,Status,Total,Expires,Created');

    // Data rows
    for (final quote in quotes) {
      final load = _loadCache[quote.loadId];
      final customer = load?.brokerName ?? '';
      final route = load != null
          ? '${load.pickup.city} ${load.pickup.state} → ${load.delivery.city} ${load.delivery.state}'
          : '';
      final status = quote.status;
      final total = quote.total.toStringAsFixed(2);
      final expires = quote.expiresOn != null
          ? DateFormat('yyyy-MM-dd').format(quote.expiresOn!)
          : '';
      final created = quote.createdAt != null
          ? DateFormat('yyyy-MM-dd').format(quote.createdAt!)
          : '';

      // Escape fields with commas
      buffer.writeln(
        '"${quote.loadReference}","$customer","$route","$status","$total","$expires","$created"',
      );
    }

    // Copy to clipboard for now (file save requires file_picker package)
    // In production, use file_picker or path_provider to save file
    try {
      final csvContent = buffer.toString();

      // For desktop, we can use a simple approach
      final now = DateTime.now();
      final filename =
          'quotes_export_${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';

      // Show the content in a dialog with copy option
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => ContentDialog(
          title: Text('Export: $filename'),
          content: SizedBox(
            width: 500,
            height: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${quotes.length} quotes exported',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FluentTheme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: FluentTheme.of(
                          context,
                        ).resources.dividerStrokeColorDefault,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        csvContent,
                        style: GoogleFonts.sourceCodePro(fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                // Copy to clipboard
                // In production, save to file using path_provider
                Navigator.pop(context);
                displayInfoBar(
                  context,
                  builder: (context, close) => InfoBar(
                    title: const Text('CSV content ready'),
                    content: const Text(
                      'Select and copy the content from the dialog',
                    ),
                    severity: InfoBarSeverity.success,
                    onClose: close,
                  ),
                );
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Export failed'),
          content: Text('$e'),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SINGLE ACTIONS
  // ─────────────────────────────────────────────────────────────────────────
  void _editQuote(Quote quote) async {
    // Get the associated load from cache
    final load = _loadCache[quote.loadId];

    if (load == null) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Unable to edit'),
          content: const Text('Could not find associated load for this quote'),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );
      return;
    }

    // Open the quote dialog for editing
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return LoadQuoteDialog(
          load: load,
          existingQuote: quote, // Pass existing quote for editing
          onPublish:
              ({
                required lineItems,
                required deliveryStartDate,
                required deliveryEndDate,
                required notes,
                required status,
                required poNumber,
                required loadReference,
                required expiresOn,
              }) async {
                // Check if meaningful load details changed
                if ((poNumber != null && poNumber != load.poNumber) ||
                    (loadReference != null &&
                        loadReference != load.loadReference)) {
                  // Update the load first
                  final updatedLoad = load.copyWith(
                    poNumber: poNumber,
                    loadReference: loadReference?.isNotEmpty == true
                        ? loadReference
                        : load.loadReference,
                  );
                  await ref
                      .read(loadControllerProvider.notifier)
                      .updateLoad(updatedLoad);
                }

                // Convert dialog line items to Quote model format
                final quoteLineItems = lineItems
                    .map(
                      (item) => QuoteLineItem(
                        type: item.type,
                        description: item.description,
                        rate: item.rate,
                        quantity: item.quantity,
                        unit: item.unit,
                      ),
                    )
                    .toList();

                final total = quoteLineItems.fold<double>(
                  0.0,
                  (sum, item) => sum + item.total,
                );

                // Create updated quote with same ID
                final updatedQuote = Quote(
                  id: quote.id,
                  loadId: quote.loadId,
                  loadReference: loadReference?.isNotEmpty == true
                      ? loadReference!
                      : quote.loadReference,
                  status: status,
                  lineItems: quoteLineItems,
                  total: total,
                  notes: notes,
                  expiresOn: expiresOn,
                );

                try {
                  await ref
                      .read(quoteControllerProvider.notifier)
                      .updateQuote(updatedQuote);

                  if (!mounted) return;
                  displayInfoBar(
                    context,
                    builder: (context, close) => InfoBar(
                      title: const Text('Quote Updated'),
                      content: Text(
                        'Quote for Load #${load.loadReference} updated successfully.',
                      ),
                      severity: InfoBarSeverity.success,
                      onClose: close,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  displayInfoBar(
                    context,
                    builder: (context, close) => InfoBar(
                      title: const Text('Error Updating Quote'),
                      content: Text('$e'),
                      severity: InfoBarSeverity.error,
                      onClose: close,
                    ),
                  );
                }
              },
        );
      },
    );
  }

  void _cloneQuote(Quote quote) async {
    await ref.read(quoteControllerProvider.notifier).cloneQuote(quote);
    if (mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Quote cloned successfully'),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    }
  }

  void _changeQuoteStatus(Quote quote, String status) async {
    await ref
        .read(quoteControllerProvider.notifier)
        .updateQuoteStatus(quote.id, status);
    if (mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: Text('Quote marked as ${status.toUpperCase()}'),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    }
  }

  Future<void> _deleteQuote(Quote quote, Load? load) async {
    final tripNumber = load?.tripNumber ?? quote.loadReference;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Delete Quote'),
        content: Text(
          'Are you sure you want to delete the quote for Trip #$tripNumber?',
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(AppColors.error),
            ),
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(quoteControllerProvider.notifier).deleteQuote(quote.id);
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Quote Deleted'),
            severity: InfoBarSeverity.success,
            onClose: close,
          ),
        );
      }
    }
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

// ─────────────────────────────────────────────────────────────────────────────
// QUOTE TABLE ROW WIDGET WITH CONTEXT MENU
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteTableRow extends StatefulWidget {
  const _QuoteTableRow({
    required this.quote,
    required this.load,
    required this.isSelected,
    required this.isFocused,
    required this.now,
    required this.theme,
    required this.dateFormat,
    required this.onToggleSelection,
    required this.onEdit,
    required this.onClone,
    required this.onChangeStatus,
    required this.onDelete,
    required this.getStatusColor,
  });

  final Quote quote;
  final Load? load;
  final bool isSelected;
  final bool isFocused;
  final DateTime now;
  final FluentThemeData theme;
  final DateFormat dateFormat;
  final void Function(bool) onToggleSelection;
  final VoidCallback onEdit;
  final VoidCallback onClone;
  final void Function(String) onChangeStatus;
  final VoidCallback onDelete;
  final Color Function(String) getStatusColor;

  @override
  State<_QuoteTableRow> createState() => _QuoteTableRowState();
}

class _QuoteTableRowState extends State<_QuoteTableRow> {
  final FlyoutController _flyoutController = FlyoutController();
  Offset _targetPosition = Offset.zero;

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  void _showContextMenu() {
    _flyoutController.showFlyout(
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      autoModeConfiguration: FlyoutAutoConfiguration(
        preferredMode: FlyoutPlacementMode.bottomRight,
      ),
      builder: (context) {
        return MenuFlyout(
          items: [
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.edit_24_regular, size: 16),
              text: const Text('Edit'),
              onPressed: () {
                Navigator.pop(context);
                widget.onEdit();
              },
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.copy_24_regular, size: 16),
              text: const Text('Clone'),
              onPressed: () {
                Navigator.pop(context);
                widget.onClone();
              },
            ),
            const MenuFlyoutSeparator(),
            if (widget.quote.status != 'won')
              MenuFlyoutItem(
                leading: Icon(
                  FluentIcons.checkmark_circle_24_regular,
                  size: 16,
                  color: AppColors.success,
                ),
                text: Text(
                  'Mark as Won',
                  style: TextStyle(color: AppColors.success),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onChangeStatus('won');
                },
              ),
            if (widget.quote.status == 'draft')
              MenuFlyoutItem(
                leading: Icon(
                  FluentIcons.send_24_regular,
                  size: 16,
                  color: AppColors.info,
                ),
                text: Text(
                  'Mark as Sent',
                  style: TextStyle(color: AppColors.info),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onChangeStatus('sent');
                },
              ),
            if (widget.quote.status != 'lost')
              MenuFlyoutItem(
                leading: Icon(
                  FluentIcons.dismiss_circle_24_regular,
                  size: 16,
                  color: AppColors.warning,
                ),
                text: Text(
                  'Mark as Lost',
                  style: TextStyle(color: AppColors.warning),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onChangeStatus('lost');
                },
              ),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              leading: Icon(
                FluentIcons.delete_24_regular,
                size: 16,
                color: AppColors.error,
              ),
              text: Text('Delete', style: TextStyle(color: AppColors.error)),
              onPressed: () {
                Navigator.pop(context);
                widget.onDelete();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpired =
        widget.quote.expiresOn != null &&
        widget.quote.expiresOn!.isBefore(widget.now) &&
        widget.quote.status != 'won';
    final isExpiringSoon =
        widget.quote.expiresOn != null &&
        !isExpired &&
        widget.quote.expiresOn!.difference(widget.now).inDays <= 3 &&
        widget.quote.status != 'won';

    return GestureDetector(
      onSecondaryTapUp: (details) {
        setState(() {
          _targetPosition = details.localPosition;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showContextMenu();
        });
      },
      child: Stack(
        children: [
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? widget.theme.accentColor.withValues(alpha: 0.05)
                  : null,
              border: widget.isFocused
                  ? Border.all(color: widget.theme.accentColor, width: 2)
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Checkbox
                SizedBox(
                  width: 40,
                  child: Checkbox(
                    checked: widget.isSelected,
                    onChanged: (v) => widget.onToggleSelection(v ?? false),
                  ),
                ),
                const SizedBox(width: 12),
                // Trip #
                Expanded(
                  flex: 1,
                  child: Text(
                    widget.load?.tripNumber ?? 'N/A',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                ),
                // Customer
                Expanded(
                  flex: 2,
                  child: Text(
                    widget.load?.brokerName ?? '—',
                    style: GoogleFonts.outfit(
                      color: widget.theme.resources.textFillColorSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Route
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.load != null
                              ? '${widget.load!.pickup.city}, ${widget.load!.pickup.state}'
                              : '—',
                          style: GoogleFonts.outfit(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.load != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            FluentIcons.arrow_right_24_regular,
                            size: 12,
                            color: widget.theme.resources.textFillColorTertiary,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '${widget.load!.delivery.city}, ${widget.load!.delivery.state}',
                            style: GoogleFonts.outfit(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Status
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget
                            .getStatusColor(widget.quote.status)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.quote.status.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: widget.getStatusColor(widget.quote.status),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                // Total
                Expanded(
                  flex: 2,
                  child: Text(
                    '\$${NumberFormat('#,##0.00').format(widget.quote.total)}',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: widget.theme.accentColor,
                    ),
                  ),
                ),
                // Expires
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      if (isExpired || isExpiringSoon)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            FluentIcons.warning_24_filled,
                            size: 14,
                            color: isExpired
                                ? AppColors.error
                                : AppColors.warning,
                          ),
                        ),
                      Text(
                        widget.quote.expiresOn != null
                            ? widget.dateFormat.format(widget.quote.expiresOn!)
                            : '—',
                        style: GoogleFonts.outfit(
                          color: isExpired
                              ? AppColors.error
                              : isExpiringSoon
                              ? AppColors.warning
                              : widget.theme.resources.textFillColorSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Created
                Expanded(
                  flex: 2,
                  child: Text(
                    widget.quote.createdAt != null
                        ? widget.dateFormat.format(widget.quote.createdAt!)
                        : '—',
                    style: GoogleFonts.outfit(
                      color: widget.theme.resources.textFillColorSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Hidden FlyoutTarget for positioning the context menu
          Positioned(
            left: _targetPosition.dx,
            top: _targetPosition.dy,
            child: FlyoutTarget(
              controller: _flyoutController,
              child: const SizedBox(height: 1, width: 1),
            ),
          ),
        ],
      ),
    );
  }
}
