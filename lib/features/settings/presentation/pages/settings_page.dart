import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/services/auth_service.dart';
import 'package:milow/core/services/profile_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _fullName;
  String? _email;
  String? _avatarUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService.getProfile();
    setState(() {
      _fullName = profile?['full_name'] as String?;
      _email = profile?['email'] as String?;
      _avatarUrl = profile?['avatar_url'] as String?;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userName = _fullName ?? AuthService.getCurrentUserName() ?? 'User';
    final userEmail = _email ?? AuthService.getCurrentUserEmail() ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF9FAFB);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header with gradient background
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)]
                        : [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        'Profile',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Profile Avatar
                      _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.white,
                                    backgroundImage:
                                        _avatarUrl != null &&
                                            _avatarUrl!.isNotEmpty
                                        ? NetworkImage(_avatarUrl!)
                                        : null,
                                    child:
                                        _avatarUrl == null ||
                                            _avatarUrl!.isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            size: 50,
                                            color: Color(0xFF3B82F6),
                                          )
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () => context.push('/edit-profile'),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF3B82F6),
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.1,
                                            ),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        size: 18,
                                        color: Color(0xFF3B82F6),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      const SizedBox(height: 16),
                      Text(
                        userName,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userEmail,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -20),
                child: Container(
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      // Menu Items
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildMenuItem(
                              context,
                              Icons.person_outline,
                              'Edit Profile',
                              () => context.push('/edit-profile'),
                            ),
                            _buildDivider(),
                            _buildMenuItem(
                              context,
                              Icons.notifications_outlined,
                              'Notifications',
                              () => context.push('/notifications'),
                            ),
                            _buildDivider(),
                            _buildMenuItem(
                              context,
                              Icons.palette_outlined,
                              'Appearance',
                              () => context.push('/appearance'),
                            ),
                            _buildDivider(),
                            _buildMenuItem(
                              context,
                              Icons.language_outlined,
                              'Language',
                              () {},
                            ),
                            _buildDivider(),
                            _buildMenuItem(
                              context,
                              Icons.security_outlined,
                              'Privacy & Security',
                              () => context.push('/privacy-security'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Sign Out
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _buildMenuItem(
                          context,
                          Icons.logout,
                          'Sign out',
                          () async {
                            await AuthService.signOut();
                            if (context.mounted) {
                              context.go('/login');
                            }
                          },
                          isDestructive: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 3,
        selectedItemColor: const Color(0xFF007AFF),
        unselectedItemColor: const Color(0xFF98A2B3),
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mail_outline),
            label: 'Inbox',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          if (index == 0) context.go('/explore');
          if (index == 1) context.go('/dashboard');
          if (index == 2) context.go('/inbox');
          if (index == 3) context.go('/settings');
        },
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive
                    ? Colors.red.withValues(alpha: 0.1)
                    : const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isDestructive ? Colors.red : const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? Colors.red : textColor,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: const Color(0xFF98A2B3)),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFEAECF0),
      indent: 16,
      endIndent: 16,
    );
  }
}
