import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/toast_notification.dart';

class TeamPanel extends StatefulWidget {
  const TeamPanel({super.key});

  @override
  State<TeamPanel> createState() => _TeamPanelState();
}

class _TeamPanelState extends State<TeamPanel> {
  bool _isLoading = false;
  bool _isAdmin = false;
  final TextEditingController _emailController = TextEditingController();

  int _selectedIndex = 0;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _drivers = [];

  // Realtime subscription
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _checkAdminAndLoad();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _checkAdminAndLoad() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();
      _isAdmin =
          (profile['role'] as String? ?? '').toLowerCase() == 'admin' ||
          (user.email?.contains('admin') ?? false);

      if (_isAdmin) {
        await _loadTeamMembers();
        _setupRealtime();
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadTeamMembers() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // 1. Get Admin's Company ID
    final adminProfile = await Supabase.instance.client
        .from('profiles')
        .select('company_id')
        .eq('id', user.id)
        .single();

    final companyId = adminProfile['company_id'] as String?;

    // STRICT FILTERING: Only show users if company_id is present.
    // If no company_id (e.g. new admin), show nothing or just themselves.
    // We do NOT default to showing all DB users anymore.
    if (companyId == null) {
      if (mounted) {
        setState(() {
          _users = [];
          _drivers = [];
        });
      }
      return;
    }

    try {
      // Fetch All Company Profiles
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('company_id', companyId)
          .order('created_at', ascending: false);

      final allProfiles = List<Map<String, dynamic>>.from(data);

      if (mounted) {
        setState(() {
          // Filter into Users (Staff) vs Drivers
          _drivers = allProfiles
              .where(
                (p) => (p['role'] as String? ?? '').toLowerCase() == 'driver',
              )
              .toList();
          _users = allProfiles
              .where(
                (p) => (p['role'] as String? ?? '').toLowerCase() != 'driver',
              )
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading team: $e');
    }
  }

  void _setupRealtime() {
    _subscription = Supabase.instance.client
        .channel('public:profiles')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            _loadTeamMembers(); // Reload on any change
          },
        )
        .subscribe();
  }

  Future<void> _approveUser(String email) async {
    if (email.isEmpty) return;

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, is_verified, full_name')
          .ilike('email', email)
          .maybeSingle();

      if (response == null) {
        if (mounted)
          showToast(
            context,
            title: 'Not Found',
            message: 'User not found.',
            type: ToastType.warning,
          );
        return;
      }

      if (response['is_verified'] == true) {
        if (mounted)
          showToast(context, title: 'Info', message: 'User already verified.');
        return;
      }

      final adminId = Supabase.instance.client.auth.currentUser!.id;
      final adminProfile = await Supabase.instance.client
          .from('profiles')
          .select('company_id, company_name')
          .eq('id', adminId)
          .single();

      await Supabase.instance.client
          .from('profiles')
          .update({
            'is_verified': true,
            'company_id': adminProfile['company_id'],
            'company_name': adminProfile['company_name'],
          })
          .eq('email', email);

      if (mounted) {
        showToast(
          context,
          title: 'Success',
          message: 'User approved.',
          type: ToastType.success,
        );
        _emailController.clear();
      }
    } catch (e) {
      if (mounted)
        showToast(
          context,
          title: 'Error',
          message: e.toString(),
          type: ToastType.error,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin && !_isLoading) {
      return const Center(child: Text('Access Denied'));
    }

    return ScaffoldPage(
      header: PageHeader(
        title: Text(
          'Users, Roles, Groups',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        commandBar: CommandBar(
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add_24_regular),
              label: const Text('Invite User'),
              onPressed: () {
                // TODO: Implement invitation logic
                showToast(
                  context,
                  title: 'Coming Soon',
                  message: 'Invite feature is coming soon.',
                );
              },
            ),
          ],
        ),
      ),
      content: TabView(
        currentIndex: _selectedIndex,
        onChanged: (i) => setState(() => _selectedIndex = i),
        closeButtonVisibility:
            CloseButtonVisibilityMode.never, // Hide close buttons
        tabs: [
          Tab(
            text: const Text('Users'),
            icon: const Icon(FluentIcons.person_24_regular),
            body: _buildList(_users, 'No users found'),
          ),
          Tab(
            text: const Text('Drivers'),
            icon: const Icon(FluentIcons.vehicle_truck_profile_24_regular),
            body: _buildList(_drivers, 'No drivers found'),
          ),
          Tab(
            text: const Text('Roles'),
            icon: const Icon(FluentIcons.shield_24_regular),
            body: const Center(child: Text('Role Management Coming Soon')),
          ),
          Tab(
            text: const Text('Groups'),
            icon: const Icon(FluentIcons.people_team_24_regular),
            body: const Center(child: Text('Group Management Coming Soon')),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, String emptyMessage) {
    if (_isLoading) return const Center(child: ProgressBar());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Approval Section (Only show on Users tab for simplicity, or make a dedicated tab)
        if (_selectedIndex == 0) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Row(
                children: [
                  Expanded(
                    child: TextBox(
                      controller: _emailController,
                      placeholder:
                          'Approve user by email (e.g. user@email.com)',
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => _approveUser(_emailController.text.trim()),
                    child: const Text('Approve'),
                  ),
                ],
              ),
            ),
          ),
        ],

        Expanded(
          child: items.isEmpty
              ? Center(child: Text(emptyMessage))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final member = items[index];
                    final name = member['full_name'] ?? 'Unknown User';
                    final email = member['email'] ?? '';
                    final role = member['role'] ?? 'User';
                    final avatar = member['avatar_url'];

                    return Card(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue, // Placeholder color
                              image: avatar != null
                                  ? DecorationImage(image: NetworkImage(avatar))
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: avatar == null
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  email,
                                  style: TextStyle(
                                    color: FluentTheme.of(
                                      context,
                                    ).resources.textFillColorSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              (role as String).toLowerCase(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // More Actions
                          IconButton(
                            icon: const Icon(
                              FluentIcons.more_vertical_24_regular,
                            ),
                            onPressed: () {
                              // Show context menu
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
