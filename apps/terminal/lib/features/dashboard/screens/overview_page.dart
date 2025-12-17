import 'package:fluent_ui/fluent_ui.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: Text(
          'Dashboard Overview',
          style: FluentTheme.of(context).typography.title,
        ),
      ),
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            _buildStatCard(
              context,
              title: 'Total Users',
              value: '1,234',
              icon: FluentIcons.people,
              color: Colors.blue,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              context,
              title: 'Active Trips',
              value: '42',
              icon: FluentIcons.delivery_truck,
              color: Colors.green,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              context,
              title: 'Revenue',
              value: '\$12,345',
              icon: FluentIcons.money,
              color: Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          'Recent Activity',
          style: FluentTheme.of(context).typography.subtitle,
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(FluentIcons.add_friend),
                title: const Text('New user registered'),
                subtitle: const Text('Maninder Singh joined 2 hours ago'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(FluentIcons.bus),
                title: const Text('Fuel entry added'),
                subtitle: const Text('Truck #101 added 50L'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(FluentIcons.completed),
                title: const Text('Trip completed'),
                subtitle: const Text('Trip #2938 marked as done'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 16),
            Text(
              value,
              style: FluentTheme.of(
                context,
              ).typography.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey, // Fluent Colors.grey is fine
              ),
            ),
          ],
        ),
      ),
    );
  }
}
