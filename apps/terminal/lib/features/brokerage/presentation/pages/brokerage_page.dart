import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:terminal/features/brokerage/presentation/providers/brokerage_providers.dart';
import 'package:terminal/features/brokerage/domain/models/manifest.dart';
import 'package:terminal/features/brokerage/domain/models/partner.dart';
import '../../../../core/widgets/ui_hardening.dart';

class BrokeragePage extends ConsumerStatefulWidget {
  const BrokeragePage({super.key});

  @override
  ConsumerState<BrokeragePage> createState() => _BrokeragePageState();
}

class _BrokeragePageState extends ConsumerState<BrokeragePage> {
  int _selectedSegment = 0;
  String _searchQuery = '';
  final Set<String> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

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
        title: const Text('Brokerage Dashboard'),
        commandBar: _buildCommandBar(context),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Statistics
          _buildStatisticsBar(context, theme),
          const SizedBox(height: 16),

          // Segment Control + Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildSegmentedControl(theme),
                const Spacer(),
                SizedBox(
                  width: 280,
                  child: TextBox(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    placeholder: 'Search...',
                    onChanged: (v) => setState(() => _searchQuery = v),
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(FluentIcons.search_24_regular, size: 16),
                    ),
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
                child: _selectedSegment == 0
                    ? _buildManifestsTable(context, theme, resources)
                    : _buildPartnersTable(context, theme, resources),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCommandBar(BuildContext context) {
    return CommandBar(
      primaryItems: [
        CommandBarButton(
          icon: const Icon(FluentIcons.add_24_regular),
          label: Text(_selectedSegment == 0 ? 'New Manifest' : 'New Partner'),
          onPressed: () {
            // Placeholder: Open dialog or navigate to form
          },
        ),
        const CommandBarSeparator(),
        CommandBarButton(
          icon: const Icon(FluentIcons.arrow_sync_24_regular),
          label: const Text('Refresh'),
          onPressed: () {
            if (_selectedSegment == 0) {
              ref.invalidate(brokerageManifestsProvider);
            } else {
              ref.invalidate(brokeragePartnersProvider);
            }
          },
        ),
      ],
      secondaryItems: [
        CommandBarButton(
          icon: const Icon(FluentIcons.delete_24_regular),
          label: const Text('Delete Selected'),
          onPressed: _selectedIds.isEmpty ? null : () {},
        ),
      ],
    );
  }

  Widget _buildStatisticsBar(BuildContext context, FluentThemeData theme) {
    final manifestsAsync = ref.watch(brokerageManifestsProvider);
    final partnersAsync = ref.watch(brokeragePartnersProvider);

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
            'Total Manifests',
            manifestsAsync.when(
              data: (d) => d.length.toString(),
              loading: () => '...',
              error: (_, _) => '-',
            ),
            FluentIcons.document_text_24_regular,
            theme.accentColor,
          ),
          _buildDivider(theme),
          _buildStatCard(
            context,
            theme,
            'Active Partners',
            partnersAsync.when(
              data: (d) => d.where((p) => p.status == PartnerStatus.active).length.toString(),
              loading: () => '...',
              error: (_, _) => '-',
            ),
            FluentIcons.building_24_regular,
            Colors.teal,
          ),
          _buildDivider(theme),
          _buildStatCard(
            context,
            theme,
            'In Transit',
            manifestsAsync.when(
              data: (d) => d.where((m) => m.status == ManifestStatus.inTransit).length.toString(),
              loading: () => '...',
              error: (_, _) => '-',
            ),
            FluentIcons.vehicle_truck_24_regular,
            Colors.orange,
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
            Text(value, style: theme.typography.subtitle?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: theme.typography.caption?.copyWith(color: theme.resources.textFillColorSecondary)),
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
      children: [
        ToggleButton(
          checked: _selectedSegment == 0,
          onChanged: (_) => setState(() { _selectedSegment = 0; _selectedIds.clear(); }),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [Icon(FluentIcons.document_text_24_regular, size: 16), SizedBox(width: 8), Text('Manifests')],
            ),
          ),
        ),
        const SizedBox(width: 4),
        ToggleButton(
          checked: _selectedSegment == 1,
          onChanged: (_) => setState(() { _selectedSegment = 1; _selectedIds.clear(); }),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [Icon(FluentIcons.building_24_regular, size: 16), SizedBox(width: 8), Text('Partners')],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManifestsTable(BuildContext context, FluentThemeData theme, ResourceDictionary resources) {
    final asyncData = ref.watch(brokerageManifestsProvider);
    return asyncData.when(
      data: (manifests) {
        final filtered = manifests.where((m) => m.manifestNumber.toString().contains(_searchQuery)).toList();
        if (filtered.isEmpty) return _buildEmptyState(theme, 'manifests');
        return Column(
          children: [
            _buildManifestHeaderRow(theme, resources),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final m = filtered[index];
                  final isEven = index % 2 == 0;
                  return _buildManifestRow(theme, resources, m, isEven);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const TableSkeleton(
        columnFlex: [2, 3, 2, 2],
        showCheckbox: false,
      ),
      error: (e, st) => StandardErrorState(
        message: 'Could not load manifests: $e',
        onRetry: () => ref.invalidate(brokerageManifestsProvider),
      ),
    );
  }

  Widget _buildManifestHeaderRow(FluentThemeData theme, ResourceDictionary resources) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: resources.subtleFillColorSecondary,
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('Manifest #', style: theme.typography.bodyStrong)),
          Expanded(flex: 3, child: Text('Partner ID', style: theme.typography.bodyStrong)),
          Expanded(flex: 2, child: Text('Status', style: theme.typography.bodyStrong)),
          Expanded(flex: 2, child: Text('Cost', style: theme.typography.bodyStrong)),
          const SizedBox(width: 80), // Actions
        ],
      ),
    );
  }

  Widget _buildManifestRow(FluentThemeData theme, ResourceDictionary resources, Manifest manifest, bool isEven) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isEven ? resources.cardBackgroundFillColorDefault : resources.cardBackgroundFillColorSecondary,
        border: Border(bottom: BorderSide(color: resources.dividerStrokeColorDefault, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(manifest.manifestNumber.toString())),
          Expanded(flex: 3, child: Text(manifest.partnerId)),
          Expanded(flex: 2, child: Text(manifest.status.label)),
          Expanded(flex: 2, child: Text('${manifest.agreedCost} ${manifest.currency}')),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(icon: const Icon(FluentIcons.edit_16_regular), onPressed: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnersTable(BuildContext context, FluentThemeData theme, ResourceDictionary resources) {
    final asyncData = ref.watch(brokeragePartnersProvider);
    return asyncData.when(
      data: (partners) {
        final filtered = partners.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
        if (filtered.isEmpty) return _buildEmptyState(theme, 'partners');
        return Column(
          children: [
            _buildPartnerHeaderRow(theme, resources),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final p = filtered[index];
                  final isEven = index % 2 == 0;
                  return _buildPartnerRow(theme, resources, p, isEven);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const TableSkeleton(
        columnFlex: [3, 2, 2, 2],
        showCheckbox: false,
      ),
      error: (e, st) => StandardErrorState(
        message: 'Could not load partners: $e',
        onRetry: () => ref.invalidate(brokeragePartnersProvider),
      ),
    );
  }

  Widget _buildPartnerHeaderRow(FluentThemeData theme, ResourceDictionary resources) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: resources.subtleFillColorSecondary,
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Partner Name', style: theme.typography.bodyStrong)),
          Expanded(flex: 2, child: Text('MC/DOT', style: theme.typography.bodyStrong)),
          Expanded(flex: 2, child: Text('Status', style: theme.typography.bodyStrong)),
          Expanded(flex: 2, child: Text('Safety Rating', style: theme.typography.bodyStrong)),
          const SizedBox(width: 80), // Actions
        ],
      ),
    );
  }

  Widget _buildPartnerRow(FluentThemeData theme, ResourceDictionary resources, Partner partner, bool isEven) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isEven ? resources.cardBackgroundFillColorDefault : resources.cardBackgroundFillColorSecondary,
        border: Border(bottom: BorderSide(color: resources.dividerStrokeColorDefault, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(partner.name)),
          Expanded(flex: 2, child: Text('${partner.mcNumber ?? '-'} / ${partner.dotNumber ?? '-'}')),
          Expanded(flex: 2, child: Text(partner.status.label)),
          Expanded(flex: 2, child: Text(partner.safetyRating?.label ?? '-')),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(icon: const Icon(FluentIcons.edit_16_regular), onPressed: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(FluentThemeData theme, String type) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.search_24_regular,
            size: 48,
            color: theme.resources.textFillColorSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No $type found',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search criteria.',
            style: TextStyle(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
          const SizedBox(height: 24),
          if (_searchQuery.isNotEmpty)
            Button(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Text('Clear Search'),
            ),
        ],
      ),
    );
  }
}
