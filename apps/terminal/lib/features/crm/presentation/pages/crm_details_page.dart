import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:terminal/features/crm/domain/models/crm_entity.dart';
import 'package:terminal/features/crm/presentation/providers/crm_providers.dart';

class CRMDetailsPage extends ConsumerStatefulWidget {
  final String entityId;
  final String typeString;

  const CRMDetailsPage({
    super.key,
    required this.entityId,
    required this.typeString,
  });

  @override
  ConsumerState<CRMDetailsPage> createState() => _CRMDetailsPageState();
}

class _CRMDetailsPageState extends ConsumerState<CRMDetailsPage> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final type = CRMEntityType.values.byName(widget.typeString);
    final entityAsync = ref.watch(
      crmEntityDetailsProvider(id: widget.entityId, type: type),
    );

    return entityAsync.when(
      data: (entity) => ScaffoldPage(
        header: PageHeader(
          title: Text(entity.name),
          leading: IconButton(
            icon: const Icon(FluentIcons.arrow_left_24_regular),
            onPressed: () => context.pop(),
          ),
        ),
        content: TabView(
          currentIndex: _selectedTab,
          onChanged: (i) => setState(() => _selectedTab = i),
          closeButtonVisibility: CloseButtonVisibilityMode.never,
          tabs: [
            Tab(text: const Text('Overview'), body: _buildOverviewTab(entity)),
            Tab(
              text: const Text('Contacts'),
              body: _buildContactsTab(entity.id),
            ),
            Tab(
              text: const Text('Load History'),
              body: _buildHistoryTab(entity.id),
            ),
          ],
        ),
      ),
      loading: () => const Center(child: ProgressBar()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildOverviewTab(CRMEntity entity) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('Address', entity.address ?? 'N/A'),
          _infoRow(
            'City/State',
            '${entity.city ?? ""}, ${entity.stateProvince ?? ""} ${entity.postalCode ?? ""}',
          ),
          _infoRow('Phone', entity.phone ?? 'N/A'),
          _infoRow('Email', entity.email ?? 'N/A'),
          _infoRow('Payment Terms', entity.paymentTerms ?? 'N/A'),
          const SizedBox(height: 20),
          const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(entity.notes ?? 'No notes available.'),
        ],
      ),
    );
  }

  Widget _buildContactsTab(String entityId) {
    final contactsAsync = ref.watch(crmEntityContactsProvider(entityId));

    return contactsAsync.when(
      data: (contacts) {
        if (contacts.isEmpty) {
          return const Center(child: Text('No contacts found.'));
        }
        return ListView.builder(
          itemCount: contacts.length,
          itemBuilder: (context, index) {
            final contact = contacts[index];
            return ListTile(
              title: Text(contact.name),
              subtitle: Text(contact.role ?? 'General'),
              trailing: Text(contact.phone ?? contact.email ?? ''),
            );
          },
        );
      },
      loading: () => const Center(child: ProgressBar()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildHistoryTab(String entityId) {
    // Placeholder until repository has fetchHistory
    return const Center(child: Text('Load history integration coming soon.'));
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
