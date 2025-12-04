import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/services/local_auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final LocalAuthService _authService = LocalAuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  String? _loginError;
  bool _emailValid = false;

  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  late final Animation<double> _fadeAnim = CurvedAnimation(
    parent: _entranceController,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
    _entranceController.forward();
  }

  void _checkExistingSession() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && mounted) {
      context.go('/dashboard');
    }
  }

  void _validateEmail(String value) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    setState(() {
      if (value.isEmpty) {
        _emailError = null;
        _emailValid = false;
      } else if (!emailRegex.hasMatch(value)) {
        _emailError = 'Please enter a valid email address';
        _emailValid = false;
      } else {
        _emailError = null;
        _emailValid = true;
      }
    });
  }

  bool _isLockedOut() {
    if (_lockoutUntil == null) return false;
    if (DateTime.now().isBefore(_lockoutUntil!)) return true;
    setState(() => _lockoutUntil = null);
    return false;
  }

  Future<void> _signIn() async {
    if (_isLockedOut()) {
      final remainingSeconds = _lockoutUntil!
          .difference(DateTime.now())
          .inSeconds;
      setState(
        () => _loginError =
            'Too many failed attempts. Please wait $remainingSeconds seconds.',
      );
      return;
    }

    if (_emailError != null) return;
    if (_passwordController.text.length < 8) {
      setState(() => _passwordError = 'Password must be at least 8 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _loginError = null;
      _passwordError = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = Supabase.instance.client.auth.currentUser;
      final emailConfirmedAt = user?.emailConfirmedAt;
      if (emailConfirmedAt != null) {
        try {
          final confirmedTime = DateTime.parse(emailConfirmedAt).toUtc();
          final now = DateTime.now().toUtc();
          if (now.difference(confirmedTime).inMinutes <= 10) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Email verified successfully. Welcome!'),
                ),
              );
            }
          }
        } catch (_) {}
      }
      await _authService.storeUserEmail(_emailController.text.trim());
      setState(() => _failedAttempts = 0);
      if (mounted) context.go('/dashboard');
    } on AuthException catch (error) {
      setState(() {
        _failedAttempts++;
        if (_failedAttempts >= 5) {
          _lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
          _loginError = 'Too many failed attempts. Please wait 30 seconds.';
        } else {
          _loginError = error.message;
        }
      });
    } catch (_) {
      setState(() => _loginError = 'An unexpected error occurred');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    String? resetError;
    bool isResetting = false;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Reset Password',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your email address and we\'ll send you a link to reset your password.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email address',
                  prefixIcon: const Icon(
                    Icons.alternate_email,
                    color: Color(0xFF9CA3AF),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                ),
              ),
              if (resetError != null) ...[
                const SizedBox(height: 12),
                Text(
                  resetError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: const Color(0xFF667085)),
              ),
            ),
            ElevatedButton(
              onPressed: isResetting
                  ? null
                  : () async {
                      final email = resetEmailController.text.trim();
                      if (email.isEmpty ||
                          !RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(email)) {
                        setDialogState(
                          () => resetError = 'Please enter a valid email',
                        );
                        return;
                      }
                      setDialogState(() {
                        isResetting = true;
                        resetError = null;
                      });
                      try {
                        await Supabase.instance.client.auth
                            .resetPasswordForEmail(
                              email,
                              redirectTo: 'milow://reset-password',
                            );
                        Navigator.pop(dialogContext);
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text('Password reset link sent to $email'),
                            backgroundColor: const Color(0xFF8B5CF6),
                          ),
                        );
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            isResetting = false;
                            resetError = 'Failed to send reset email';
                          });
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isResetting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send Link'),
            ),
          ],
        ),
      ),
    );
    resetEmailController.dispose();
  }

  Future<void> _showResendVerificationDialog() async {
    final verifyEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    String? verifyError;
    bool isSending = false;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Resend Verification',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your email address and we\'ll resend the verification link.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: verifyEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email address',
                  prefixIcon: const Icon(
                    Icons.alternate_email,
                    color: Color(0xFF9CA3AF),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                ),
              ),
              if (verifyError != null) ...[
                const SizedBox(height: 12),
                Text(
                  verifyError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: const Color(0xFF667085)),
              ),
            ),
            ElevatedButton(
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
                          emailRedirectTo: 'milow://email-verified',
                        );
                        Navigator.pop(dialogContext);
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text('Verification email sent to $email'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            isSending = false;
                            verifyError = 'Failed to send verification email';
                          });
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Resend'),
            ),
          ],
        ),
      ),
    );
    verifyEmailController.dispose();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Decorative elements
          _buildDecorations(),
          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    // Logo
                    _buildLogo(),
                    const SizedBox(height: 16),
                    // Tagline
                    Text(
                      'Your trucking companion',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: const Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 50),
                    // Email field
                    _buildEmailField(),
                    const SizedBox(height: 20),
                    // Password field
                    _buildPasswordField(),
                    const SizedBox(height: 12),
                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF8B5CF6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    // Error message
                    if (_loginError != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade400,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _loginError!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                    // Sign In button
                    _buildSignInButton(),
                    const SizedBox(height: 30),
                    // Sign up link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account yet? ",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/signup'),
                          child: Text(
                            'Sign Up',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8B5CF6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Resend verification link
                    TextButton(
                      onPressed: _showResendVerificationDialog,
                      child: Text(
                        'Resend verification email',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
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
        // Top-left purple arc
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
        // Top-right green arc
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
        // Bottom-right purple arc
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
        // Small decorative circles
        ..._buildSmallCircles(),
      ],
    );
  }

  List<Widget> _buildSmallCircles() {
    return [
      Positioned(
        top: 180,
        left: 30,
        child: _smallCircle(8, const Color(0xFFE5E7EB)),
      ),
      Positioned(
        top: 250,
        right: 40,
        child: _smallCircle(6, const Color(0xFF10B981).withValues(alpha: 0.4)),
      ),
      Positioned(
        bottom: 300,
        left: 50,
        child: _smallCircle(10, const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
      ),
      Positioned(
        bottom: 200,
        right: 30,
        child: _smallCircle(7, const Color(0xFFE5E7EB)),
      ),
      Positioned(
        top: 400,
        left: 20,
        child: _smallCircle(5, const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
    ];
  }

  Widget _smallCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFF10B981)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset('assets/images/milow_icon.png', fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      onChanged: _validateEmail,
      style: GoogleFonts.poppins(fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Email address',
        hintStyle: GoogleFonts.poppins(
          color: const Color(0xFFD1D5DB),
          fontSize: 15,
        ),
        prefixIcon: const Icon(
          Icons.alternate_email,
          color: Color(0xFFD1D5DB),
          size: 22,
        ),
        suffixIcon: _emailValid
            ? const Icon(Icons.check, color: Color(0xFF10B981), size: 22)
            : null,
        errorText: _emailError,
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
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: GoogleFonts.poppins(fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Password',
        hintStyle: GoogleFonts.poppins(
          color: const Color(0xFFD1D5DB),
          fontSize: 15,
        ),
        prefixIcon: const Icon(
          Icons.key_outlined,
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
        errorText: _passwordError,
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
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B5CF6),
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                'SIGN IN',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    );
  }
}
