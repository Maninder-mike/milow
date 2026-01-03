import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/features/auth/presentation/pages/terms_page.dart';
import 'package:milow/features/auth/presentation/pages/privacy_policy_page.dart';
import 'package:milow/core/constants/design_tokens.dart';

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

  Color _getStrengthColor(DesignTokens tokens) {
    if (_passwordStrength < 0.3) return tokens.error;
    if (_passwordStrength < 0.6) return tokens.warning;
    return tokens.success;
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
        data: {
          'full_name': _nameController.text.trim(),
          'role': 'driver', // Mobile app users are drivers by default
        },
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
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    String? verifyError;
    bool isSending = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              tokens.shapeL + tokens.spacingXS,
            ),
          ),
          backgroundColor: tokens.surfaceContainer,
          title: Text(
            'Resend Verification',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Enter your email address and we'll resend the verification link.",
                style: textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
              SizedBox(height: tokens.spacingM + tokens.spacingXS),
              TextField(
                controller: verifyEmailController,
                keyboardType: TextInputType.emailAddress,
                style: textTheme.bodyLarge,
                decoration: _inputDecoration(
                  hint: 'Email address',
                  prefixIcon: Icons.alternate_email,
                ),
              ),
              if (verifyError != null) ...[
                SizedBox(height: tokens.spacingM),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacingM,
                    vertical: tokens.spacingS,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.errorContainer,
                    borderRadius: BorderRadius.circular(tokens.shapeM),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: tokens.error, size: 16),
                      SizedBox(width: tokens.spacingS),
                      Expanded(
                        child: Text(
                          verifyError!,
                          style: textTheme.bodySmall?.copyWith(
                            color: tokens.error,
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
                style: textTheme.labelLarge?.copyWith(
                  color: tokens.textSecondary,
                ),
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
                              ),
                              backgroundColor: tokens.success,
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
                  borderRadius: BorderRadius.circular(tokens.shapeM),
                ),
              ),
              child: isSending
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.0,
                        strokeCap: StrokeCap.round,
                        color: colorScheme.onPrimary,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.scaffoldAltBackground,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(tokens.spacingM),
                child: Row(
                  children: [
                    _buildNavButton(
                      icon: Icons.arrow_back_ios_new,
                      onTap: () => context.go('/login'),
                    ),
                    SizedBox(width: tokens.spacingM),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Account',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          'Join Milow today',
                          style: textTheme.bodyMedium?.copyWith(
                            color: tokens.textSecondary,
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
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacingM,
                    tokens.spacingS,
                    tokens.spacingM,
                    120,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Name Field
                      _buildLabel('Full Name'),
                      SizedBox(height: tokens.spacingS),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: textTheme.bodyLarge?.copyWith(
                          color: tokens.textPrimary,
                        ),
                        decoration: _inputDecoration(
                          hint: 'John Doe',
                          prefixIcon: Icons.person_outline,
                        ),
                      ),

                      SizedBox(height: tokens.spacingM + tokens.spacingXS),

                      // Email Field
                      _buildLabel('Email Address'),
                      SizedBox(height: tokens.spacingS),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: textTheme.bodyLarge?.copyWith(
                          color: tokens.textPrimary,
                        ),
                        decoration: _inputDecoration(
                          hint: 'name@email.com',
                          prefixIcon: Icons.alternate_email,
                        ),
                      ),

                      SizedBox(height: tokens.spacingM + tokens.spacingXS),

                      // Password Field
                      _buildLabel('Password'),
                      SizedBox(height: tokens.spacingS),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onChanged: _calculatePasswordStrength,
                        style: textTheme.bodyLarge?.copyWith(
                          color: tokens.textPrimary,
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
                        SizedBox(height: tokens.spacingM),
                        Container(
                          padding: EdgeInsets.all(tokens.spacingM),
                          decoration: BoxDecoration(
                            color: tokens.surfaceContainer,
                            borderRadius: BorderRadius.circular(
                              tokens.shapeL + tokens.spacingXS,
                            ),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
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
                                    color: _getStrengthColor(tokens),
                                  ),
                                  SizedBox(width: tokens.spacingS),
                                  Text(
                                    'Password Strength: $_strengthText',
                                    style: textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: _getStrengthColor(tokens),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: tokens.spacingS),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  tokens.shapeXS,
                                ),
                                child: LinearProgressIndicator(
                                  value: _passwordStrength,
                                  backgroundColor: _getStrengthColor(
                                    tokens,
                                  ).withValues(alpha: 0.2),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _getStrengthColor(tokens),
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: tokens.spacingM + tokens.spacingXS),

                      // Confirm Password
                      _buildLabel('Confirm Password'),
                      SizedBox(height: tokens.spacingS),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: textTheme.bodyLarge?.copyWith(
                          color: tokens.textPrimary,
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

                      SizedBox(height: tokens.spacingL),

                      // Terms and Conditions
                      GestureDetector(
                        onTap: () {
                          setState(() => _agreedToTerms = !_agreedToTerms);
                        },
                        child: Container(
                          padding: EdgeInsets.all(tokens.spacingM),
                          decoration: BoxDecoration(
                            color: tokens.surfaceContainer,
                            borderRadius: BorderRadius.circular(
                              tokens.shapeL + tokens.spacingXS,
                            ),
                            border: Border.all(
                              color: _agreedToTerms
                                  ? colorScheme.primary
                                  : colorScheme.outlineVariant,
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
                                      ? colorScheme.primary
                                      : tokens.inputBackground,
                                  borderRadius: BorderRadius.circular(6),
                                  border: _agreedToTerms
                                      ? null
                                      : Border.all(color: tokens.textTertiary),
                                ),
                                child: _agreedToTerms
                                    ? Icon(
                                        Icons.check,
                                        size: 16,
                                        color: colorScheme.onPrimary,
                                      )
                                    : null,
                              ),
                              SizedBox(width: tokens.spacingM),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: textTheme.bodySmall?.copyWith(
                                      color: tokens.textSecondary,
                                      height: 1.4,
                                    ),
                                    children: [
                                      const TextSpan(text: 'I agree to the '),
                                      TextSpan(
                                        text: 'Terms & Conditions',
                                        style: TextStyle(
                                          color: colorScheme.primary,
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
                                          color: colorScheme.primary,
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
                        SizedBox(height: tokens.spacingS),
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: tokens.warning,
                            ),
                            SizedBox(width: tokens.spacingS - 2),
                            Expanded(
                              child: Text(
                                'Required to create account',
                                style: textTheme.labelSmall?.copyWith(
                                  color: tokens.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      SizedBox(height: tokens.spacingL),

                      // Resend Verification Link
                      Center(
                        child: TextButton(
                          onPressed: _showResendVerificationDialog,
                          child: Text(
                            'Already registered? Resend verification email',
                            style: textTheme.bodySmall?.copyWith(
                              color: tokens.textSecondary,
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
        padding: EdgeInsets.all(tokens.spacingM),
        decoration: BoxDecoration(
          color: tokens.scaffoldAltBackground,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
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
                    side: BorderSide(color: colorScheme.outlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.shapeL),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: tokens.spacingM),
              // Sign Up Button
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: (_isLoading || !_agreedToTerms) ? null : _signUp,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.shapeL),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.0,
                            strokeCap: StrokeCap.round,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Create Account',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                            SizedBox(width: tokens.spacingS),
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
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: tokens.surfaceContainer,
        borderRadius: BorderRadius.circular(tokens.shapeM),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: colorScheme.onSurface),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildLabel(String text) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Text(
      text,
      style: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: tokens.textPrimary,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return InputDecoration(
      hintText: hint,
      hintStyle: textTheme.bodyMedium?.copyWith(color: tokens.textTertiary),
      prefixIcon: Icon(prefixIcon, color: colorScheme.primary, size: 20),
      suffixIcon: suffixIcon != null
          ? IconButton(
              icon: Icon(suffixIcon, color: colorScheme.primary, size: 20),
              onPressed: onSuffixTap,
            )
          : null,
      filled: true,
      fillColor: tokens.inputBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.shapeL),
        borderSide: BorderSide(color: tokens.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.shapeL),
        borderSide: BorderSide(color: tokens.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.shapeL),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: tokens.spacingM,
        vertical: tokens.spacingM,
      ),
    );
  }
}
