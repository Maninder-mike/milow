import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';
import 'package:intl/intl.dart';
import 'package:milow/core/services/profile_repository.dart';
import 'package:milow/core/models/country_code.dart';
import 'package:milow/core/widgets/country_code_selector.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
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
            '${Supabase.instance.client.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
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
    final tokens = context.tokens;
    final backgroundColor = tokens.scaffoldAltBackground;
    final textColor = tokens.textPrimary;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: Semantics(
          label: 'Back',
          hint: 'Go back to previous screen',
          button: true,
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          'Edit Profile',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: tokens.spacingM),
            child: Center(
              child: Semantics(
                label: 'Save Profile',
                button: true,
                child: FilledButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.shapeL),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: tokens.spacingM),
                    minimumSize: const Size(0, 40),
                  ),
                  child: Text(
                    'Save',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(tokens.spacingL),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatarSection(primaryColor, backgroundColor),
                    SizedBox(height: tokens.spacingXL),

                    _buildSectionCard(
                      title: 'Personal Information',
                      children: [
                        _buildLabel('Full Name'),
                        SizedBox(height: tokens.spacingS),
                        _buildTextField(
                          controller: _nameController,
                          hint: 'Enter your name',
                          icon: Icons.person_outline,
                        ),
                        SizedBox(height: tokens.spacingL),
                        _buildLabel('Email Address'),
                        SizedBox(height: tokens.spacingS),
                        _buildTextField(
                          controller: _emailController,
                          hint: 'Email',
                          icon: Icons.email_outlined,
                          enabled: false,
                        ),
                        SizedBox(height: tokens.spacingL),
                        _buildLabel('Phone Number'),
                        SizedBox(height: tokens.spacingS),
                        _buildPhoneField(),
                      ],
                    ),

                    SizedBox(height: tokens.spacingL),

                    _buildSectionCard(
                      title: 'Address Information',
                      children: [
                        _buildLabel('Street Address'),
                        SizedBox(height: tokens.spacingS),
                        _buildTextField(
                          controller: _streetController,
                          hint: '123 Trucker Way',
                          icon: Icons.home_outlined,
                        ),
                        SizedBox(height: tokens.spacingM),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('City'),
                                  SizedBox(height: tokens.spacingS),
                                  _buildTextField(
                                    controller: _cityController,
                                    hint: 'Toronto',
                                    icon: Icons.location_city_outlined,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: tokens.spacingM),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('State / Province'),
                                  SizedBox(height: tokens.spacingS),
                                  _buildTextField(
                                    controller: _stateController,
                                    hint: 'ON',
                                    icon: Icons.map_outlined,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: tokens.spacingM),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Postal Code'),
                                  SizedBox(height: tokens.spacingS),
                                  _buildTextField(
                                    controller: _zipController,
                                    hint: 'M1B 2C3',
                                    icon: Icons.pin_drop_outlined,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: tokens.spacingM),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Country'),
                                  SizedBox(height: tokens.spacingS),
                                  _buildTextField(
                                    controller: _countryController,
                                    hint: 'Canada',
                                    icon: Icons.public_outlined,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: tokens.spacingL),

                    _buildSectionCard(
                      title: 'Driver Documents',
                      children: [
                        _buildLabel('License Number'),
                        SizedBox(height: tokens.spacingS),
                        _buildTextField(
                          controller: _licenseNumberController,
                          hint: 'A1234-56789-01234',
                          icon: Icons.badge_outlined,
                        ),
                        SizedBox(height: tokens.spacingM),
                        _buildLabel('License Expiry Date'),
                        SizedBox(height: tokens.spacingS),
                        _buildClickableField(
                          text: _licenseExpiryDate != null
                              ? DateFormat.yMMMd().format(_licenseExpiryDate!)
                              : 'Select Expiry Date',
                          icon: Icons.event_available_outlined,
                          onTap: _selectLicenseExpiry,
                        ),
                        SizedBox(height: tokens.spacingM),
                        _buildLabel('License Type (Class)'),
                        SizedBox(height: tokens.spacingS),
                        _buildTextField(
                          controller: _licenseTypeController,
                          hint: 'Class AZ',
                          icon: Icons.category_outlined,
                        ),
                        SizedBox(height: tokens.spacingM),
                        _buildLabel('FAST ID (Optional)'),
                        SizedBox(height: tokens.spacingS),
                        _buildTextField(
                          controller: _fastIdController,
                          hint: '12345678',
                          icon: Icons.security_outlined,
                        ),
                        SizedBox(height: tokens.spacingM),
                        _buildLabel('Date of Birth'),
                        SizedBox(height: tokens.spacingS),
                        _buildClickableField(
                          text: _dob != null
                              ? DateFormat.yMMMd().format(_dob!)
                              : 'Select Date',
                          icon: Icons.calendar_today_outlined,
                          onTap: _selectDate,
                        ),
                        SizedBox(height: tokens.spacingM),
                        _buildLabel('Citizenship'),
                        SizedBox(height: tokens.spacingS),
                        _buildCitizenshipSelector(),
                      ],
                    ),

                    SizedBox(height: tokens.spacingXL),
                  ],
                ),
              ),
            ),

            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection(Color primaryColor, Color backgroundColor) {
    final tokens = context.tokens;
    final subtext = tokens.textSecondary;

    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.2),
                width: 4,
              ),
            ),
            child: ClipOval(
              child: _imageFile != null
                  ? Image.file(_imageFile!, fit: BoxFit.cover)
                  : (_avatarUrl != null
                        ? CachedNetworkImage(
                            imageUrl: _avatarUrl!,
                            fit: BoxFit.cover,
                            memCacheHeight: 240,
                            memCacheWidth: 240,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: primaryColor.withValues(alpha: 0.3),
                              ),
                            ),
                            errorWidget: (context, url, error) =>
                                Icon(Icons.person, size: 60, color: subtext),
                          )
                        : Icon(Icons.person, size: 60, color: subtext)),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Semantics(
              label: 'Change profile picture',
              button: true,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: EdgeInsets.all(tokens.spacingS),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: backgroundColor, width: 2),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 20,
                  ),
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
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: tokens.spacingXS,
            bottom: tokens.spacingS,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.all(tokens.spacingM),
          decoration: BoxDecoration(
            color: tokens.surfaceContainer,
            borderRadius: BorderRadius.circular(tokens.shapeL),
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

  Widget _buildPhoneField() {
    final tokens = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: tokens.inputBackground,
            borderRadius: BorderRadius.circular(tokens.shapeS),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: CountryCodeSelector(
            selectedCountry: _selectedCountryCode,
            onCountryChanged: (c) => setState(() => _selectedCountryCode = c),
          ),
        ),
        SizedBox(width: tokens.spacingS),
        Expanded(
          child: _buildTextField(
            controller: _phoneController,
            hint: 'Phone number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
        ),
      ],
    );
  }

  Widget _buildCitizenshipSelector() {
    final tokens = context.tokens;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: tokens.inputBackground,
        borderRadius: BorderRadius.circular(tokens.shapeS),
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
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: context.tokens.textSecondary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool enabled = true,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    final tokens = context.tokens;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Semantics(
      label: hint,
      textField: true,
      enabled: enabled,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: enabled ? tokens.textPrimary : tokens.disabled,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: tokens.textTertiary),
          prefixIcon: Icon(icon, color: primaryColor, size: 20),
          filled: true,
          fillColor: tokens.inputBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(tokens.shapeS),
            borderSide: BorderSide(color: tokens.inputBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(tokens.shapeS),
            borderSide: BorderSide(color: tokens.inputBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(tokens.shapeS),
            borderSide: BorderSide(color: tokens.inputFocusedBorder, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(tokens.shapeS),
            borderSide: BorderSide(
              color: tokens.disabled.withValues(alpha: 0.5),
            ),
          ),
          contentPadding: EdgeInsets.all(tokens.spacingM),
        ),
      ),
    );
  }

  Widget _buildClickableField({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final tokens = context.tokens;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Semantics(
      label: text,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.shapeS),
        child: Container(
          padding: EdgeInsets.all(tokens.spacingM),
          decoration: BoxDecoration(
            color: tokens.inputBackground,
            borderRadius: BorderRadius.circular(tokens.shapeS),
            border: Border.all(color: tokens.inputBorder),
          ),
          child: Row(
            children: [
              Icon(icon, color: primaryColor, size: 20),
              SizedBox(width: tokens.spacingS),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: tokens.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
