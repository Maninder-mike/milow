import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/toast_notification.dart';

class OrganizationPanel extends StatefulWidget {
  const OrganizationPanel({super.key});

  @override
  State<OrganizationPanel> createState() => _OrganizationPanelState();
}

class _OrganizationPanelState extends State<OrganizationPanel> {
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isAdmin = false;

  // Company Details Controllers
  final _compNameController = TextEditingController();
  final _compAddressController = TextEditingController();
  final _compCityController = TextEditingController();
  final _compStateController = TextEditingController();
  final _compZipController = TextEditingController();
  final _compDotController = TextEditingController();
  final _compMcController = TextEditingController();
  final _compPhoneController = TextEditingController();
  final _compEmailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOrganizationDetails();
  }

  Future<void> _loadOrganizationDetails() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      final role = profile['role'] as String? ?? '';
      _isAdmin =
          role.toLowerCase() == 'admin' ||
          (user.email?.contains('admin') ?? false);

      Map<String, dynamic>? companyData;
      final companyId = profile['company_id'] as String?;

      if (companyId != null) {
        companyData = await Supabase.instance.client
            .from('companies')
            .select()
            .eq('id', companyId)
            .maybeSingle();
      }

      companyData ??= profile;

      if (mounted) {
        setState(() {
          _compNameController.text =
              companyData?['name'] ?? companyData?['company_name'] ?? '';
          _compAddressController.text =
              companyData?['address'] ?? companyData?['company_address'] ?? '';
          _compCityController.text =
              companyData?['city'] ?? companyData?['company_city'] ?? '';
          _compStateController.text =
              companyData?['state'] ?? companyData?['company_state'] ?? '';
          _compZipController.text =
              companyData?['zip_code'] ?? companyData?['company_zip'] ?? '';
          _compDotController.text =
              companyData?['dot_number'] ??
              companyData?['company_dot_number'] ??
              '';
          _compMcController.text =
              companyData?['mc_number'] ??
              companyData?['company_mc_number'] ??
              '';
          _compPhoneController.text =
              companyData?['phone'] ?? companyData?['company_phone'] ?? '';
          _compEmailController.text =
              companyData?['email'] ?? companyData?['company_email'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading org details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveOrganizationDetails() async {
    if (!_isAdmin) return;
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .single();

      final companyId = profile['company_id'] as String?;

      if (companyId != null) {
        await Supabase.instance.client
            .from('companies')
            .update({
              'name': _compNameController.text,
              'address': _compAddressController.text,
              'city': _compCityController.text,
              'state': _compStateController.text,
              'zip_code': _compZipController.text,
              'dot_number': _compDotController.text,
              'mc_number': _compMcController.text,
              'phone': _compPhoneController.text,
              'email': _compEmailController.text,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', companyId);
      }

      await Supabase.instance.client
          .from('profiles')
          .update({
            'company_name': _compNameController.text,
            'company_address': _compAddressController.text,
            'company_city': _compCityController.text,
            'company_state': _compStateController.text,
            'company_zip': _compZipController.text,
            'company_dot_number': _compDotController.text,
            'company_mc_number': _compMcController.text,
            'company_phone': _compPhoneController.text,
            'company_email': _compEmailController.text,
          })
          .eq('id', user.id);

      if (mounted) {
        showToast(
          context,
          title: 'Saved',
          message: 'Organization details updated.',
        );
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        showToast(
          context,
          title: 'Error',
          message: e.toString(),
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

    if (!_isAdmin && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FluentIcons.lock_closed_24_regular,
              size: 48,
              color: theme.resources.textFillColorSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Restricted Access',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Only administrators can manage organization settings.'),
          ],
        ),
      );
    }

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: Text(
          'Organization',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        commandBar: _isAdmin
            ? CommandBar(
                primaryItems: [
                  if (_isEditing)
                    CommandBarButton(
                      icon: const Icon(FluentIcons.dismiss_24_regular),
                      label: const Text('Cancel'),
                      onPressed: () => setState(() => _isEditing = false),
                    ),
                  CommandBarButton(
                    icon: Icon(
                      _isEditing
                          ? FluentIcons.save_24_regular
                          : FluentIcons.edit_24_regular,
                    ),
                    label: Text(_isEditing ? 'Save Changes' : 'Edit Details'),
                    onPressed: _isEditing
                        ? (_isLoading ? null : _saveOrganizationDetails)
                        : () => setState(() => _isEditing = true),
                  ),
                ],
              )
            : null,
      ),
      children: [
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: ProgressBar(),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategory(
                  context,
                  title: 'Company Profile',
                  description:
                      'Manage your official carrier information for invoices and rate confirmations.',
                  icon: FluentIcons.organization_24_regular,
                  children: [
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildIdentitySection(context)),
                          const SizedBox(width: 48),
                          Expanded(child: _buildContactSection(context)),
                        ],
                      )
                    else ...[
                      _buildIdentitySection(context),
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 32),
                      _buildContactSection(context),
                    ],
                  ],
                ),
                const SizedBox(height: 48),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategory(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = FluentTheme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.resources.surfaceStrokeColorDefault,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: theme.accentColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.resources.textFillColorSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ...children,
        ],
      ),
    );
  }

  Widget _buildIdentitySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Identity Details'),
        const SizedBox(height: 24),
        _buildField(
          'Company Name',
          _compNameController,
          placeholder: 'Legal Company Name',
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildField(
                'DOT Number',
                _compDotController,
                placeholder: 'USDOT#',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildField(
                'MC Number',
                _compMcController,
                placeholder: 'MC#',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Contact & Location'),
        const SizedBox(height: 24),
        _buildField(
          'Address',
          _compAddressController,
          placeholder: 'Street Address',
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(flex: 2, child: _buildField('City', _compCityController)),
            const SizedBox(width: 12),
            Expanded(
              child: _buildField(
                'State',
                _compStateController,
                placeholder: 'XX',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildField('Zip', _compZipController)),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildField(
                'Phone',
                _compPhoneController,
                placeholder: '+1 ...',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildField(
                'Email',
                _compEmailController,
                placeholder: 'admin@...',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    final theme = FluentTheme.of(context);
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: theme.accentColor,
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    String? placeholder,
  }) {
    final theme = FluentTheme.of(context);

    if (!_isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.resources.textFillColorSecondary,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            controller.text.isNotEmpty ? controller.text : '-',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return InfoLabel(
      label: label,
      labelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500),
      child: TextFormBox(
        controller: controller,
        placeholder: placeholder,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  @override
  void dispose() {
    _compNameController.dispose();
    _compAddressController.dispose();
    _compCityController.dispose();
    _compStateController.dispose();
    _compZipController.dispose();
    _compDotController.dispose();
    _compMcController.dispose();
    _compPhoneController.dispose();
    _compEmailController.dispose();
    super.dispose();
  }
}
