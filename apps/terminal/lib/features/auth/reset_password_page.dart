import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'auth_theme.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late AuthTheme _theme;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  bool _isSuccess = false;
  double _passwordStrength = 0.0;

  @override
  void initState() {
    super.initState();
    _theme = AuthTheme.getRandom();
    _verifySession();
  }

  void _verifySession() {
    // Check if we have a valid session for password recovery
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      // No session - might still be processing the deep link
      // Wait a moment and check again
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

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validation
    setState(() => _errorMessage = null);

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

    if (_passwordStrength < 0.5) {
      setState(() => _errorMessage = 'Please create a stronger password');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );

      setState(() {
        _isSuccess = true;
        _isLoading = false;
      });

      // Wait a moment to show success, then navigate
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        // Sign out after password reset so user can login with new password
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          context.go('/login');
        }
      }
    } on AuthException catch (e) {
      String errorMsg = e.message;
      if (e.message.contains('session') || e.message.contains('token')) {
        errorMsg = 'Session expired. Please request a new password reset link.';
      }
      setState(() {
        _errorMessage = errorMsg;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color buttonTextCol(Color bg) {
      return bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    }

    return Container(
      decoration: BoxDecoration(gradient: _theme.gradient),
      child: Center(
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isSuccess
                    ? _buildSuccessView()
                    : _buildResetForm(buttonTextCol),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResetForm(Color Function(Color) buttonTextCol) {
    return Column(
      key: const ValueKey('reset_form'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(FluentIcons.lock, size: 64, color: _theme.primaryContentColor),
        const SizedBox(height: 24),
        Text(
          'Reset Password',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: _theme.primaryContentColor,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Create a new password for your account',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: _theme.secondaryContentColor,
            decoration: TextDecoration.none,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextBox(
          controller: _passwordController,
          placeholder: 'New Password',
          obscureText: _obscurePassword,
          onChanged: _calculatePasswordStrength,
          prefix: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Icon(FluentIcons.lock, color: _theme.primaryContentColor),
          ),
          suffix: IconButton(
            icon: Icon(
              _obscurePassword ? FluentIcons.red_eye : FluentIcons.hide,
              color: _theme.primaryContentColor,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          placeholderStyle: TextStyle(color: _theme.secondaryContentColor),
          style: TextStyle(color: _theme.primaryContentColor),
          decoration: WidgetStateProperty.all(
            BoxDecoration(
              color: _theme.inputFillColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        if (_passwordController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildPasswordStrengthIndicator(),
        ],
        const SizedBox(height: 16),
        TextBox(
          controller: _confirmPasswordController,
          placeholder: 'Confirm Password',
          obscureText: _obscureConfirmPassword,
          prefix: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Icon(FluentIcons.lock, color: _theme.primaryContentColor),
          ),
          suffix: IconButton(
            icon: Icon(
              _obscureConfirmPassword ? FluentIcons.red_eye : FluentIcons.hide,
              color: _theme.primaryContentColor,
            ),
            onPressed: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword,
            ),
          ),
          placeholderStyle: TextStyle(color: _theme.secondaryContentColor),
          style: TextStyle(color: _theme.primaryContentColor),
          decoration: WidgetStateProperty.all(
            BoxDecoration(
              color: _theme.inputFillColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _buildErrorMessage(),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: Button(
            onPressed: _isLoading ? null : _updatePassword,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                _theme.glassColor.withValues(alpha: 0.2),
              ),
              foregroundColor: WidgetStateProperty.all(
                _theme.primaryContentColor,
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(
                    color: _theme.glassBorderColor.withValues(
                      // More visible
                      alpha: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            child: _isLoading
                ? ProgressRing(activeColor: _theme.primaryContentColor)
                : Text(
                    'Update Password',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        HyperlinkButton(
          onPressed: () => context.go('/login'),
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.all(
              _theme.primaryContentColor.withValues(alpha: 0.9),
            ),
          ),
          child: Text(
            'Back to Login',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      key: const ValueKey('success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(FluentIcons.check_mark, size: 80, color: const Color(0xFF10B981)),
        const SizedBox(height: 24),
        Text(
          'Password Updated!',
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: _theme.primaryContentColor,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Redirecting to login...',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: _theme.secondaryContentColor,
            decoration: TextDecoration.none,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        const ProgressRing(),
      ],
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    Color strengthColor;
    String strengthText;

    if (_passwordStrength < 0.3) {
      strengthColor = Colors.red;
      strengthText = 'Weak';
    } else if (_passwordStrength < 0.6) {
      strengthColor = Colors.orange;
      strengthText = 'Fair';
    } else if (_passwordStrength < 0.8) {
      strengthColor = const Color(0xFF10B981);
      strengthText = 'Good';
    } else {
      strengthColor = const Color(0xFF059669);
      strengthText = 'Strong';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 4,
                  child: ProgressBar(
                    value: _passwordStrength * 100,
                    backgroundColor: _theme.secondaryContentColor.withValues(
                      alpha: 0.1,
                    ),
                    activeColor: strengthColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              strengthText,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: strengthColor,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.error, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.inter(
                color: Colors.red,
                fontSize: 13,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
