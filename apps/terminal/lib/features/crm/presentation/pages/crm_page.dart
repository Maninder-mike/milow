import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:terminal/features/crm/domain/models/crm_entity.dart';
import 'package:terminal/features/crm/presentation/providers/crm_providers.dart';

class CRMPage extends ConsumerStatefulWidget {
  const CRMPage({super.key});

  @override
  ConsumerState<CRMPage> createState() => _CRMPageState();
}

class _CRMPageState extends ConsumerState<CRMPage> {
  int _selectedSegment = 0;
  String _searchQuery = '';
  String? _stateFilter;
  String _sortColumn = 'name';
  bool _sortAscending = true;
  final Set<String> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final List<CRMEntityType> _segments = [
    CRMEntityType.broker,
    CRMEntityType.shipper,
    CRMEntityType.receiver,
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final resources = theme.resources;

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('CRM & Directory'),
        commandBar: _buildCommandBar(context, theme),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Statistics Bar
          _buildStatisticsBar(context, theme),
          const SizedBox(height: 16),

          // Segment Control + Search Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Segmented Control
                _buildSegmentedControl(theme),
                const Spacer(),
                // Search Box
                SizedBox(
                  width: 280,
                  child: TextBox(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    placeholder: 'Search by name, city, or state...',
                    onChanged: (v) => setState(() => _searchQuery = v),
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
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Data Table
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                padding: EdgeInsets.zero,
                backgroundColor: resources.cardBackgroundFillColorDefault,
                child: _buildDataTable(context, theme, resources),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCommandBar(BuildContext context, FluentThemeData theme) {
    return CommandBar(
      primaryItems: [
        CommandBarButton(
          icon: const Icon(FluentIcons.add_24_regular),
          label: const Text('Add New'),
          onPressed: () => _showAddEntityDialog(context),
        ),
        const CommandBarSeparator(),
        CommandBarButton(
          icon: const Icon(FluentIcons.arrow_export_24_regular),
          label: const Text('Export'),
          onPressed: _selectedIds.isEmpty ? null : () {},
        ),
        CommandBarButton(
          icon: const Icon(FluentIcons.arrow_sync_24_regular),
          label: const Text('Refresh'),
          onPressed: () => ref.invalidate(crmEntitiesProvider),
        ),
      ],
      secondaryItems: [
        CommandBarButton(
          icon: const Icon(FluentIcons.filter_24_regular),
          label: const Text('Filter by State'),
          onPressed: () => _showFilterFlyout(context),
        ),
        CommandBarButton(
          icon: const Icon(FluentIcons.delete_24_regular),
          label: const Text('Delete Selected'),
          onPressed: _selectedIds.isEmpty ? null : () {},
        ),
      ],
    );
  }

  Widget _buildStatisticsBar(BuildContext context, FluentThemeData theme) {
    final brokersAsync = ref.watch(crmEntitiesProvider(CRMEntityType.broker));
    final shippersAsync = ref.watch(crmEntitiesProvider(CRMEntityType.shipper));
    final receiversAsync = ref.watch(
      crmEntitiesProvider(CRMEntityType.receiver),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.cardStrokeColorDefault),
      ),
      child: Row(
        children: [
          _buildStatCard(
            context,
            theme,
            'Total Brokers',
            brokersAsync.when(
              data: (d) => d.length.toString(),
              loading: () => '...',
              error: (_, _) => '-',
            ),
            FluentIcons.people_24_regular,
            theme.accentColor,
          ),
          _buildDivider(theme),
          _buildStatCard(
            context,
            theme,
            'Total Shippers',
            shippersAsync.when(
              data: (d) => d.length.toString(),
              loading: () => '...',
              error: (_, _) => '-',
            ),
            FluentIcons.box_24_regular,
            Colors.teal,
          ),
          _buildDivider(theme),
          _buildStatCard(
            context,
            theme,
            'Total Receivers',
            receiversAsync.when(
              data: (d) => d.length.toString(),
              loading: () => '...',
              error: (_, _) => '-',
            ),
            FluentIcons.vehicle_truck_24_regular,
            Colors.orange,
          ),
          const Spacer(),
          _buildStatCard(
            context,
            theme,
            'Active This Month',
            '-', // Placeholder for future analytics
            FluentIcons.pulse_24_regular,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    FluentThemeData theme,
    String label,
    String value,
    IconData icon,
    AccentColor color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: theme.typography.subtitle?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDivider(FluentThemeData theme) {
    return Container(
      height: 40,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      color: theme.resources.dividerStrokeColorDefault,
    );
  }

  Widget _buildSegmentedControl(FluentThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_segments.length, (index) {
        final isSelected = _selectedSegment == index;
        final labels = ['Brokers', 'Shippers', 'Receivers'];
        final icons = [
          FluentIcons.people_24_regular,
          FluentIcons.box_24_regular,
          FluentIcons.vehicle_truck_24_regular,
        ];

        return Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
          child: ToggleButton(
            checked: isSelected,
            onChanged: (_) => setState(() {
              _selectedSegment = index;
              _selectedIds.clear();
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Icon(icons[index], size: 16),
                  const SizedBox(width: 8),
                  Text(labels[index]),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDataTable(
    BuildContext context,
    FluentThemeData theme,
    ResourceDictionary resources,
  ) {
    final entitiesAsync = ref.watch(
      crmEntitiesProvider(_segments[_selectedSegment]),
    );

    return entitiesAsync.when(
      data: (entities) {
        // Filter
        var filtered = entities.where((e) {
          final query = _searchQuery.toLowerCase();
          final matchesSearch =
              e.name.toLowerCase().contains(query) ||
              (e.city?.toLowerCase().contains(query) ?? false) ||
              (e.stateProvince?.toLowerCase().contains(query) ?? false);
          final matchesState =
              _stateFilter == null || e.stateProvince == _stateFilter;
          return matchesSearch && matchesState;
        }).toList();

        // Sort
        filtered.sort((a, b) {
          int result;
          switch (_sortColumn) {
            case 'name':
              result = a.name.compareTo(b.name);
            case 'city':
              result = (a.city ?? '').compareTo(b.city ?? '');
            case 'state':
              result = (a.stateProvince ?? '').compareTo(b.stateProvince ?? '');
            case 'email':
              result = (a.email ?? '').compareTo(b.email ?? '');
            default:
              result = 0;
          }
          return _sortAscending ? result : -result;
        });

        if (filtered.isEmpty) {
          return _buildEmptyState(context, theme);
        }

        return Column(
          children: [
            // Header Row
            _buildHeaderRow(theme, resources),
            const Divider(),
            // Data Rows
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final entity = filtered[index];
                  final isSelected = _selectedIds.contains(entity.id);
                  final isEven = index % 2 == 0;

                  return _buildDataRow(
                    context,
                    theme,
                    resources,
                    entity,
                    isSelected,
                    isEven,
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: ProgressRing()),
      error: (err, stack) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.error_circle_24_regular,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text('Error loading data: $err'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(
                crmEntitiesProvider(_segments[_selectedSegment]),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(FluentThemeData theme, ResourceDictionary resources) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: resources.subtleFillColorSecondary,
      child: Row(
        children: [
          // Checkbox
          SizedBox(
            width: 40,
            child: Checkbox(
              checked: _selectedIds.isNotEmpty,
              onChanged: (val) {
                // Select all / deselect all (placeholder)
              },
            ),
          ),
          // Name
          _buildSortableHeader(theme, 'Name', 'name', flex: 3),
          // City
          _buildSortableHeader(theme, 'City', 'city', flex: 2),
          // State
          _buildSortableHeader(theme, 'State', 'state', flex: 1),
          // Email
          _buildSortableHeader(theme, 'Email', 'email', flex: 2),
          // Phone
          Expanded(
            flex: 2,
            child: Text('Phone', style: theme.typography.bodyStrong),
          ),
          // Actions
          const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildSortableHeader(
    FluentThemeData theme,
    String label,
    String column, {
    int flex = 1,
  }) {
    final isActive = _sortColumn == column;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_sortColumn == column) {
              _sortAscending = !_sortAscending;
            } else {
              _sortColumn = column;
              _sortAscending = true;
            }
          });
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Row(
            children: [
              Text(
                label,
                style: theme.typography.bodyStrong?.copyWith(
                  color: isActive ? theme.accentColor : null,
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
                    color: theme.accentColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(
    BuildContext context,
    FluentThemeData theme,
    ResourceDictionary resources,
    CRMEntity entity,
    bool isSelected,
    bool isEven,
  ) {
    return HoverButton(
      onPressed: () => context.push('/crm/${entity.type.name}/${entity.id}'),
      builder: (context, states) {
        final isHovered = states.isHovered;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.accentColor.withValues(alpha: 0.1)
                : isHovered
                ? resources.subtleFillColorSecondary
                : isEven
                ? resources.cardBackgroundFillColorDefault
                : resources.cardBackgroundFillColorSecondary,
            border: Border(
              bottom: BorderSide(
                color: resources.dividerStrokeColorDefault,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // Checkbox
              SizedBox(
                width: 40,
                child: Checkbox(
                  checked: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedIds.add(entity.id);
                      } else {
                        _selectedIds.remove(entity.id);
                      }
                    });
                  },
                ),
              ),
              // Name
              Expanded(
                flex: 3,
                child: Text(
                  entity.name,
                  style: theme.typography.body?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // City
              Expanded(
                flex: 2,
                child: Text(
                  entity.city ?? '-',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // State
              Expanded(flex: 1, child: Text(entity.stateProvince ?? '-')),
              // Email
              Expanded(
                flex: 2,
                child: Text(
                  entity.email ?? '-',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: entity.email != null
                        ? theme.accentColor
                        : theme.resources.textFillColorSecondary,
                  ),
                ),
              ),
              // Phone
              Expanded(flex: 2, child: Text(entity.phone ?? '-')),
              // Actions
              SizedBox(
                width: 80,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        FluentIcons.edit_24_regular,
                        size: 16,
                        color: isHovered ? theme.accentColor : null,
                      ),
                      onPressed: () =>
                          context.push('/crm/${entity.type.name}/${entity.id}'),
                    ),
                    IconButton(
                      icon: const Icon(
                        FluentIcons.more_vertical_24_regular,
                        size: 16,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, FluentThemeData theme) {
    final labels = ['brokers', 'shippers', 'receivers'];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.folder_open_24_regular,
            size: 64,
            color: theme.resources.textFillColorSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No ${labels[_selectedSegment]} found',
            style: theme.typography.subtitle,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search or filters'
                : 'Get started by adding your first ${labels[_selectedSegment].substring(0, labels[_selectedSegment].length - 1)}',
            style: theme.typography.body?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => _showAddEntityDialog(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FluentIcons.add_24_regular, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Add ${labels[_selectedSegment].substring(0, labels[_selectedSegment].length - 1).toUpperCase()}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEntityDialog(BuildContext context) {
    // Navigate to new entity form based on selected segment
    final types = ['broker', 'shipper', 'receiver'];
    context.push('/crm/${types[_selectedSegment]}/new');
  }

  void _showFilterFlyout(BuildContext context) {
    // Placeholder for filter flyout
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Filter by State'),
        content: const Text('State filter options would go here.'),
        actions: [
          Button(
            child: const Text('Clear'),
            onPressed: () {
              setState(() => _stateFilter = null);
              Navigator.pop(context);
            },
          ),
          FilledButton(
            child: const Text('Apply'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
