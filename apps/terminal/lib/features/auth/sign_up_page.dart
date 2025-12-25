import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_theme.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  UserRole _selectedRole = UserRole.dispatcher; // Default role
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _flyoutController = FlyoutController();

  late AuthTheme _theme;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    _theme = AuthTheme.getRandom();
  }

  @override
  void dispose() {
    _flyoutController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ... (build methods)

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      _showError('Please accept the Terms & Conditions');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        emailRedirectTo: 'milow-terminal://login',
        data: {
          'full_name': _nameController.text.trim(),
          'role': _selectedRole.name,
        },
      );

      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: const Text('Success'),
              content: const Text(
                'Account created! Please check your email to verify your account.',
              ),
              severity: InfoBarSeverity.success,
              action: IconButton(
                icon: const Icon(FluentIcons.dismiss_24_regular),
                onPressed: close,
              ),
            );
          },
        );
        context.go('/login');
      }
    } on AuthException catch (error) {
      if (mounted) _showError(error.message);
    } catch (error) {
      if (mounted) _showError('Unexpected error occurred');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    displayInfoBar(
      context,
      builder: (context, close) {
        return InfoBar(
          title: const Text('Error'),
          content: Text(message),
          severity: InfoBarSeverity.error,
          action: IconButton(
            icon: const Icon(FluentIcons.dismiss_24_regular),
            onPressed: close,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Color buttonTextCol(Color bg) {
      return bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    }

    return Container(
      decoration: BoxDecoration(gradient: _theme.gradient),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: _theme.glassColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _theme.glassBorderColor),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        FluentIcons.person_add_24_regular,
                        size: 64,
                        color: _theme.primaryContentColor,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Create Account',
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _theme.primaryContentColor,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Join the admin team',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: _theme.secondaryContentColor,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Role Selection
                      SizedBox(
                        width: double.infinity,
                        child: FlyoutTarget(
                          controller: _flyoutController,
                          child: Button(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all(
                                _theme.inputFillColor,
                              ),
                              shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  side: BorderSide.none,
                                ),
                              ),
                              padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                            onPressed: _showRolePicker,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatRole(_selectedRole),
                                  style: TextStyle(
                                    color: _theme.primaryContentColor,
                                    fontSize: 14,
                                  ),
                                ),
                                Icon(
                                  FluentIcons.chevron_down_24_regular,
                                  size: 10,
                                  color: _theme.primaryContentColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Name Field
                      _buildTextField(
                        controller: _nameController,
                        hint: 'Full Name',
                        icon: FluentIcons.person_24_regular,
                        validator: (v) =>
                            v?.isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Email Field
                      _buildTextField(
                        controller: _emailController,
                        hint: 'Email',
                        icon: FluentIcons.mail_24_regular,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (!v.contains('@')) return 'Invalid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      _buildTextField(
                        controller: _passwordController,
                        hint: 'Password',
                        icon: FluentIcons.lock_closed_24_regular,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? FluentIcons.eye_24_regular
                                : FluentIcons.eye_off_24_regular,
                            color: _theme.primaryContentColor,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 6) return 'Min 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password Field
                      _buildTextField(
                        controller: _confirmPasswordController,
                        hint: 'Confirm Password',
                        icon: FluentIcons.lock_closed_24_regular,
                        obscureText: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? FluentIcons.eye_24_regular
                                : FluentIcons.eye_off_24_regular,
                            color: _theme.primaryContentColor,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),
                        validator: (v) {
                          if (v != _passwordController.text) {
                            return 'Passwords match not';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Terms Checkbox
                      Row(
                        children: [
                          Checkbox(
                            checked: _acceptedTerms,
                            onChanged: (v) {
                              setState(() => _acceptedTerms = v ?? false);
                            },
                            style: CheckboxThemeData(
                              checkedDecoration: WidgetStateProperty.all(
                                BoxDecoration(
                                  color: const Color(0xFF6C5CE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              uncheckedDecoration: WidgetStateProperty.all(
                                BoxDecoration(
                                  color: _theme.inputFillColor,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: _theme.glassBorderColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: _theme.secondaryContentColor,
                                ),
                                children: [
                                  const TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Terms',
                                    style: TextStyle(
                                      color: _theme.primaryContentColor,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        launchUrl(
                                          Uri.parse(
                                            'https://www.maninder.co.in/milow/TermsandConditions',
                                          ),
                                        );
                                      },
                                  ),
                                  const TextSpan(text: ' & '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                      color: _theme.primaryContentColor,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        launchUrl(
                                          Uri.parse(
                                            'https://www.maninder.co.in/milow/privacypolicy',
                                          ),
                                        );
                                      },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Sign Up Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _signUp,
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(
                              _theme.primaryContentColor,
                            ),
                            foregroundColor: WidgetStateProperty.all(
                              buttonTextCol(_theme.primaryContentColor),
                            ),
                          ),
                          child: _isLoading
                              ? const ProgressRing(
                                  activeColor: Color(0xFF6C5CE7),
                                )
                              : Text(
                                  'Create Account',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Login Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: GoogleFonts.inter(
                              color: _theme.secondaryContentColor,
                              fontSize: 14,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          HyperlinkButton(
                            onPressed: () => context.go('/login'),
                            child: Text(
                              'Login',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: _theme.primaryContentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormBox(
      controller: controller,
      style: TextStyle(color: _theme.primaryContentColor),
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      prefix: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Icon(icon, color: _theme.primaryContentColor),
      ),
      suffix: suffixIcon,
      placeholder: hint,
      placeholderStyle: TextStyle(color: _theme.secondaryContentColor),
      decoration: WidgetStateProperty.all(
        BoxDecoration(
          color: _theme.inputFillColor,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  void _showRolePicker() {
    _flyoutController.showFlyout(
      builder: (context) {
        return FlyoutContent(
          padding: EdgeInsets.zero,
          color: Colors.transparent,
          child: Container(
            width: 320, // Matches form width (400 - 40*2 padding)
            decoration: BoxDecoration(
              color: _theme.glassColor, // Background similar to other inputs
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _theme.glassBorderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: UserRole.values
                  .where(
                    (role) =>
                        role != UserRole.driver && role != UserRole.pending,
                  )
                  .map((role) {
                    final isSelected = _selectedRole == role;
                    return HoverButton(
                      onPressed: () {
                        setState(() => _selectedRole = role);
                        Navigator.of(context).pop();
                      },
                      builder: (context, states) {
                        final isHovering = states.isHovered;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          color: isSelected
                              ? _theme.primaryContentColor.withValues(
                                  alpha: 0.1,
                                )
                              : isHovering
                              ? _theme.secondaryContentColor.withValues(
                                  alpha: 0.1,
                                )
                              : Colors.transparent,
                          child: Text(
                            _formatRole(role),
                            style: TextStyle(
                              color: _theme.primaryContentColor,
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    );
                  })
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  String _formatRole(UserRole role) {
    return role.name
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}')
        .replaceFirstMapped(
          RegExp(r'^[a-z]'),
          (match) => match.group(0)!.toUpperCase(),
        );
  }
}
