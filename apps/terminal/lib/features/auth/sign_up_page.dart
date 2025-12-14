import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

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
        emailRedirectTo: 'milow-admin://login',
        data: {'full_name': _nameController.text.trim()},
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
                icon: const Icon(FluentIcons.clear),
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
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
        ),
      ),
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
                  color: Colors.white.withValues(
                    alpha: 0.1,
                  ), // Fluent Colors.white
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        FluentIcons.add_friend,
                        size: 64,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Create Account',
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Join the admin team',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.7),
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Name Field
                      _buildTextField(
                        controller: _nameController,
                        hint: 'Full Name',
                        icon: FluentIcons.contact,
                        validator: (v) =>
                            v?.isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Email Field
                      _buildTextField(
                        controller: _emailController,
                        hint: 'Email',
                        icon: FluentIcons.mail,
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
                        icon: FluentIcons.lock,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? FluentIcons.red_eye
                                : FluentIcons.hide,
                            color: Colors.white,
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
                        icon: FluentIcons.lock,
                        obscureText: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? FluentIcons.red_eye
                                : FluentIcons.hide,
                            color: Colors.white,
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
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.7),
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
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                children: [
                                  const TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Terms',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => context.push('/terms'),
                                  ),
                                  const TextSpan(text: ' & '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => context.push('/privacy'),
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
                        height: 40,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _signUp,
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(
                              Colors.white,
                            ),
                            foregroundColor: WidgetStateProperty.all(
                              const Color(0xFF6C5CE7),
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
                              color: Colors.white.withValues(alpha: 0.9),
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
                                color: Colors.white,
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
      style: const TextStyle(color: Colors.white),
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      prefix: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Icon(icon, color: Colors.white),
      ),
      suffix: suffixIcon,
      placeholder: hint,
      placeholderStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
      decoration: WidgetStateProperty.all(
        BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
