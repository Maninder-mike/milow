import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import 'package:intl/intl.dart';

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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Identity Sidebar (Fixed Width)
                  if (isWide) ...[
                    SizedBox(
                      width: 320,
                      child: _buildIdentityCard(context, isLight),
                    ),
                    const SizedBox(width: 32),
                  ],

                  // 2. Main content (Flexible)
                  Expanded(
                    child: isWide
                        ? _buildMainContent()
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildIdentityCard(context, isLight),
                                const SizedBox(height: 32),
                                _buildMainContent(),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIdentityCard(BuildContext context, bool isLight) {
    final theme = FluentTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.resources.dividerStrokeColorDefault,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.04 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar with Refined Border
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.resources.controlFillColorDefault,
                  border: Border.all(
                    color: theme.accentColor.withValues(alpha: 0.2),
                    width: 4,
                  ),
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
                          style: GoogleFonts.outfit(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: theme.accentColor,
                          ),
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
                        color: theme.accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
          const SizedBox(height: 24),
          Text(
            _nameController.text,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.resources.textFillColorPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.accentColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              _role.toUpperCase(),
              style: GoogleFonts.outfit(
                color: theme.accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Divider(), // Changed from const Divider()
          const SizedBox(height: 24),
          _buildStatRow(context, FluentIcons.mail_24_regular, _email),
          const SizedBox(height: 16),
          if (_createdAt != null)
            _buildStatRow(
              context,
              FluentIcons.calendar_ltr_24_regular,
              'Joined ${DateFormat('MMMM y').format(_createdAt!)}',
            ),
        ],
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, IconData icon, String text) {
    final theme = FluentTheme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.resources.textFillColorSecondary.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              color: theme.resources.textFillColorSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    final theme = FluentTheme.of(context);
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, 'Contact Information'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildInfoField(
                    label: 'Full Name',
                    controller: _nameController,
                    placeholder: 'Enter your full name',
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildInfoField(
                    label: 'Phone Number',
                    controller: _phoneController,
                    placeholder: '+1 (000) 000-0000',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            _buildSectionHeader(context, 'Local Address'),
            const SizedBox(height: 24),
            _buildInfoField(
              label: 'Street Address',
              controller: _streetController,
              placeholder: '123 Main St',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildInfoField(
                    label: 'City',
                    controller: _cityController,
                    placeholder: 'City',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoField(
                    label: 'State / Province',
                    controller: _stateController,
                    placeholder: 'State',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoField(
                    label: 'Zip / Postal Code',
                    controller: _zipController,
                    placeholder: 'Zip',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoField(
              label: 'Country',
              controller: _countryController,
              placeholder: 'Country',
            ),
            const SizedBox(height: 48),
            _buildSectionHeader(context, 'Security'),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.resources.cardBackgroundFillColorDefault,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.resources.dividerStrokeColorDefault,
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(FluentIcons.shield_24_regular, size: 32),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Password & Authentication',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage your password and sign-in methods.',
                          style: GoogleFonts.outfit(
                            color: theme.resources.textFillColorSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Button(
                    child: Text(
                      'Reset Password',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (mounted) {
                        Navigator.of(context).pushReplacementNamed('/');
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.resources.textFillColorPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            color: theme.accentColor.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoField({
    required String label,
    required TextEditingController controller,
    String? placeholder,
    String? Function(String?)? validator,
  }) {
    final theme = FluentTheme.of(context);
    return InfoLabel(
      label: label,
      labelStyle: GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: theme.resources.textFillColorSecondary,
      ),
      child: TextFormBox(
        controller: controller,
        readOnly: !_isEditing,
        placeholder: placeholder,
        validator: validator,
        style: GoogleFonts.outfit(fontSize: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: WidgetStateProperty.all(
          BoxDecoration(
            color: _isEditing
                ? theme.resources.controlFillColorDefault
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isEditing
                  ? theme.resources.dividerStrokeColorDefault
                  : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}
