import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

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
  late final AnimationController _shakeController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _entranceController.forward();
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

  void _triggerShake() {
    _shakeController.reset();
    _shakeController.forward();
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // Validation
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter a new password');
      _triggerShake();
      return;
    }

    if (password.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters');
      _triggerShake();
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match');
      _triggerShake();
      return;
    }

    if (_passwordStrength < 0.5) {
      setState(() => _errorMessage = 'Please create a stronger password');
      _triggerShake();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Verify we have a valid session before attempting update
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        setState(() {
          _errorMessage =
              'Session expired. Please request a new password reset link.';
          _isLoading = false;
        });
        _triggerShake();
        return;
      }

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
      _triggerShake();
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });
      _triggerShake();
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _entranceController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _buildDecorations(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      _buildIcon(),
                      const SizedBox(height: 24),
                      Text(
                        _isSuccess ? 'Password Updated!' : 'Reset Password',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF101828),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isSuccess
                            ? 'Your password has been successfully updated. Redirecting to login...'
                            : 'Create a new password for your account',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: const Color(0xFF667085),
                        ),
                      ),
                      const SizedBox(height: 40),
                      if (!_isSuccess) ...[
                        AnimatedBuilder(
                          animation: _shakeAnim,
                          builder: (context, child) {
                            final shake = _shakeAnim.value * 10;
                            return Transform.translate(
                              offset: Offset(
                                shake *
                                    ((_shakeAnim.value * 10).toInt().isEven
                                        ? 1
                                        : -1),
                                0,
                              ),
                              child: child,
                            );
                          },
                          child: Column(
                            children: [
                              _buildPasswordField(),
                              if (_passwordController.text.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _buildPasswordStrengthIndicator(),
                              ],
                              const SizedBox(height: 20),
                              _buildConfirmPasswordField(),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 20),
                                _buildErrorMessage(),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildUpdateButton(),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: Text(
                            'Back to Login',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: const Color(0xFF8B5CF6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ] else ...[
                        _buildSuccessAnimation(),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecorations() {
    return Stack(
      children: [
        Positioned(
          top: -80,
          left: -80,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                width: 40,
              ),
            ),
          ),
        ),
        Positioned(
          top: -40,
          right: -60,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                width: 30,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          right: -50,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                width: 50,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIcon() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isSuccess
                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                    : [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (_isSuccess
                              ? const Color(0xFF10B981)
                              : const Color(0xFF8B5CF6))
                          .withValues(alpha: 0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              _isSuccess ? Icons.check_rounded : Icons.lock_reset_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      onChanged: _calculatePasswordStrength,
      style: GoogleFonts.poppins(fontSize: 15),
      decoration: InputDecoration(
        hintText: 'New password',
        hintStyle: GoogleFonts.poppins(
          color: const Color(0xFFD1D5DB),
          fontSize: 15,
        ),
        prefixIcon: const Icon(
          Icons.lock_outline,
          color: Color(0xFFD1D5DB),
          size: 22,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: const Color(0xFFD1D5DB),
            size: 22,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF8B5CF6), width: 2),
        ),
      ),
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
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _passwordStrength),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, child) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: value,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                      minHeight: 6,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Text(
              strengthText,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: strengthColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Use 8+ characters with uppercase, lowercase, numbers & symbols',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      style: GoogleFonts.poppins(fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Confirm new password',
        hintStyle: GoogleFonts.poppins(
          color: const Color(0xFFD1D5DB),
          fontSize: 15,
        ),
        prefixIcon: const Icon(
          Icons.lock_outline,
          color: Color(0xFFD1D5DB),
          size: 22,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
            color: const Color(0xFFD1D5DB),
            size: 22,
          ),
          onPressed: () => setState(
            () => _obscureConfirmPassword = !_obscureConfirmPassword,
          ),
        ),
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF8B5CF6), width: 2),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.poppins(
                color: Colors.red.shade700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _updatePassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B5CF6),
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          disabledBackgroundColor: const Color(
            0xFF8B5CF6,
          ).withValues(alpha: 0.6),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                'UPDATE PASSWORD',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    );
  }

  Widget _buildSuccessAnimation() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(height: 16),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  strokeWidth: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
