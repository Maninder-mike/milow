import 'dart:io';

import 'package:flutter/material.dart';
import 'package:milow/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:milow/core/services/profile_service.dart';
import 'package:milow/core/services/profile_repository.dart';
import 'package:milow/core/models/country_code.dart';
import 'package:milow/core/widgets/country_code_selector.dart';
import 'package:milow/core/utils/error_handler.dart';
import 'package:milow/core/widgets/glassy_card.dart';
import 'package:path/path.dart' show extension;

// Expected local (national) number lengths from previous implementation
const Map<String, List<int>> _countryLocalLengths = {
  '+1': [10],
  '+44': [10],
  '+91': [10],
  '+61': [9],
  '+81': [10],
  '+49': [10, 11],
  '+33': [9],
  '+34': [9],
  '+52': [10],
  '+31': [9],
  '+32': [9],
  '+39': [10],
  '+86': [11],
  '+7': [10],
  '+27': [9],
  '+55': [10, 11],
};

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Personal Info
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  CountryCode _selectedCountryCode = countryCodes[0];

  // Address
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _countryController = TextEditingController(); // Or use a selector

  // Driver Info
  final _licenseNumberController = TextEditingController();
  final _licenseTypeController = TextEditingController();
  final _fastIdController = TextEditingController();
  DateTime? _dob;
  CountryCode? _citizenship;

  // Company Info
  Map<String, dynamic>? _companyInfo;

  String? _avatarUrl;
  XFile? _pickedImage;
  bool _loading = true;
  bool _saving = false;

  String _formatCompanyAddress(Map<String, dynamic> info) {
    // Check if 'companies' is a list (one-to-many from Supabase view) and take first
    // Note: 'companies' from select('*, companies(*)') returns a List<dynamic> even if singular relation
    // Wait, let's verification in _populateFields handles structure.
    // Assuming passed info is the map of the company.

    final parts = [
      info['address'],
      info['city'],
      info['state'],
      info['zip_code'],
      info['country'],
    ].where((p) => p != null && p.toString().isNotEmpty).join(', ');
    return parts.isEmpty ? 'address not set' : parts;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileRepository.getCachedFirst(refresh: false);
    if (profile != null) {
      _populateFields(profile);
      setState(() => _loading = false);
    } else {
      setState(() => _loading = false);
    }

    final fresh = await ProfileRepository.refresh();
    if (!mounted) return;
    if (fresh != null) {
      _populateFields(fresh);
      // Ensure loading is off if it was on, but only refresh state if mounted
      if (mounted) setState(() => _loading = false);
    }
  }

  void _populateFields(Map<String, dynamic> data) {
    _nameController.text = data['full_name'] ?? '';
    _emailController.text = data['email'] ?? '';

    // Address Split
    _streetController.text = data['street'] ?? '';
    _cityController.text = data['city'] ?? '';
    _stateController.text = data['state_province'] ?? '';
    _zipController.text = data['postal_code'] ?? '';
    // Use stored country name or default/empty
    _countryController.text = data['country'] ?? '';

    // Driver Info
    _licenseNumberController.text = data['license_number'] ?? '';
    _licenseTypeController.text = data['license_type'] ?? '';
    _fastIdController.text = data['fast_id'] ?? '';

    if (data['date_of_birth'] != null) {
      try {
        _dob = DateTime.parse(data['date_of_birth']);
      } catch (e) {
        debugPrint('Error parsing date_of_birth: $e');
      }
    }

    final citizenshipCode = data['citizenship'];
    if (citizenshipCode != null) {
      try {
        _citizenship = countryCodes.firstWhere(
          (c) =>
              c.name.toLowerCase() ==
                  citizenshipCode.toString().toLowerCase() ||
              c.code == citizenshipCode,
          orElse: () => countryCodes[0],
        );
        try {
          _citizenship = countryCodes.firstWhere(
            (c) =>
                c.name.toLowerCase() ==
                    citizenshipCode.toString().toLowerCase() ||
                c.code == citizenshipCode,
          );
        } catch (_) {
          _citizenship = null;
        }
      } catch (e) {
        debugPrint('Error parsing citizenship: $e');
      }
    }

    if (data['companies'] != null) {
      // companies is likely a map if singular join (maybeSingle) or list?
      // supabase_flutter v2 client with select('*, companies(*)') usually returns a list if it's one-to-many,
      // or single object if one-to-one and forced?
      // Let's assume list and take first, or map.
      // Safest check:
      final comp = data['companies'];
      if (comp is List && comp.isNotEmpty) {
        _companyInfo = comp.first as Map<String, dynamic>;
      } else if (comp is Map<String, dynamic>) {
        _companyInfo = comp;
      }
    } else {
      if (data['company_name'] != null) {
        _companyInfo = {'name': data['company_name']};
      }
    }

    _avatarUrl = data['avatar_url'] as String?;

    // Phone parsing logic
    final phoneNumber = data['phone'] as String? ?? '';
    if (phoneNumber.isNotEmpty) {
      final parsedCountry = parsePhoneNumber(phoneNumber);
      if (parsedCountry != null) {
        _selectedCountryCode = parsedCountry;
        _phoneController.text =
            extractPhoneNumber(phoneNumber, parsedCountry) ?? '';
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    String? newAvatarUrl = _avatarUrl;
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (_pickedImage != null) {
        final bytes = await _pickedImage!.readAsBytes();
        final filename =
            'avatar_${DateTime.now().millisecondsSinceEpoch}${extension(_pickedImage!.path)}';
        newAvatarUrl = await ProfileService.uploadAvatar(
          bytes: bytes,
          filename: filename,
        );
      }

      String fullPhone = '';
      final localPhone = _phoneController.text.trim();
      if (localPhone.isNotEmpty) {
        fullPhone = '${_selectedCountryCode.dialCode}$localPhone';
        // Insert validation logic here similar to previous impl
        final e164Pattern = RegExp(r'^\+[1-9]\d{7,14}$');
        if (!e164Pattern.hasMatch(fullPhone)) {
          setState(() => _saving = false);
          messenger.showSnackBar(
            const SnackBar(content: Text('Invalid international phone length')),
          );
          return;
        }
      }

      final dobString = _dob != null
          ? DateFormat('yyyy-MM-dd').format(_dob!)
          : null;
      final citizenshipVal = _citizenship?.name;

      await ProfileRepository.updateOptimistic({
        'full_name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': fullPhone,
        'street': _streetController.text.trim(),
        'city': _cityController.text.trim(),
        'state_province': _stateController.text.trim(),
        'postal_code': _zipController.text.trim(),
        'country': _countryController.text.trim(),
        'date_of_birth': dobString,
        'license_number': _licenseNumberController.text.trim(),
        'license_type': _licenseTypeController.text.trim(),
        'fast_id': _fastIdController.text.trim(),
        'citizenship': citizenshipVal,
        'avatar_url': newAvatarUrl,
      });

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(ErrorHandler.getErrorMessage(e))),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showImageOptions(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.camera_alt,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                title: Text(
                  'Take Photo',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 80);
    if (image != null) setState(() => _pickedImage = image);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dob) {
      setState(() {
        _dob = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1a1a2e),
                    const Color(0xFF16213e),
                    const Color(0xFF0f0f1a),
                  ]
                : [
                    const Color(0xFFF0F4FF),
                    const Color(0xFFFDF2F8),
                    const Color(0xFFF0FDF4),
                  ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
          children: [
            _buildAppBar(context, textColor),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            _buildAvatarSection(context, isDark),
                            const SizedBox(height: 32),

                            _buildSectionHeader('PERSONAL INFORMATION', isDark),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: GlassyCard(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    _buildTextField(
                                      controller: _nameController,
                                      label: 'Full Name',
                                      icon: Icons.person_outline,
                                      validator: (v) =>
                                          v!.isEmpty ? 'Name Required' : null,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTextField(
                                      controller: _emailController,
                                      label: 'Email Address',
                                      icon: Icons.email_outlined,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (v) =>
                                          (!RegExp(
                                            r'\S+@\S+\.\S+',
                                          ).hasMatch(v!))
                                          ? 'Invalid Email'
                                          : null,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildPhoneField(
                                      context,
                                      isDark,
                                      textColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),
                            _buildSectionHeader('ADDRESS', isDark),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: GlassyCard(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    _buildTextField(
                                      controller: _streetController,
                                      label: 'Street',
                                      icon: Icons.home_outlined,
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildTextField(
                                            controller: _cityController,
                                            label: 'City',
                                            icon: Icons.location_city,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildTextField(
                                            controller: _stateController,
                                            label: 'State/Prov',
                                            icon: Icons.map_outlined,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildTextField(
                                            controller: _zipController,
                                            label: 'Zip/Postal',
                                            icon: Icons.pin_drop_outlined,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildTextField(
                                            controller: _countryController,
                                            label: 'Country',
                                            icon: Icons.public_outlined,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),
                            _buildSectionHeader('DRIVER INFORMATION', isDark),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: GlassyCard(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDateField(
                                      context,
                                      'Date of Birth',
                                      _dob,
                                      () => _selectDate(context),
                                      isDark,
                                      textColor,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTextField(
                                      controller: _licenseNumberController,
                                      label: "Driver's License Number",
                                      icon: Icons.badge_outlined,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTextField(
                                      controller: _licenseTypeController,
                                      label: "Driver's License Type",
                                      icon: Icons.local_shipping_outlined,
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildCountrySelectorField(
                                            context,
                                            'Citizenship',
                                            _citizenship,
                                            (c) => setState(
                                              () => _citizenship = c,
                                            ),
                                            isDark,
                                            textColor,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildTextField(
                                            controller: _fastIdController,
                                            label: 'Fast ID (Optional)',
                                            icon: Icons.card_membership,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),
                            /* Company Info Card */
                            _buildSectionHeader('COMPANY INFORMATION', isDark),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: GlassyCard(
                                padding: const EdgeInsets.all(20),
                                child: _companyInfo == null
                                    ? Center(
                                        child: Text(
                                          'No Company Information',
                                          style: GoogleFonts.inter(
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      )
                                    : Column(
                                        children: [
                                          _buildReadOnlyField(
                                            'Company Name',
                                            _companyInfo!['name'] ?? '',
                                            Icons.business,
                                            isDark,
                                            textColor,
                                          ),
                                          const SizedBox(height: 16),
                                          _buildReadOnlyField(
                                            'Address',
                                            _formatCompanyAddress(
                                              _companyInfo!,
                                            ),
                                            Icons.location_on_outlined,
                                            isDark,
                                            textColor,
                                          ),
                                          const SizedBox(height: 16),
                                          _buildReadOnlyField(
                                            'Contact',
                                            _companyInfo!['phone'] ??
                                                _companyInfo!['email'] ??
                                                '-',
                                            Icons.contact_phone_outlined,
                                            isDark,
                                            textColor,
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            const SizedBox(height: 32),
                            _buildActionButtons(context, isDark, textColor),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, Color textColor) {
    return AppBar(
      title: Text(
        AppLocalizations.of(context)?.editProfile ?? 'Edit Profile',
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: textColor),
        onPressed: () => context.pop(),
      ),
    );
  }

  Widget _buildAvatarSection(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showImageOptions(context, isDark),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 60,
                backgroundColor: const Color(0xFFBFDBFE),
                backgroundImage: _pickedImage != null
                    ? FileImage(File(_pickedImage!.path))
                    : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                    ? NetworkImage(_avatarUrl!)
                    : null,
                child: (_avatarUrl == null && _pickedImage == null)
                    ? const Icon(
                        Icons.person,
                        size: 60,
                        color: Color(0xFF3B82F6),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap to change photo',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white70 : const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(
    String label,
    String value,
    IconData icon,
    bool isDark,
    Color textColor,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF007AFF), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white60 : const Color(0xFF98A2B3),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 15, color: textColor),
          decoration: _inputDecoration(context, icon, hintText, isDark),
        ),
      ],
    );
  }

  Widget _buildDateField(
    BuildContext context,
    String label,
    DateTime? date,
    VoidCallback onTap,
    bool isDark,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: AbsorbPointer(
            child: TextFormField(
              controller: TextEditingController(
                text: date != null ? DateFormat.yMMMd().format(date) : '',
              ),
              style: GoogleFonts.inter(fontSize: 15, color: textColor),
              decoration: _inputDecoration(
                context,
                Icons.calendar_today_outlined,
                'Select Date',
                isDark,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountrySelectorField(
    BuildContext context,
    String label,
    CountryCode? selected,
    ValueChanged<CountryCode> onChanged,
    bool isDark,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE5E7EB),
            ),
          ),
          child: CountryCodeSelector(
            selectedCountry: selected ?? countryCodes[0],
            onCountryChanged: onChanged,
            showCountryName: true,
            showDialCode: false,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField(BuildContext context, bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact Number',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CountryCodeSelector(
              selectedCountry: _selectedCountryCode,
              onCountryChanged: (c) => setState(() => _selectedCountryCode = c),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  // Logic from previous impl
                  if (v == null || v.trim().isEmpty) return null;
                  if (!RegExp(r'^\d{4,15}$').hasMatch(v.trim())) {
                    return 'Enter digits (4-15)';
                  }
                  final lengths =
                      _countryLocalLengths[_selectedCountryCode.dialCode];
                  if (lengths != null && !lengths.contains(v.trim().length)) {
                    return 'Expect ${lengths.join(' or ')} digits';
                  }
                  return null;
                },
                style: GoogleFonts.inter(fontSize: 15, color: textColor),
                decoration: _inputDecoration(
                  context,
                  Icons.phone_outlined,
                  'Phone number',
                  isDark,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Reusable decoration
  InputDecoration _inputDecoration(
    BuildContext context,
    IconData? icon,
    String? hint,
    bool isDark,
  ) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        fontSize: 15,
        color: const Color(0xFF98A2B3),
      ),
      prefixIcon: icon != null
          ? Icon(icon, color: const Color(0xFF007AFF), size: 20)
          : null,
      filled: true,
      fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE5E7EB),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE5E7EB),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF007AFF), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      errorStyle: GoogleFonts.inter(fontSize: 12, color: Colors.red),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    bool isDark,
    Color textColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF3A3A3A)
                      : const Color(0xFFE5E7EB),
                ),
                backgroundColor: isDark ? Colors.black12 : Colors.white54,
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF007AFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Save',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
