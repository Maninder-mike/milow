import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';

import '../../core/widgets/toast_notification.dart';
import '../../core/widgets/choreographed_entrance.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _countryController = TextEditingController();

  // Read-only fields
  String _email = '';
  String _role = '';
  String? _avatarUrl;
  DateTime? _createdAt;

  XFile? _profileImage;
  bool _isLoading = false;
  bool _isEditing = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      if (mounted) {
        setState(() {
          _email = user.email ?? '';
          _createdAt = DateTime.parse(user.createdAt);
          _isLoading = true;
        });
      }

      try {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('*, company_staff_profiles(*)')
            .eq('id', user.id)
            .maybeSingle();

        if (data != null && mounted) {
          final details =
              data['company_staff_profiles'] as Map<String, dynamic>?;

          setState(() {
            _nameController.text = data['full_name'] as String? ?? '';
            _avatarUrl = data['avatar_url'] as String?;
            _role = (data['role'] as String?) ?? 'User';

            // Load details
            _phoneController.text =
                (details?['work_phone'] ?? data['phone']) as String? ?? '';
            _streetController.text =
                (details?['address'] ?? data['street']) as String? ?? '';
            _cityController.text =
                (details?['city'] ?? data['city']) as String? ?? '';
            _stateController.text =
                (details?['state_province'] ?? data['state_province'])
                    as String? ??
                '';
            _zipController.text =
                (details?['postal_code'] ?? data['postal_code']) as String? ??
                '';
            _countryController.text =
                (details?['country'] ?? data['country']) as String? ?? '';
          });
        }
      } catch (e) {
        debugPrint('Error loading profile: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'images',
      extensions: <String>['jpg', 'png', 'jpeg'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[typeGroup],
    );
    if (file != null && mounted) {
      setState(() => _profileImage = file);
      // Auto-upload on pick could be nice, or wait for save. Let's wait for save.
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      String? avatarUrl = _avatarUrl;
      // 1. Upload new avatar if selected
      if (_profileImage != null) {
        final bytes = await _profileImage!.readAsBytes();
        final fileExt = _profileImage!.path.split('.').last;
        final fileName =
            '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await Supabase.instance.client.storage
            .from('avatars')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );

        avatarUrl = Supabase.instance.client.storage
            .from('avatars')
            .getPublicUrl(fileName);
      }

      // 2. Update Profiles (Base)
      await Supabase.instance.client
          .from('profiles')
          .update({
            'full_name': _nameController.text,
            'updated_at': DateTime.now().toIso8601String(),
            if (avatarUrl != null) 'avatar_url': avatarUrl,
          })
          .eq('id', user.id);

      // 3. Update Staff Details
      await Supabase.instance.client.from('company_staff_profiles').upsert({
        'id': user.id,
        'address': _streetController.text,
        'city': _cityController.text,
        'state_province': _stateController.text,
        'postal_code': _zipController.text,
        'country': _countryController.text,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 4. Update Auth Metadata
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'full_name': _nameController.text}),
      );

      if (mounted) {
        showToast(
          context,
          title: 'Success',
          message: 'Profile updated successfully.',
          type: ToastType.success,
        );
        setState(() {
          _isEditing = false;
          _profileImage = null; // Clear picked image
          _avatarUrl = avatarUrl;
        });
      }
    } catch (e) {
      if (mounted) {
        showToast(
          context,
          title: 'Error',
          message: 'Failed to update: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return ScaffoldPage(
      header: PageHeader(
        title: Text(
          'My Profile',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        commandBar: _isEditing
            ? CommandBar(
                primaryItems: [
                  CommandBarButton(
                    icon: const Icon(FluentIcons.dismiss_24_regular),
                    label: const Text('Cancel'),
                    onPressed: () => setState(() => _isEditing = false),
                  ),
                  CommandBarButton(
                    icon: _isLoading
                        ? const ProgressRing(strokeWidth: 2)
                        : const Icon(FluentIcons.save_24_regular),
                    label: const Text('Save Changes'),
                    onPressed: _isLoading ? null : _updateProfile,
                  ),
                ],
              )
            : CommandBar(
                primaryItems: [
                  CommandBarButton(
                    icon: const Icon(FluentIcons.edit_24_regular),
                    label: const Text('Edit Profile'),
                    onPressed: () => setState(() => _isEditing = true),
                  ),
                ],
              ),
      ),
      content: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          return ChoreographedEntrance(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Identity Sidebar (Fixed Width)
                if (isWide) ...[
                  SizedBox(
                    width: 320,
                    child: _buildIdentityCard(context, isLight),
                  ),
                  const SizedBox(width: 24),
                ],

                // 2. Main content (Flexible)
                Expanded(
                  child: isWide
                      ? _buildTabs(context)
                      : SingleChildScrollView(
                          padding: const EdgeInsets.only(right: 24, bottom: 24),
                          child: Column(
                            children: [
                              _buildIdentityCard(context, isLight),
                              const SizedBox(height: 24),
                              SizedBox(height: 500, child: _buildTabs(context)),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIdentityCard(BuildContext context, bool isLight) {
    return Card(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[40],
                  image: _profileImage != null
                      ? DecorationImage(
                          image: FileImage(File(_profileImage!.path)),
                          fit: BoxFit.cover,
                        )
                      : _avatarUrl != null
                      ? DecorationImage(
                          image: NetworkImage(_avatarUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _profileImage == null && _avatarUrl == null
                    ? Center(
                        child: Text(
                          _nameController.text.isNotEmpty
                              ? _nameController.text[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 40),
                        ),
                      )
                    : null,
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: FluentTheme.of(context).accentColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        FluentIcons.camera_24_regular,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    onPressed: _pickImage,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _nameController.text,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: FluentTheme.of(context).accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: FluentTheme.of(
                  context,
                ).accentColor.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              _role.toUpperCase(),
              style: TextStyle(
                color: FluentTheme.of(context).accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          _buildStatRow(FluentIcons.mail_24_regular, _email),
          if (_createdAt != null) ...[
            const SizedBox(height: 12),
            _buildStatRow(
              FluentIcons.calendar_ltr_24_regular,
              'Joined ${_createdAt!.year}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[100]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[120], fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(BuildContext context) {
    return TabView(
      currentIndex: _selectedTab,
      onChanged: (index) => setState(() => _selectedTab = index),
      tabs: [
        Tab(
          text: const Text('Overview'),
          icon: const Icon(FluentIcons.person_24_regular),
          body: _buildOverviewTab(),
        ),
        Tab(
          text: const Text('Security'),
          icon: const Icon(FluentIcons.lock_shield_24_regular),
          body: _buildSecurityTab(),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Information',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),

            InfoLabel(
              label: 'Full Name',
              child: TextFormBox(
                controller: _nameController,
                readOnly: !_isEditing,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(height: 16),

            InfoLabel(
              label: 'Phone Number',
              child: TextFormBox(
                controller: _phoneController,
                readOnly: !_isEditing,
                placeholder: '+1 (000) 000-0000',
              ),
            ),
            const SizedBox(height: 32),

            Text(
              'Address',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),

            InfoLabel(
              label: 'Street Address',
              child: TextFormBox(
                controller: _streetController,
                readOnly: !_isEditing,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: InfoLabel(
                    label: 'City',
                    child: TextFormBox(
                      controller: _cityController,
                      readOnly: !_isEditing,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InfoLabel(
                    label: 'State',
                    child: TextFormBox(
                      controller: _stateController,
                      readOnly: !_isEditing,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InfoLabel(
                    label: 'Zip',
                    child: TextFormBox(
                      controller: _zipController,
                      readOnly: !_isEditing,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Country',
              child: TextFormBox(
                controller: _countryController,
                readOnly: !_isEditing,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityTab() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            FluentIcons.lock_closed_24_regular,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'Password & Security',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'To change your password, please use the logout button and select "Forgot Password".',
          ),
          const SizedBox(height: 24),
          Button(
            child: const Text('Sign out to Reset Password'),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                // Navigation handled by auth wrapper usually, or:
                Navigator.of(context).pushReplacementNamed('/');
              }
            },
          ),
        ],
      ),
    );
  }
}
