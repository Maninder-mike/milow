import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/features/auth/presentation/pages/terms_page.dart';
import 'package:milow/features/auth/presentation/pages/privacy_policy_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  double _passwordStrength = 0.0;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  void _calculatePasswordStrength(String password) {
    if (password.isEmpty) {
      setState(() => _passwordStrength = 0.0);
      return;
    }
    double strength = 0.0;
    if (password.length >= 8) strength += 0.25;
    if (password.length >= 12) strength += 0.25;
    if (RegExp(r'[a-z]').hasMatch(password)) strength += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.15;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.2;
    setState(() => _passwordStrength = strength.clamp(0.0, 1.0));
  }

  Color get _strengthColor {
    if (_passwordStrength < 0.3) return const Color(0xFFEF4444);
    if (_passwordStrength < 0.6) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  String get _strengthText {
    if (_passwordStrength < 0.3) return 'Weak';
    if (_passwordStrength < 0.6) return 'Fair';
    return 'Strong';
  }

  Future<void> _signUp() async {
    // Validate fields
    if (_nameController.text.trim().isEmpty) {
      AppDialogs.showWarning(context, 'Please enter your name');
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      AppDialogs.showWarning(context, 'Please enter your email');
      return;
    }
    if (!RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    ).hasMatch(_emailController.text.trim())) {
      AppDialogs.showWarning(context, 'Please enter a valid email');
      return;
    }
    if (_passwordController.text.isEmpty) {
      AppDialogs.showWarning(context, 'Please enter a password');
      return;
    }
    if (_passwordController.text.length < 6) {
      AppDialogs.showWarning(context, 'Password must be at least 6 characters');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      AppDialogs.showError(context, 'Passwords do not match');
      return;
    }
    if (!_agreedToTerms) {
      AppDialogs.showWarning(
        context,
        'Please agree to Terms & Conditions to continue',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        emailRedirectTo: 'milow://login',
        data: {'full_name': _nameController.text.trim()},
      );
      if (mounted) {
        AppDialogs.showSuccess(
          context,
          'Sign up successful! Please check your email to verify.',
        );
        context.go('/login');
      }
    } on AuthException catch (error) {
      if (mounted) {
        AppDialogs.showError(context, error.message);
      }
    } catch (error) {
      if (mounted) {
        AppDialogs.showError(context, 'Unexpected error occurred');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showResendVerificationDialog() async {
    final verifyEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final messenger = ScaffoldMessenger.of(context);
    String? verifyError;
    bool isSending = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Theme.of(context).cardColor,
          title: Text(
            'Resend Verification',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Enter your email address and we'll resend the verification link.",
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: verifyEmailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.outfit(fontSize: 16),
                decoration: _inputDecoration(
                  hint: 'Email address',
                  prefixIcon: Icons.alternate_email,
                ),
              ),
              if (verifyError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          verifyError!,
                          style: GoogleFonts.outfit(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(color: const Color(0xFF667085)),
              ),
            ),
            FilledButton(
              onPressed: isSending
                  ? null
                  : () async {
                      final email = verifyEmailController.text.trim();
                      if (email.isEmpty ||
                          !RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(email)) {
                        setDialogState(
                          () => verifyError = 'Please enter a valid email',
                        );
                        return;
                      }
                      setDialogState(() {
                        isSending = true;
                        verifyError = null;
                      });
                      try {
                        await Supabase.instance.client.auth.resend(
                          type: OtpType.signup,
                          email: email,
                          emailRedirectTo: 'milow://login',
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Verification email sent to $email',
                                style: GoogleFonts.outfit(),
                              ),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        }
                      } catch (e) {
                        final message = e is AuthException
                            ? e.message
                            : e.toString();
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            isSending = false;
                            verifyError = message.isNotEmpty
                                ? message
                                : 'Failed to send verification email';
                          });
                        }
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => isSending = false);
                        }
                      }
                    },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.0,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Resend'),
            ),
          ],
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      verifyEmailController.dispose();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0A0A0A)
        : const Color(0xFFF9FAFB);
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildNavButton(
                      icon: Icons.arrow_back_ios_new,
                      onTap: () => context.go('/login'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Account',
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Join Milow today',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: const Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Name Field
                      _buildLabel('Full Name'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: GoogleFonts.outfit(
                          color: textColor,
                          fontSize: 16,
                        ),
                        decoration: _inputDecoration(
                          hint: 'John Doe',
                          prefixIcon: Icons.person_outline,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Email Field
                      _buildLabel('Email Address'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.outfit(
                          color: textColor,
                          fontSize: 16,
                        ),
                        decoration: _inputDecoration(
                          hint: 'name@email.com',
                          prefixIcon: Icons.alternate_email,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Password Field
                      _buildLabel('Password'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onChanged: _calculatePasswordStrength,
                        style: GoogleFonts.outfit(
                          color: textColor,
                          fontSize: 16,
                        ),
                        decoration: _inputDecoration(
                          hint: 'Create a strong password',
                          prefixIcon: Icons.lock_outline,
                          suffixIcon: _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          onSuffixTap: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                      ),

                      // Password Strength Indicator
                      if (_passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _passwordStrength < 0.6
                                        ? Icons.shield_outlined
                                        : Icons.verified_user_outlined,
                                    size: 16,
                                    color: _strengthColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Password Strength: $_strengthText',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _strengthColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _passwordStrength,
                                  backgroundColor: _strengthColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _strengthColor,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Confirm Password
                      _buildLabel('Confirm Password'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: GoogleFonts.outfit(
                          color: textColor,
                          fontSize: 16,
                        ),
                        decoration: _inputDecoration(
                          hint: 'Re-enter your password',
                          prefixIcon: Icons.lock_outline,
                          suffixIcon: _obscureConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          onSuffixTap: () {
                            setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Terms and Conditions
                      GestureDetector(
                        onTap: () {
                          setState(() => _agreedToTerms = !_agreedToTerms);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _agreedToTerms
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                              width: _agreedToTerms ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: _agreedToTerms
                                      ? Theme.of(context).colorScheme.primary
                                      : isDark
                                      ? const Color(0xFF2A2A2A)
                                      : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(6),
                                  border: _agreedToTerms
                                      ? null
                                      : Border.all(
                                          color: const Color(0xFF98A2B3),
                                        ),
                                ),
                                child: _agreedToTerms
                                    ? const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: const Color(0xFF667085),
                                      height: 1.4,
                                    ),
                                    children: [
                                      const TextSpan(text: 'I agree to the '),
                                      TextSpan(
                                        text: 'Terms & Conditions',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const TermsPage(),
                                              ),
                                            );
                                          },
                                      ),
                                      const TextSpan(text: ' and '),
                                      TextSpan(
                                        text: 'Privacy Policy',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const PrivacyPolicyPage(),
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
                        ),
                      ),

                      if (!_agreedToTerms) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: Colors.orange.shade400,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Required to create account',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.orange.shade400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Resend Verification Link
                      Center(
                        child: TextButton(
                          onPressed: _showResendVerificationDialog,
                          child: Text(
                            'Already registered? Resend verification email',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: const Color(0xFF667085),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Bottom Sign Up Button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Cancel Button
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go('/login'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 56),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Sign Up Button
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: (_isLoading || !_agreedToTerms) ? null : _signUp,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.0,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Create Account',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 20),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).textTheme.bodyLarge?.color,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(
        color: const Color(0xFF98A2B3),
        fontSize: 14,
      ),
      prefixIcon: Icon(prefixIcon, color: primaryColor, size: 20),
      suffixIcon: suffixIcon != null
          ? IconButton(
              icon: Icon(suffixIcon, color: primaryColor, size: 20),
              onPressed: onSuffixTap,
            )
          : null,
      filled: true,
      fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
