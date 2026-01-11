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
  int _selectedTab = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<CRMEntityType> _tabs = [
    CRMEntityType.broker,
    CRMEntityType.shipper,
    CRMEntityType.receiver,
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('CRM & Directory'),
        commandBar: SizedBox(
          width: 300,
          child: TextBox(
            controller: _searchController,
            placeholder: 'Search name, city, or state...',
            onChanged: (v) => setState(() => _searchQuery = v),
            prefix: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(FluentIcons.search_24_regular, size: 16),
            ),
          ),
        ),
      ),
      content: TabView(
        currentIndex: _selectedTab,
        onChanged: (i) => setState(() => _selectedTab = i),
        closeButtonVisibility: CloseButtonVisibilityMode.never,
        tabs: [
          Tab(
            text: const Text('Brokers'),
            icon: const Icon(FluentIcons.people_24_regular),
            body: _buildEntityList(_tabs[0]),
          ),
          Tab(
            text: const Text('Shippers'),
            icon: const Icon(FluentIcons.box_24_regular),
            body: _buildEntityList(_tabs[1]),
          ),
          Tab(
            text: const Text('Receivers'),
            icon: const Icon(FluentIcons.vehicle_truck_24_regular),
            body: _buildEntityList(_tabs[2]),
          ),
        ],
      ),
    );
  }

  Widget _buildEntityList(CRMEntityType type) {
    final entitiesAsync = ref.watch(crmEntitiesProvider(type));

    return entitiesAsync.when(
      data: (entities) {
        final filteredEntities = entities.where((e) {
          final query = _searchQuery.toLowerCase();
          return e.name.toLowerCase().contains(query) ||
              (e.city?.toLowerCase().contains(query) ?? false) ||
              (e.stateProvince?.toLowerCase().contains(query) ?? false);
        }).toList();

        if (filteredEntities.isEmpty) {
          return const Center(child: Text('No results found.'));
        }

        return ListView.builder(
          itemCount: filteredEntities.length,
          itemBuilder: (context, index) {
            final entity = filteredEntities[index];
            return ListTile(
              title: Text(
                entity.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${entity.city ?? ""}, ${entity.stateProvince ?? ""}',
              ),
              trailing: const Icon(
                FluentIcons.chevron_right_24_regular,
                size: 16,
              ),
              onPressed: () {
                context.push('/crm/${entity.type.name}/${entity.id}');
              },
            );
          },
        );
      },
      loading: () => const Center(child: ProgressBar()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}
