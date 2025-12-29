import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';
import 'package:intl/intl.dart';
import 'package:milow/core/services/profile_repository.dart';
import 'package:milow/core/models/country_code.dart';
import 'package:milow/core/widgets/country_code_selector.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Personal Info
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  CountryCode _selectedCountryCode = countryCodes[0];

  // Address Info
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _zipController;
  late TextEditingController _countryController;

  // Driver Info
  late TextEditingController _licenseNumberController;
  late TextEditingController _licenseTypeController;
  late TextEditingController _fastIdController;
  DateTime? _dob;
  DateTime? _licenseExpiryDate;
  CountryCode? _citizenship;

  bool _isLoading = false;
  File? _imageFile;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();

    _streetController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _zipController = TextEditingController();
    _countryController = TextEditingController();

    _licenseNumberController = TextEditingController();
    _licenseTypeController = TextEditingController();
    _fastIdController = TextEditingController();

    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final data = await ProfileRepository.getCachedFirst(refresh: true);
    if (data != null) {
      _populateFields(data);
    }
    setState(() => _isLoading = false);
  }

  void _populateFields(Map<String, dynamic> data) {
    _nameController.text = data['full_name'] ?? '';
    _emailController.text = data['email'] ?? '';

    // Address
    _streetController.text = data['street'] ?? '';
    _cityController.text = data['city'] ?? '';
    _stateController.text = data['state_province'] ?? '';
    _zipController.text = data['postal_code'] ?? '';
    _countryController.text = data['country'] ?? '';

    // Driver Info
    _licenseNumberController.text = data['license_number'] ?? '';
    _licenseTypeController.text = data['license_type'] ?? '';
    _fastIdController.text = data['fast_id'] ?? '';

    if (data['date_of_birth'] != null) {
      try {
        _dob = DateTime.parse(data['date_of_birth']);
      } catch (_) {}
    }

    if (data['license_expiry_date'] != null) {
      try {
        _licenseExpiryDate = DateTime.parse(data['license_expiry_date']);
      } catch (_) {}
    }

    final citizenshipCode = data['citizenship'];
    if (citizenshipCode != null) {
      try {
        _citizenship = countryCodes.firstWhere(
          (c) =>
              c.code == citizenshipCode ||
              c.name.toLowerCase() == citizenshipCode.toString().toLowerCase(),
          orElse: () => countryCodes[0],
        );
      } catch (_) {}
    }

    _avatarUrl = data['avatar_url'];

    // Phone parsing
    final phoneNumber = data['phone'] as String? ?? '';
    if (phoneNumber.isNotEmpty) {
      final country = parsePhoneNumber(phoneNumber);
      if (country != null) {
        _selectedCountryCode = country;
        _phoneController.text = extractPhoneNumber(phoneNumber, country) ?? '';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _countryController.dispose();
    _licenseNumberController.dispose();
    _licenseTypeController.dispose();
    _fastIdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      String? finalAvatarUrl = _avatarUrl;

      if (_imageFile != null) {
        final path =
            'avatars/${Supabase.instance.client.auth.currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage
            .from('avatars')
            .upload(path, _imageFile!);
        finalAvatarUrl = Supabase.instance.client.storage
            .from('avatars')
            .getPublicUrl(path);
      }

      final fullPhone =
          '${_selectedCountryCode.dialCode}${_phoneController.text.trim()}';

      final values = {
        'full_name': _nameController.text.trim(),
        'phone': fullPhone,
        'avatar_url': finalAvatarUrl,
        'street': _streetController.text.trim(),
        'city': _cityController.text.trim(),
        'state_province': _stateController.text.trim(),
        'postal_code': _zipController.text.trim(),
        'country': _countryController.text.trim(),
        'license_number': _licenseNumberController.text.trim(),
        'license_type': _licenseTypeController.text.trim(),
        'fast_id': _fastIdController.text.trim(),
        'date_of_birth': _dob?.toIso8601String(),
        'license_expiry_date': _licenseExpiryDate?.toIso8601String(),
        'citizenship': _citizenship?.code,
      };

      await ProfileRepository.updateOptimistic(values);

      if (mounted) {
        AppDialogs.showSuccess(context, 'Profile updated successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(context, 'Error updating profile: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dob = picked);
    }
  }

  void _selectLicenseExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _licenseExpiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
    );
    if (picked != null) {
      setState(() => _licenseExpiryDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0A0A0A)
        : const Color(0xFFF9FAFB);
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.outfit(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatarSection(primaryColor, backgroundColor),
                  const SizedBox(height: 40),

                  _buildSectionCard(
                    title: 'Personal Information',
                    children: [
                      _buildLabel('Full Name'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _nameController,
                        hint: 'Enter your name',
                        icon: Icons.person_outline,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),
                      _buildLabel('Email Address'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _emailController,
                        hint: 'Email',
                        icon: Icons.email_outlined,
                        isDark: isDark,
                        enabled: false,
                      ),
                      const SizedBox(height: 24),
                      _buildLabel('Phone Number'),
                      const SizedBox(height: 8),
                      _buildPhoneField(isDark),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _buildSectionCard(
                    title: 'Address Information',
                    children: [
                      _buildLabel('Street Address'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _streetController,
                        hint: '123 Trucker Way',
                        icon: Icons.home_outlined,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('City'),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _cityController,
                                  hint: 'Toronto',
                                  icon: Icons.location_city_outlined,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('State / Province'),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _stateController,
                                  hint: 'ON',
                                  icon: Icons.map_outlined,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Postal Code'),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _zipController,
                                  hint: 'M1B 2C3',
                                  icon: Icons.pin_drop_outlined,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Country'),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _countryController,
                                  hint: 'Canada',
                                  icon: Icons.public_outlined,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _buildSectionCard(
                    title: 'Driver Documents',
                    children: [
                      _buildLabel('License Number'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _licenseNumberController,
                        hint: 'A1234-56789-01234',
                        icon: Icons.badge_outlined,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('License Expiry Date'),
                      const SizedBox(height: 8),
                      _buildClickableField(
                        text: _licenseExpiryDate != null
                            ? DateFormat.yMMMd().format(_licenseExpiryDate!)
                            : 'Select Expiry Date',
                        icon: Icons.event_available_outlined,
                        onTap: _selectLicenseExpiry,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('License Type (Class)'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _licenseTypeController,
                        hint: 'Class AZ',
                        icon: Icons.category_outlined,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('FAST ID (Optional)'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _fastIdController,
                        hint: '12345678',
                        icon: Icons.security_outlined,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('Date of Birth'),
                      const SizedBox(height: 8),
                      _buildClickableField(
                        text: _dob != null
                            ? DateFormat.yMMMd().format(_dob!)
                            : 'Select Date',
                        icon: Icons.calendar_today_outlined,
                        onTap: _selectDate,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('Citizenship'),
                      const SizedBox(height: 8),
                      _buildCitizenshipSelector(isDark),
                    ],
                  ),

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),

          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: SafeArea(
          child: FilledButton(
            onPressed: _isLoading ? null : _saveProfile,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Save Changes',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(Color primaryColor, Color backgroundColor) {
    final subtext = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF667085);

    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: primaryColor.withOpacity(0.2),
                width: 4,
              ),
            ),
            child: CircleAvatar(
              radius: 56,
              backgroundColor: Theme.of(context).cardColor,
              backgroundImage: _imageFile != null
                  ? FileImage(_imageFile!)
                  : (_avatarUrl != null ? NetworkImage(_avatarUrl!) : null)
                        as ImageProvider?,
              child: _imageFile == null && _avatarUrl == null
                  ? Icon(Icons.person, size: 60, color: subtext)
                  : null,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: backgroundColor, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: CountryCodeSelector(
            selectedCountry: _selectedCountryCode,
            onCountryChanged: (c) => setState(() => _selectedCountryCode = c),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTextField(
            controller: _phoneController,
            hint: 'Phone number',
            icon: Icons.phone_outlined,
            isDark: isDark,
            keyboardType: TextInputType.phone,
          ),
        ),
      ],
    );
  }

  Widget _buildCitizenshipSelector(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: CountryCodeSelector(
        selectedCountry: _citizenship ?? countryCodes[0],
        onCountryChanged: (c) => setState(() => _citizenship = c),
        showCountryName: true,
        showDialCode: false,
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white70
            : const Color(0xFF475467),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool enabled = true,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final outlineVariant = Theme.of(context).colorScheme.outlineVariant;

    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.outfit(
        color: enabled
            ? (isDark ? Colors.white : const Color(0xFF101828))
            : (isDark ? Colors.white38 : Colors.black26),
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(
          color: const Color(0xFF98A2B3),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outlineVariant.withOpacity(0.5)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildClickableField({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final outlineVariant = Theme.of(context).colorScheme.outlineVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryColor, size: 20),
            const SizedBox(width: 12),
            Text(
              text,
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white : const Color(0xFF101828),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
