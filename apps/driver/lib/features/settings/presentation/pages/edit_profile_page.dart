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
import 'package:milow/core/utils/image_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:milow/core/mixins/form_restoration_mixin.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage>
    with RestorationMixin, FormRestorationMixin {
  final _formKey = GlobalKey<FormState>();

  @override
  String get restorationId => 'edit_profile_page';

  // Personal Info
  late final RestorableTextEditingController _nameController =
      RestorableTextEditingController();
  late final RestorableTextEditingController _emailController =
      RestorableTextEditingController();
  late final RestorableTextEditingController _phoneController =
      RestorableTextEditingController();
  // We should also restore the country code ideally, but keeping it simple for now or using RestorableString
  CountryCode _selectedCountryCode = countryCodes[0];

  // Address Info
  late final RestorableTextEditingController _streetController =
      RestorableTextEditingController();
  late final RestorableTextEditingController _cityController =
      RestorableTextEditingController();
  late final RestorableTextEditingController _stateController =
      RestorableTextEditingController();
  late final RestorableTextEditingController _zipController =
      RestorableTextEditingController();
  late final RestorableTextEditingController _countryController =
      RestorableTextEditingController();

  // Driver Info
  late final RestorableTextEditingController _licenseNumberController =
      RestorableTextEditingController();
  late final RestorableTextEditingController _licenseTypeController =
      RestorableTextEditingController();
  late final RestorableTextEditingController _fastIdController =
      RestorableTextEditingController();

  final RestorableDateTimeN _dob = RestorableDateTimeN(null);
  final RestorableDateTimeN _licenseExpiryDate = RestorableDateTimeN(null);

  // For non-primitive types not easily restorable without custom classes,
  // we might re-fetch or skip restoration.
  CountryCode? _citizenship;
  // Enum restoration could be done with RestorableInt or similar, skipping for simplicity in this demo
  DriverType _driverType = DriverType.companyDriver;

  bool _isLoading = false;
  File? _imageFile;
  String? _avatarUrl;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_nameController, 'name');
    registerForRestoration(_emailController, 'email');
    registerForRestoration(_phoneController, 'phone');

    registerForRestoration(_streetController, 'street');
    registerForRestoration(_cityController, 'city');
    registerForRestoration(_stateController, 'state');
    registerForRestoration(_zipController, 'zip');
    registerForRestoration(_countryController, 'country');

    registerForRestoration(_licenseNumberController, 'license_number');
    registerForRestoration(_licenseTypeController, 'license_type');
    registerForRestoration(_fastIdController, 'fast_id');

    registerForRestoration(_dob, 'dob');
    registerForRestoration(_licenseExpiryDate, 'license_expiry');
  }

  @override
  void initState() {
    super.initState();
    // No need to instantiate controllers, they are final fields now.
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    // If we have restored state (e.g. name is not empty), we might prioritize it?
    // But usually profile load should happen if we haven't edited?
    // Simpler strategy: If distinctively restored (not implemented here), skip.
    // For now, we load profile. If users had unsaved changes and app died, restoration
    // restores them. Then _loadProfile runs.
    // To prevent overwriting restored values with server values:
    // We can check if controllers are empty before populating.

    setState(() => _isLoading = true);
    final data = await ProfileRepository.getCachedFirst(refresh: true);
    if (data != null) {
      _populateFields(data);
    }
    setState(() => _isLoading = false);
  }

  void _populateFields(Map<String, dynamic> data) {
    // Only overwrite if empty? Or always overwrite?
    // If we strictly want to support "unsaved changes preservation", we should NOT overwrite if field is dirty.
    // But tracking "dirty" is hard.
    // Compromise: Overwrite only if controller is empty (fresh start behavior).
    // This allows restoration to win if it has content.

    if (_nameController.value.text.isEmpty) {
      _nameController.value.text = data['full_name'] ?? '';
    }
    if (_emailController.value.text.isEmpty) {
      _emailController.value.text = data['email'] ?? '';
    }

    // Address
    if (_streetController.value.text.isEmpty) {
      _streetController.value.text = data['street'] ?? '';
    }
    if (_cityController.value.text.isEmpty) {
      _cityController.value.text = data['city'] ?? '';
    }
    if (_stateController.value.text.isEmpty) {
      _stateController.value.text = data['state_province'] ?? '';
    }
    if (_zipController.value.text.isEmpty) {
      _zipController.value.text = data['postal_code'] ?? '';
    }
    if (_countryController.value.text.isEmpty) {
      _countryController.value.text = data['country'] ?? '';
    }

    // Driver Info
    if (_licenseNumberController.value.text.isEmpty) {
      _licenseNumberController.value.text = data['license_number'] ?? '';
    }
    if (_licenseTypeController.value.text.isEmpty) {
      _licenseTypeController.value.text = data['license_type'] ?? '';
    }
    if (_fastIdController.value.text.isEmpty) {
      _fastIdController.value.text = data['fast_id'] ?? '';
    }

    if (data['date_of_birth'] != null && _dob.value == null) {
      try {
        _dob.value = DateTime.parse(data['date_of_birth']);
      } catch (_) {}
    }

    if (data['license_expiry_date'] != null &&
        _licenseExpiryDate.value == null) {
      try {
        _licenseExpiryDate.value = DateTime.parse(data['license_expiry_date']);
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

    // Driver type
    final driverTypeStr = data['driver_type'] as String?;
    if (driverTypeStr != null) {
      final normalized = driverTypeStr.replaceAll('_', '').toLowerCase();
      _driverType = DriverType.values.firstWhere(
        (e) => e.name.toLowerCase() == normalized,
        orElse: () => DriverType.companyDriver,
      );
    }

    _avatarUrl = data['avatar_url'];

    // Phone parsing
    final phoneNumber = data['phone'] as String? ?? '';
    if (phoneNumber.isNotEmpty && _phoneController.value.text.isEmpty) {
      final country = parsePhoneNumber(phoneNumber);
      if (country != null) {
        _selectedCountryCode = country;
        _phoneController.value.text =
            extractPhoneNumber(phoneNumber, country) ?? '';
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
    // RestorableDateTimeN doesn't need explicit dispose if not holding resources,
    // but usually RestorableProperties are disposed by the Mixin if registered?
    // No, standard practice says dispose controllers.
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
          '${_selectedCountryCode.dialCode}${_phoneController.value.text.trim()}';

      final values = {
        'full_name': _nameController.value.text.trim(),
        'phone': fullPhone,
        'avatar_url': finalAvatarUrl,
        'street': _streetController.value.text.trim(),
        'city': _cityController.value.text.trim(),
        'state_province': _stateController.value.text.trim(),
        'postal_code': _zipController.value.text.trim(),
        'country': _countryController.value.text.trim(),
        'license_number': _licenseNumberController.value.text.trim(),
        'license_type': _licenseTypeController.value.text.trim(),
        'fast_id': _fastIdController.value.text.trim(),
        'date_of_birth': _dob.value?.toIso8601String(),
        'license_expiry_date': _licenseExpiryDate.value?.toIso8601String(),
        'citizenship': _citizenship?.code,
        'driver_type': _driverType.name,
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
      initialDate: _dob.value ?? DateTime(1990),
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
      setState(() => _dob.value = picked);
    }
  }

  void _selectLicenseExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _licenseExpiryDate.value ??
          DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
    );
    if (picked != null) {
      setState(() => _licenseExpiryDate.value = picked);
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
                    _buildSectionHeader('Personal Information', first: true),
                    _buildLabel('Full Name'),
                    _buildTextField(
                      controller: _nameController.value,
                      hint: 'Enter your name',
                      icon: Icons.person_outline,
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildLabel('Email Address'),
                    _buildTextField(
                      controller: _emailController.value,
                      hint: 'Email',
                      icon: Icons.email_outlined,
                      enabled: false,
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildLabel('Phone Number'),
                    _buildPhoneField(),

                    _buildSectionHeader('Address Information'),
                    _buildLabel('Street Address'),
                    _buildTextField(
                      controller: _streetController.value,
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
                              _buildTextField(
                                controller: _cityController.value,
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
                              _buildTextField(
                                controller: _stateController.value,
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
                              _buildTextField(
                                controller: _zipController.value,
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
                              _buildTextField(
                                controller: _countryController.value,
                                hint: 'Canada',
                                icon: Icons.public_outlined,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    _buildSectionHeader('Driver Documents'),
                    _buildLabel('License Number'),
                    _buildTextField(
                      controller: _licenseNumberController.value,
                      hint: 'A1234-56789-01234',
                      icon: Icons.badge_outlined,
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildLabel('License Expiry Date'),
                    _buildClickableField(
                      text: _licenseExpiryDate.value != null
                          ? DateFormat.yMMMd().format(_licenseExpiryDate.value!)
                          : 'Select Expiry Date',
                      icon: Icons.event_available_outlined,
                      onTap: _selectLicenseExpiry,
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildLabel('License Type (Class)'),
                    _buildTextField(
                      controller: _licenseTypeController.value,
                      hint: 'Class AZ',
                      icon: Icons.category_outlined,
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildLabel('FAST ID (Optional)'),
                    _buildTextField(
                      controller: _fastIdController.value,
                      hint: '12345678',
                      icon: Icons.security_outlined,
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildLabel('Date of Birth'),
                    _buildClickableField(
                      text: _dob.value != null
                          ? DateFormat.yMMMd().format(_dob.value!)
                          : 'Select Date',
                      icon: Icons.calendar_today_outlined,
                      onTap: _selectDate,
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildLabel('Citizenship'),
                    _buildCitizenshipSelector(),
                    SizedBox(height: tokens.spacingM),
                    _buildLabel('Driver Type'),
                    _buildDriverTypeSelector(),

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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: ClipOval(
              child: Container(
                color: tokens.surfaceContainerHigh,
                child: _imageFile != null
                    ? Image.file(_imageFile!, fit: BoxFit.cover)
                    : (_avatarUrl != null
                          ? CachedNetworkImage(
                              imageUrl: _avatarUrl!,
                              fit: BoxFit.cover,
                              memCacheHeight: ImageUtils.getCacheSize(
                                120,
                                context,
                              ),
                              memCacheWidth: ImageUtils.getCacheSize(
                                120,
                                context,
                              ),
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
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Semantics(
              label: 'Change profile picture',
              button: true,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: backgroundColor, width: 2.5),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool first = false}) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(
        top: first ? tokens.spacingM : tokens.spacingXL,
        bottom: tokens.spacingM,
        left: tokens.spacingXS,
      ),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    final tokens = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: tokens.inputBackground,
            borderRadius: BorderRadius.circular(tokens.shapeS),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.8),
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
            controller: _phoneController.value,
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
      height: 56,
      decoration: BoxDecoration(
        color: tokens.inputBackground,
        borderRadius: BorderRadius.circular(tokens.shapeS),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: CountryCodeSelector(
        selectedCountry: _citizenship ?? countryCodes[0],
        onCountryChanged: (c) => setState(() => _citizenship = c),
        showCountryName: true,
        showDialCode: false,
      ),
    );
  }

  Widget _buildDriverTypeSelector() {
    final tokens = context.tokens;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: tokens.spacingM),
      decoration: BoxDecoration(
        color: tokens.inputBackground,
        borderRadius: BorderRadius.circular(tokens.shapeS),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DriverType>(
          value: _driverType,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: primaryColor),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: tokens.textPrimary),
          dropdownColor: tokens.surfaceContainer,
          borderRadius: BorderRadius.circular(tokens.shapeM),
          items: DriverType.values.map((type) {
            return DropdownMenuItem<DriverType>(
              value: type,
              child: Row(
                children: [
                  Icon(_getDriverTypeIcon(type), size: 20, color: primaryColor),
                  SizedBox(width: tokens.spacingS),
                  Text(type.label),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _driverType = value);
            }
          },
        ),
      ),
    );
  }

  IconData _getDriverTypeIcon(DriverType type) {
    switch (type) {
      case DriverType.companyDriver:
        return Icons.business_outlined;
      case DriverType.ownerOperator:
        return Icons.person_outline;
      case DriverType.leaseOperator:
        return Icons.handshake_outlined;
    }
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: context.tokens.textSecondary.withValues(alpha: 0.8),
        ),
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
          fontWeight: FontWeight.w500,
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
            borderSide: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.8),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(tokens.shapeS),
            borderSide: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.8),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(tokens.shapeS),
            borderSide: BorderSide(color: primaryColor, width: 1.5),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(tokens.shapeS),
            borderSide: BorderSide(
              color: tokens.disabled.withValues(alpha: 0.2),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: tokens.inputBackground,
            borderRadius: BorderRadius.circular(tokens.shapeS),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.8),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: primaryColor, size: 20),
              SizedBox(width: tokens.spacingM),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: tokens.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
