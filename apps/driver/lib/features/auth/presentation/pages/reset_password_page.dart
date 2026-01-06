import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/theme/m3_expressive_motion.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage>
    with TickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  bool _isSuccess = false;
  double _passwordStrength = 0.0;

  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: M3ExpressiveMotion.durationEmphasis,
    );

    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: M3ExpressiveMotion.decelerated,
    );

    _entranceController.forward();
    _verifySession();
  }

  void _verifySession() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          final newSession = Supabase.instance.client.auth.currentSession;
          if (newSession == null) {
            setState(() {
              _errorMessage =
                  'Session expired. Please request a new password reset link.';
            });
          }
        }
      });
    }
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

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter a new password');
      return;
    }

    if (password.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        setState(() {
          _errorMessage =
              'Session expired. Please request a new password reset link.';
          _isLoading = false;
        });
        return;
      }

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );

      setState(() {
        _isSuccess = true;
        _isLoading = false;
      });

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          context.go('/login');
        }
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _entranceController.dispose();
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
                          'Reset Password',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          'Create a new password',
                          style: textTheme.bodyMedium?.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacingM,
                    tokens.spacingS,
                    tokens.spacingM,
                    120,
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: tokens.spacingXL),
                      // Icon Header
                      Center(
                        child: Container(
                          padding: EdgeInsets.all(tokens.spacingL),
                          decoration: BoxDecoration(
                            color: tokens.surfaceContainer,
                            borderRadius: BorderRadius.circular(
                              tokens.shapeXL + tokens.spacingXS,
                            ),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Icon(
                            _isSuccess
                                ? Icons.verified_user_outlined
                                : Icons.lock_reset_outlined,
                            size: 64,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      SizedBox(height: tokens.spacingXL),

                      if (!_isSuccess) ...[
                        _buildLabel('New Password'),
                        SizedBox(height: tokens.spacingS),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          onChanged: _calculatePasswordStrength,
                          style: textTheme.bodyLarge?.copyWith(
                            color: tokens.textPrimary,
                          ),
                          decoration: _inputDecoration(
                            hint: 'Enter your new password',
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            onSuffixTap: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),

                        if (_passwordController.text.isNotEmpty) ...[
                          SizedBox(height: tokens.spacingM),
                          _buildPasswordStrengthIndicator(),
                        ],

                        SizedBox(height: tokens.spacingM + tokens.spacingXS),

                        _buildLabel('Confirm New Password'),
                        SizedBox(height: tokens.spacingS),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: textTheme.bodyLarge?.copyWith(
                            color: tokens.textPrimary,
                          ),
                          decoration: _inputDecoration(
                            hint: 'Re-enter your new password',
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            onSuffixTap: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                          ),
                        ),

                        if (_errorMessage != null) ...[
                          SizedBox(height: tokens.spacingM + tokens.spacingXS),
                          _buildErrorMessage(),
                        ],

                        SizedBox(height: tokens.spacingXL + tokens.spacingS),

                        // Back to login
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: Text(
                            'Cancel and return to login',
                            style: textTheme.bodyMedium?.copyWith(
                              color: tokens.textSecondary,
                            ),
                          ),
                        ),
                      ] else ...[
                        SizedBox(height: tokens.spacingXL),
                        Text(
                          'Password Updated!',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                        SizedBox(height: tokens.spacingM),
                        Text(
                          'Your password has been successfully updated. Redirecting to login...',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge?.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                        SizedBox(height: tokens.spacingXL + tokens.spacingS),
                        CircularProgressIndicator(
                          strokeCap: StrokeCap.round,
                          color: colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Bottom Button
      bottomNavigationBar: !_isSuccess
          ? Container(
              padding: EdgeInsets.all(tokens.spacingM),
              decoration: BoxDecoration(
                color: tokens.scaffoldAltBackground,
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: SafeArea(
                child: FilledButton(
                  onPressed: _isLoading ? null : _updatePassword,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
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
                      : Text(
                          'Update Password',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildLabel(String text) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: tokens.textPrimary,
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final strengthColor = _getStrengthColor(tokens);

    return Container(
      padding: EdgeInsets.all(tokens.spacingM),
      decoration: BoxDecoration(
        color: tokens.surfaceContainer,
        borderRadius: BorderRadius.circular(tokens.shapeL + tokens.spacingXS),
        border: Border.all(color: colorScheme.outlineVariant),
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
                color: strengthColor,
              ),
              SizedBox(width: tokens.spacingS),
              Text(
                'Password Strength: $_strengthText',
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: strengthColor,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacingS),
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.shapeXS),
            child: LinearProgressIndicator(
              value: _passwordStrength,
              backgroundColor: strengthColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Container(
      padding: EdgeInsets.all(tokens.spacingM),
      decoration: BoxDecoration(
        color: tokens.errorContainer,
        borderRadius: BorderRadius.circular(tokens.shapeL),
        border: Border.all(color: tokens.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: tokens.error, size: 20),
          SizedBox(width: tokens.spacingM),
          Expanded(
            child: Text(
              _errorMessage!,
              style: textTheme.bodySmall?.copyWith(
                color: tokens.error,
                height: 1.4,
              ),
            ),
          ),
        ],
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
