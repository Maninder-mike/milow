import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow_core/milow_core.dart';
import 'dart:io';
import '../data/user_repository_provider.dart';

class UserFormPage extends ConsumerStatefulWidget {
  const UserFormPage({super.key});

  @override
  ConsumerState<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends ConsumerState<UserFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _selectedRole = UserRole.driver;
  XFile? _profileImage;
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _pickImage() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'images',
      extensions: <String>['jpg', 'png', 'jpeg'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[typeGroup],
    );
    if (file != null) {
      setState(() {
        _profileImage = file;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_profileImage == null) {
      // Show warning or proceed without image? Proceed for now.
    }

    setState(() => _isLoading = true);

    try {
      await ref
          .read(userRepositoryProvider)
          .createUser(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            firstName: _nameController.text.trim().split(' ').first,
            lastName: _nameController.text.trim().split(' ').skip(1).join(' '),
            role: _selectedRole,
          );

      if (!mounted) return;
      setState(() => _isLoading = false);

      displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('Success'),
            content: Text('User ${_emailController.text} created successfully'),
            severity: InfoBarSeverity.success,
            action: IconButton(
              icon: const Icon(FluentIcons.dismiss_24_regular),
              onPressed: close,
            ),
          );
        },
      );

      // Delay before closing to show success
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('Error'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
            action: IconButton(
              icon: const Icon(FluentIcons.dismiss_24_regular),
              onPressed: close,
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: Text(
          'Add User',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      children: [
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF252526), // VS Code sidebar like background
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF333333)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF3C3C3C),
                            image: _profileImage != null
                                ? DecorationImage(
                                    image: FileImage(File(_profileImage!.path)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _profileImage == null
                              ? const Icon(
                                  FluentIcons.person_48_regular,
                                  size: 48,
                                  color: Color(0xFFCCCCCC),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF007ACC),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                FluentIcons.edit_24_regular,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                            onPressed: _pickImage,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildLabel('Full Name'),
                  TextFormBox(
                    controller: _nameController,
                    placeholder: 'Enter full name',
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Email'),
                  TextFormBox(
                    controller: _emailController,
                    placeholder: 'Enter email address',
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Phone Number'),
                  TextFormBox(
                    controller: _phoneController,
                    placeholder: 'Enter phone number',
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Role'),
                  ComboBox<UserRole>(
                    value: _selectedRole,
                    items: UserRole.values
                        .map(
                          (e) => ComboBoxItem(value: e, child: Text(e.label)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedRole = v);
                    },
                    isExpanded: true,
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Password'),
                  TextFormBox(
                    controller: _passwordController,
                    placeholder: 'Set initial password',
                    obscureText: _obscurePassword,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? FluentIcons.eye_24_regular
                            : FluentIcons.eye_off_24_regular,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (v) =>
                        v != null && v.length < 6 ? 'Min 6 chars' : null,
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const ProgressRing(strokeWidth: 2)
                          : const Text('Create User'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: const Color(0xFFCCCCCC),
        ),
      ),
    );
  }
}
