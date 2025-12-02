import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:milow/core/services/local_auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();
  final LocalAuthService _authService = LocalAuthService();
  bool _isLoading = false;
  bool _canCheckBiometrics = false;
  bool _biometricEnabled = false;
  bool _isFirstLogin = true;
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  String? _loginError;

  late final AnimationController _loaderController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();
  late final AnimationController _bgController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat(reverse: true);
  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  late final Animation<double> _fadeAnim = CurvedAnimation(
    parent: _entranceController,
    curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
  );
  late final Animation<Offset> _slideAnim =
      Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
        ),
      );

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _loadBiometricPreference();
    _determineFirstLogin();
    _checkExistingSession();
    _entranceController.forward();
  }

  Future<void> _checkExistingSession() async {
    // Check if user has a valid Supabase session
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && mounted) {
      // Valid session exists, redirect to dashboard
      Future.microtask(() => context.go('/dashboard'));
    }
  }

  Future<void> _determineFirstLogin() async {
    final stored = await _authService.getStoredUserEmail();
    if (mounted) {
      setState(() => _isFirstLogin = stored == null || stored.isEmpty);
    }
  }

  Future<void> _loadBiometricPreference() async {
    final enabled = await _authService.isBiometricEnabled();
    if (mounted) {
      setState(() => _biometricEnabled = enabled);
    }
  }

  Future<void> _checkBiometrics() async {
    late bool canCheckBiometrics;
    try {
      canCheckBiometrics = await auth.canCheckBiometrics;
    } catch (_) {
      canCheckBiometrics = false;
    }
    if (!mounted) return;
    setState(() => _canCheckBiometrics = canCheckBiometrics);
  }

  void _validateEmail(String value) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    setState(() {
      if (value.isEmpty) {
        _emailError = null;
      } else if (!emailRegex.hasMatch(value)) {
        _emailError = 'Please enter a valid email address';
      } else {
        _emailError = null;
      }
    });
  }

  bool _isLockedOut() {
    if (_lockoutUntil == null) return false;
    if (DateTime.now().isBefore(_lockoutUntil!)) return true;
    setState(() => _lockoutUntil = null);
    return false;
  }

  Future<void> _authenticate() async {
    // First check if there's a valid session
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      setState(
        () => _loginError =
            'Session expired. Please login with your email and password.',
      );
      return;
    }

    bool authenticated = false;
    try {
      setState(() => _isLoading = true);
      authenticated = await auth.authenticate(
        localizedReason: 'Authenticate to access your account',
      );
    } on PlatformException catch (_) {
      authenticated = false;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (authenticated && mounted) {
      // Biometric auth successful and session exists
      context.go('/dashboard');
    }
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
      // After successful sign in, if email was just verified recently, show snackbar immediately.
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
        } catch (_) {
          // Ignore parse issues
        }
      }
      await _authService.storeUserEmail(_emailController.text.trim());
      setState(() => _failedAttempts = 0);
      if (mounted) context.go('/dashboard');
    } on AuthException catch (_) {
      setState(() {
        _failedAttempts++;
        if (_failedAttempts >= 3) {
          final delay = _failedAttempts >= 5 ? 60 : 30;
          _lockoutUntil = DateTime.now().add(Duration(seconds: delay));
          _loginError = 'Too many failed attempts. Please wait $delay seconds.';
        } else {
          _loginError = 'Incorrect email or password';
        }
      });
    } catch (_) {
      setState(
        () => _loginError = 'Unable to connect. Please check your internet.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _loaderController.dispose();
    _bgController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paletteA = isDark
        ? [
            const Color(0xFF0F172A),
            const Color(0xFF1E3A8A),
            const Color(0xFF3B82F6),
          ]
        : [
            const Color(0xFF3B82F6),
            const Color(0xFF60A5FA),
            const Color(0xFF8B5CF6),
          ];
    final paletteB = isDark
        ? [
            const Color(0xFF1E293B),
            const Color(0xFF1E3A8A),
            const Color(0xFF3B82F6),
          ]
        : [
            const Color(0xFF1E3A8A),
            const Color(0xFF3B82F6),
            const Color(0xFF60A5FA),
          ];

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          final t = _bgController.value;
          final colors = List<Color>.generate(
            paletteA.length,
            (i) => Color.lerp(paletteA[i], paletteB[i], t)!,
          );
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-0.9 + t * 0.4, -1 + t * 0.4),
                    end: Alignment(1 - t * 0.2, 0.9 - t * 0.4),
                    colors: colors,
                  ),
                ),
              ),
              // Animated accent blobs
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _BlobPainter(progress: t, dark: isDark),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 48,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _buildFullScreenContent(context, isDark),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFullScreenContent(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Milow',
                  style: GoogleFonts.inter(
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isFirstLogin
                      ? 'Create your journey'
                      : 'Welcome back – let\'s roll',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
        FadeTransition(
          opacity: CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.15, 0.75, curve: Curves.easeOut),
          ),
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.12),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: _entranceController,
                    curve: const Interval(
                      0.15,
                      0.8,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.15)
                          : Colors.white.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Simple logo/icon
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.local_shipping,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Email field with label
                      Text(
                        'Email address',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          hintText: 'you@example.com',
                          errorText: _emailError,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        onChanged: _validateEmail,
                      ),
                      const SizedBox(height: 20),

                      // Password field with label
                      Text(
                        'Password',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'Enter your password',
                          errorText: _passwordError,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF94A3B8),
                            ),
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                          ),
                        ),
                        autofillHints: const [AutofillHints.password],
                      ),

                      // Forgot password link - easy to find
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Forgot password?',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ),

                      // Login error message
                      if (_loginError != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _loginError!,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Primary action in thumb zone
                      _buildLoginButton(context),

                      // Create account - visible and clear
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () => context.go('/signup'),
                          child: Text(
                            'Create account',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ),

                      // Biometric option below if available
                      if (_canCheckBiometrics &&
                          _biometricEnabled &&
                          !_isFirstLogin) ...[
                        const SizedBox(height: 8),
                        _buildBiometricButton(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          disabledBackgroundColor: const Color(0xFF94A3B8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 6,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: _isLoading
              ? _FancyLoader(
                  controller: _loaderController,
                  key: const ValueKey('loader'),
                )
              : Text(
                  'Login',
                  key: const ValueKey('text'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildBiometricButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _authenticate,
        icon: const Icon(Icons.fingerprint, color: Color(0xFF6366F1)),
        label: Text(
          'Login with Biometrics',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6366F1),
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF6366F1)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final double progress;
  final bool dark;
  _BlobPainter({required this.progress, required this.dark});
  @override
  void paint(Canvas canvas, Size size) {
    final baseColor = dark ? const Color(0xFF3B82F6) : const Color(0xFF3B82F6);
    final accent = dark ? const Color(0xFF8B5CF6) : const Color(0xFF60A5FA);
    final p1 = Offset(
      size.width * (0.2 + 0.05 * (1 - progress)),
      size.height * (0.35 + 0.1 * progress),
    );
    final p2 = Offset(
      size.width * (0.75 - 0.05 * (1 - progress)),
      size.height * (0.65 - 0.1 * progress),
    );
    final r1 = size.width * 0.28;
    final r2 = size.width * 0.22;
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [baseColor.withOpacity(0.35), baseColor.withOpacity(0.0)],
      ).createShader(Rect.fromCircle(center: p1, radius: r1));
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [accent.withOpacity(0.32), accent.withOpacity(0.0)],
      ).createShader(Rect.fromCircle(center: p2, radius: r2));
    canvas.drawCircle(p1, r1, paint1);
    canvas.drawCircle(p2, r2, paint2);
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.dark != dark;
}

class _FancyLoader extends StatelessWidget {
  final AnimationController controller;
  const _FancyLoader({required this.controller, super.key});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) =>
            CustomPaint(painter: _SpinnerPainter(progress: controller.value)),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  final double progress;
  _SpinnerPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 4.0;
    final rect = Offset.zero & size;
    final start = progress * 6.28318;
    final sweep = 6.28318 * 0.6;
    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: 6.28318,
      colors: const [Color(0xFF6366F1), Color(0xFF3B82F6), Color(0xFF6366F1)],
      stops: const [0.0, 0.5, 1.0],
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      start,
      sweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpinnerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
