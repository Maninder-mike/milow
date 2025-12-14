import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow_core/milow_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../users/data/user_repository_provider.dart';

class DriversPage extends ConsumerWidget {
  const DriversPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);

    return ScaffoldPage(
      header: PageHeader(
        title: Text(
          'Drivers',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Button(
              onPressed: () => ref.invalidate(usersProvider),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.refresh),
                  SizedBox(width: 8),
                  Text('Refresh'),
                ],
              ),
            ),
          ],
        ),
      ),
      content: usersAsync.when(
        data: (users) {
          final drivers = users
              .where((u) => u.role == UserRole.driver)
              .toList();

          if (drivers.isEmpty) {
            return const Center(child: Text('No drivers found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Card(
                  child: ListTile(
                    leading: const Icon(FluentIcons.contact_card),
                    title: Text(driver.fullName),
                    subtitle: Text(driver.email ?? '-'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        'Driver',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: ProgressRing()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading drivers: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(usersProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
