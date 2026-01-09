import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Page for configuring a role's permissions
class RoleConfigurationPage extends ConsumerStatefulWidget {
  final String roleId;

  const RoleConfigurationPage({super.key, required this.roleId});

  @override
  ConsumerState<RoleConfigurationPage> createState() =>
      _RoleConfigurationPageState();
}

class _RoleConfigurationPageState extends ConsumerState<RoleConfigurationPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  Map<String, dynamic>? _role;
  List<Map<String, dynamic>> _allPermissions = [];
  Map<String, _PermissionState> _permissionStates = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Fetch role details
      final roleResponse = await supabase
          .from('roles')
          .select('id, name, description, is_system_role')
          .eq('id', widget.roleId)
          .single();

      _role = roleResponse;
      _nameController.text = roleResponse['name'] as String? ?? '';
      _descriptionController.text =
          roleResponse['description'] as String? ?? '';

      // Fetch all available permissions
      final permissionsResponse = await supabase
          .from('permissions')
          .select('id, code, category, description')
          .order('category')
          .order('code');

      _allPermissions = List<Map<String, dynamic>>.from(permissionsResponse);

      // Fetch current role permissions
      final rolePermissionsResponse = await supabase
          .from('role_permissions')
          .select('permission_id, can_read, can_write, can_delete')
          .eq('role_id', widget.roleId);

      // Build permission states map
      _permissionStates = {};
      for (final perm in _allPermissions) {
        final permId = perm['id'] as String;
        _permissionStates[permId] = _PermissionState();
      }

      for (final rp in rolePermissionsResponse as List) {
        final permId = rp['permission_id'] as String;
        if (_permissionStates.containsKey(permId)) {
          _permissionStates[permId] = _PermissionState(
            canRead: rp['can_read'] as bool? ?? false,
            canWrite: rp['can_write'] as bool? ?? false,
            canDelete: rp['can_delete'] as bool? ?? false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Error'),
            content: Text('Failed to load role: $e'),
            severity: InfoBarSeverity.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      final supabase = Supabase.instance.client;

      // Update role details
      await supabase
          .from('roles')
          .update({
            'name': _nameController.text,
            'description': _descriptionController.text,
          })
          .eq('id', widget.roleId);

      // Delete existing permissions and insert new ones
      await supabase
          .from('role_permissions')
          .delete()
          .eq('role_id', widget.roleId);

      // Insert new permissions
      final permissionsToInsert = <Map<String, dynamic>>[];
      for (final entry in _permissionStates.entries) {
        final state = entry.value;
        if (state.canRead || state.canWrite || state.canDelete) {
          permissionsToInsert.add({
            'role_id': widget.roleId,
            'permission_id': entry.key,
            'can_read': state.canRead,
            'can_write': state.canWrite,
            'can_delete': state.canDelete,
          });
        }
      }

      if (permissionsToInsert.isNotEmpty) {
        await supabase.from('role_permissions').insert(permissionsToInsert);
      }

      setState(() => _hasChanges = false);

      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Saved'),
            content: const Text('Role permissions updated successfully.'),
            severity: InfoBarSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Error'),
            content: Text('Failed to save: $e'),
            severity: InfoBarSeverity.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isSystemRole = _role?['is_system_role'] as bool? ?? false;

    if (_isLoading) {
      return const ScaffoldPage(content: Center(child: ProgressRing()));
    }

    // Group permissions by category
    final permissionsByCategory = <String, List<Map<String, dynamic>>>{};
    for (final perm in _allPermissions) {
      final category = perm['category'] as String? ?? 'other';
      permissionsByCategory.putIfAbsent(category, () => []).add(perm);
    }

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            IconButton(
              icon: const Icon(FluentIcons.arrow_left_24_regular),
              onPressed: () => context.go('/settings/users-roles'),
            ),
            const SizedBox(width: 8),
            Text(
              'Configure Role',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  : const Icon(FluentIcons.save_24_regular),
              label: const Text('Save Changes'),
              onPressed: (_hasChanges && !isSystemRole && !_isSaving)
                  ? _saveChanges
                  : null,
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Role Details Card
            _buildCard(
              theme: theme,
              title: 'Role Details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoLabel(
                    label: 'Role Name',
                    child: TextBox(
                      controller: _nameController,
                      placeholder: 'Enter role name',
                      enabled: !isSystemRole,
                      onChanged: (_) => setState(() => _hasChanges = true),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InfoLabel(
                    label: 'Description',
                    child: TextBox(
                      controller: _descriptionController,
                      placeholder: 'Describe what this role can do',
                      maxLines: 2,
                      enabled: !isSystemRole,
                      onChanged: (_) => setState(() => _hasChanges = true),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Permissions Section
            Text(
              'Permissions',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.resources.textFillColorPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure what users with this role can access.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: theme.resources.textFillColorSecondary,
              ),
            ),
            const SizedBox(height: 16),

            if (isSystemRole)
              const InfoBar(
                title: Text('System Role'),
                content: Text('System roles cannot be modified.'),
                severity: InfoBarSeverity.warning,
              ),

            if (!isSystemRole)
              // Permission Categories
              ...permissionsByCategory.entries.map((entry) {
                return _buildPermissionCategory(
                  theme: theme,
                  category: entry.key,
                  permissions: entry.value,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required FluentThemeData theme,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.resources.textFillColorPrimary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildPermissionCategory({
    required FluentThemeData theme,
    required String category,
    required List<Map<String, dynamic>> permissions,
  }) {
    final categoryTitle = category[0].toUpperCase() + category.substring(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
      ),
      child: Expander(
        initiallyExpanded: true,
        header: Text(
          categoryTitle,
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        content: Column(
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Permission',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.resources.textFillColorSecondary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Center(
                      child: Text(
                        'Read',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Center(
                      child: Text(
                        'Write',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Center(
                      child: Text(
                        'Delete',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Permission rows
            ...permissions.map((perm) => _buildPermissionRow(theme, perm)),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionRow(
    FluentThemeData theme,
    Map<String, dynamic> permission,
  ) {
    final permId = permission['id'] as String;
    final code = permission['code'] as String? ?? '';
    final description = permission['description'] as String? ?? code;
    final state = _permissionStates[permId] ?? _PermissionState();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description, style: GoogleFonts.outfit(fontSize: 13)),
                Text(
                  code,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: theme.resources.textFillColorTertiary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Center(
              child: Checkbox(
                checked: state.canRead,
                onChanged: (value) {
                  setState(() {
                    _permissionStates[permId] = state.copyWith(
                      canRead: value ?? false,
                    );
                    _hasChanges = true;
                  });
                },
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Center(
              child: Checkbox(
                checked: state.canWrite,
                onChanged: (value) {
                  setState(() {
                    _permissionStates[permId] = state.copyWith(
                      canWrite: value ?? false,
                    );
                    _hasChanges = true;
                  });
                },
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Center(
              child: Checkbox(
                checked: state.canDelete,
                onChanged: (value) {
                  setState(() {
                    _permissionStates[permId] = state.copyWith(
                      canDelete: value ?? false,
                    );
                    _hasChanges = true;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper class to track permission state
class _PermissionState {
  final bool canRead;
  final bool canWrite;
  final bool canDelete;

  const _PermissionState({
    this.canRead = false,
    this.canWrite = false,
    this.canDelete = false,
  });

  _PermissionState copyWith({bool? canRead, bool? canWrite, bool? canDelete}) {
    return _PermissionState(
      canRead: canRead ?? this.canRead,
      canWrite: canWrite ?? this.canWrite,
      canDelete: canDelete ?? this.canDelete,
    );
  }
}
