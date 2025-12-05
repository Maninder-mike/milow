import 'dart:io';

import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:milow/core/services/profile_service.dart';
import 'package:milow/core/services/profile_repository.dart';
import 'package:milow/core/models/country_code.dart';
import 'package:milow/core/widgets/country_code_selector.dart';
import 'package:milow/core/utils/error_handler.dart';

// Expected local (national) number lengths for common dial codes (excluding country code).
// If a dial code is not listed, generic validation 4-15 digits applies.
const Map<String, List<int>> _countryLocalLengths = {
  '+1': [10], // US/CA
  '+44': [10], // UK (simplified)
  '+91': [10], // India
  '+61': [9], // Australia
  '+81': [10], // Japan
  '+49': [10, 11], // Germany
  '+33': [9], // France
  '+34': [9], // Spain
  '+52': [10], // Mexico
  '+31': [9], // Netherlands
  '+32': [9], // Belgium
  '+39': [10], // Italy (common mobile length)
  '+86': [11], // China
  '+7': [10], // Russia
  '+27': [9], // South Africa
  '+55': [10, 11], // Brazil varying
};

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _countryController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _companyCodeController = TextEditingController();

  String? _avatarUrl;
  XFile? _pickedImage;
  bool _loading = true;
  bool _saving = false;
  CountryCode _selectedCountryCode = countryCodes[0]; // Default to US

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    // Load cached first for instant form fill
    final profile = await ProfileRepository.getCachedFirst(refresh: false);
    if (profile != null) {
      final phoneNumber = profile['phone'] as String? ?? '';
      CountryCode? parsedCountry;
      String localNumber = '';

      if (phoneNumber.isNotEmpty) {
        parsedCountry = parsePhoneNumber(phoneNumber);
        if (parsedCountry != null) {
          localNumber = extractPhoneNumber(phoneNumber, parsedCountry) ?? '';
        }
      }

      setState(() {
        _nameController.text = profile['full_name'] ?? '';
        _addressController.text = profile['address'] ?? '';
        _countryController.text = profile['country'] ?? '';
        _phoneController.text = localNumber;
        _selectedCountryCode = parsedCountry ?? countryCodes[0];
        _emailController.text = profile['email'] ?? '';
        _companyNameController.text = profile['company_name'] ?? '';
        _companyCodeController.text = profile['company_code'] ?? '';
        _avatarUrl = profile['avatar_url'] as String?;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }

    // Refresh from Supabase to ensure latest
    final fresh = await ProfileRepository.refresh();
    if (!mounted) return;
    if (fresh != null) {
      final phoneNumber = fresh['phone'] as String? ?? '';
      CountryCode? parsedCountry;
      String localNumber = '';

      if (phoneNumber.isNotEmpty) {
        parsedCountry = parsePhoneNumber(phoneNumber);
        if (parsedCountry != null) {
          localNumber = extractPhoneNumber(phoneNumber, parsedCountry) ?? '';
        }
      }

      setState(() {
        _nameController.text = fresh['full_name'] ?? '';
        _addressController.text = fresh['address'] ?? '';
        _countryController.text = fresh['country'] ?? '';
        _phoneController.text = localNumber;
        _selectedCountryCode = parsedCountry ?? countryCodes[0];
        _emailController.text = fresh['email'] ?? '';
        _companyNameController.text = fresh['company_name'] ?? '';
        _companyCodeController.text = fresh['company_code'] ?? '';
        _avatarUrl = fresh['avatar_url'] as String?;
      });
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
    if (image != null) {
      setState(() {
        _pickedImage = image;
      });
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
            'avatar_${DateTime.now().millisecondsSinceEpoch}${extension(_pickedImage!)}';
        newAvatarUrl = await ProfileService.uploadAvatar(
          bytes: bytes,
          filename: filename,
        );
      }

      // Combine country code + phone number into E.164 format
      String fullPhone = '';
      final localPhone = _phoneController.text.trim();
      if (localPhone.isNotEmpty) {
        fullPhone = '${_selectedCountryCode.dialCode}$localPhone';
        // Save-time validation for full international number length (E.164: up to 15 digits)
        final e164Pattern = RegExp(
          r'^\+[1-9]\d{7,14}$',
        ); // 8-15 digits total excluding '+'
        if (!e164Pattern.hasMatch(fullPhone)) {
          setState(() => _saving = false);
          messenger.showSnackBar(
            const SnackBar(content: Text('Invalid international phone length')),
          );
          return;
        }
        // Country-specific local length double-check (already done in field but repeated for safety)
        final lengths = _countryLocalLengths[_selectedCountryCode.dialCode];
        if (lengths != null && !lengths.contains(localPhone.length)) {
          setState(() => _saving = false);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Local number must be ${lengths.join(' or ')} digits',
              ),
            ),
          );
          return;
        }
      }

      await ProfileRepository.updateOptimistic({
        'full_name': _nameController.text.trim(),
        // username removed from schema
        'address': _addressController.text.trim(),
        'country': _countryController.text.trim(),
        'phone': fullPhone,
        'email': _emailController.text.trim(),
        'company_name': _companyNameController.text.trim(),
        'company_code': _companyCodeController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF9FAFB);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
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
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF007AFF),
                strokeWidth: 3.0,
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      // Avatar Section
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () => _showImageOptions(context, isDark),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF007AFF,
                                      ).withValues(alpha: 0.2),
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
                                      : (_avatarUrl != null &&
                                            _avatarUrl!.isNotEmpty)
                                      ? NetworkImage(_avatarUrl!)
                                      : null,
                                  child:
                                      (_avatarUrl == null &&
                                          _pickedImage == null)
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
                                color: const Color(0xFF667085),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Form Fields
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'PERSONAL INFORMATION',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF98A2B3),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(20),
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
                            _buildTextField(
                              controller: _nameController,
                              label: 'Full Name',
                              icon: Icons.person_outline,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email Address',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                final valid = RegExp(
                                  r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
                                  caseSensitive: false,
                                ).hasMatch(v.trim());
                                if (!valid) return 'Invalid email format';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildPhoneField(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'LOCATION',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF98A2B3),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(20),
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
                            _buildTextField(
                              controller: _addressController,
                              label: 'Address',
                              icon: Icons.location_on_outlined,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _countryController,
                              label: 'Country',
                              icon: Icons.public_outlined,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'COMPANY INFORMATION',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF98A2B3),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(20),
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
                            _buildTextField(
                              controller: _companyNameController,
                              label: 'Company Name',
                              icon: Icons.business,
                              hintText: 'Optional',
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _companyCodeController,
                              label: 'Company Code',
                              icon: Icons.badge_outlined,
                              hintText: 'Optional',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Action Buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => context.pop(),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF3A3A3A)
                                        : const Color(0xFFE5E7EB),
                                  ),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  backgroundColor: const Color(0xFF007AFF),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                  shadowColor: const Color(
                                    0xFF007AFF,
                                  ).withValues(alpha: 0.3),
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
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPhoneField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.phone_outlined,
              size: 18,
              color: Color(0xFF007AFF),
            ),
            const SizedBox(width: 8),
            Text(
              'Contact Number',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CountryCodeSelector(
              selectedCountry: _selectedCountryCode,
              onCountryChanged: (country) {
                setState(() {
                  _selectedCountryCode = country;
                });
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return null; // optional
                  }
                  final s = v.trim();
                  // Basic validation - just check if it's numeric and reasonable length
                  if (!RegExp(r'^\d{4,15}$').hasMatch(s)) {
                    return 'Enter digits only (4-15)';
                  }
                  final lengths =
                      _countryLocalLengths[_selectedCountryCode.dialCode];
                  if (lengths != null && !lengths.contains(s.length)) {
                    return 'Expect ${lengths.join(' or ')} digits';
                  }
                  return null;
                },
                style: GoogleFonts.inter(fontSize: 15, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Phone number',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 15,
                    color: const Color(0xFF98A2B3),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF3A3A3A)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF007AFF),
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  errorStyle: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF007AFF)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 15, color: textColor),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(
              fontSize: 15,
              color: const Color(0xFF98A2B3),
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF2A2A2A)
                : const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF3A3A3A)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF007AFF), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            errorStyle: GoogleFonts.inter(fontSize: 12, color: Colors.red),
          ),
        ),
      ],
    );
  }

  String extension(XFile file) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return '.png';
    if (name.endsWith('.jpg')) return '.jpg';
    if (name.endsWith('.jpeg')) return '.jpeg';
    return '.jpg';
  }
}
