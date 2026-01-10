
// =============================================================================
// DRIVERS TAB
// =============================================================================

class _DriversTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchDrivers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: ProgressRing());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading drivers: ${snapshot.error}'));
        }

        final drivers = snapshot.data ?? [];

        if (drivers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FluentIcons.vehicle_truck_profile_24_regular,
                  size: 48,
                  color: theme.resources.textFillColorSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No drivers found',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Invite drivers to join your fleet.',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: theme.resources.textFillColorTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: drivers.length,
          itemBuilder: (context, index) {
            final driver = drivers[index];
            return _UserListItem(user: driver);
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchDrivers() async {
    final supabase = Supabase.instance.client;
    final currentUserProfile = await supabase
        .from('profiles')
        .select('company_id')
        .eq('id', supabase.auth.currentUser!.id)
        .single();

    final companyId = currentUserProfile['company_id'] as String?;
    if (companyId == null) return [];

    final response = await supabase
        .from('profiles')
        .select('''
          id,
          email,
          full_name,
          role,
          role_id,
          is_verified,
          avatar_url,
          created_at,
          roles(name)
        ''')
        .eq('company_id', companyId)
        .eq('role', 'driver')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response as List);
  }
}
