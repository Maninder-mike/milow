import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // [NEW]
import 'package:terminal/core/providers/biometric_provider.dart';
import '../../services/biometric_service.dart';
import '../theme/auth_theme.dart';
import '../../../../core/widgets/choreographed_entrance.dart';
import '../providers/login_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late AuthTheme _theme;

  bool _obscurePassword = true;
  bool _canCheckBiometrics = false;
  bool _hasSavedCredentials = false;
  bool _hasPin = false;

  bool _isResettingPassword = false;

  BiometricService get _biometricService => ref.read(biometricServiceProvider);

  @override
  void initState() {
    super.initState();
    _theme = AuthTheme.getRandom();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricAvailability();
      _checkPinAvailability();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkPinAvailability() async {
    final hasPin = await _biometricService.hasPin();
    if (mounted) {
      setState(() => _hasPin = hasPin);
    }
  }

  Future<void> _checkBiometricAvailability() async {
    final canCheck = await _biometricService.isBiometricAvailable;
    final hasCreds = await _biometricService.hasStoredCredentials();
    if (mounted) {
      setState(() {
        _canCheckBiometrics = canCheck;
        _hasSavedCredentials = hasCreds;
      });
    }
  }

  void _login() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    ref
        .read(loginControllerProvider.notifier)
        .loginWithPassword(email, password);
  }

  void _loginWithBiometrics() {
    ref.read(loginControllerProvider.notifier).loginWithBiometrics();
  }

  void _loginWithPin(String pin) {
    ref.read(loginControllerProvider.notifier).loginWithPin(pin);
  }

  void _sendPasswordReset() {
    final email = _emailController.text.trim();
    ref.read(loginControllerProvider.notifier).sendPasswordReset(email);
  }

  Future<void> _showPinDialog() async {
    final pinController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return ContentDialog(
          title: const Text('Enter PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextBox(
                controller: pinController,
                placeholder: 'PIN',
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                onSubmitted: (value) {
                  Navigator.pop(context);
                  _loginWithPin(value);
                },
              ),
            ],
          ),
          actions: [
            Button(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            FilledButton(
              child: const Text('Login'),
              onPressed: () {
                Navigator.pop(context);
                _loginWithPin(pinController.text);
              },
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    displayInfoBar(
      context,
      builder: (context, close) {
        return InfoBar(
          title: const Text('Login Failed'),
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

  String _getUserFriendlyErrorMessage(Object error) {
    if (error is AuthException) {
      if (error.message.contains('Invalid login credentials')) {
        return 'Incorrect email or password.';
      }
      return error.message;
    }
    final message = error.toString();
    if (message.contains('SocketException') ||
        message.contains('Network is unreachable') ||
        message.contains('connection failed')) {
      return 'No internet connection. Please check your network.';
    }
    if (message.contains('A required entitlement isn\'t present')) {
      return 'Secure storage issue. "Remember Me" features may be unavailable.';
    }
    return 'An unexpected error occurred. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginControllerProvider);
    final isLoading = loginState.isLoading;

    ref.listen(loginControllerProvider, (previous, next) {
      if (next is AsyncError) {
        debugPrint('LOGIN ERROR: ${next.error}');
        debugPrint('LOGIN STACK: ${next.stackTrace}');
        _showError(_getUserFriendlyErrorMessage(next.error));
      } else if (next is AsyncData && !next.isLoading) {
        if (_isResettingPassword) {
          displayInfoBar(
            context,
            builder: (context, close) {
              return InfoBar(
                title: const Text('Email Sent'),
                content: Text('Password reset instructions sent.'),
                severity: InfoBarSeverity.success,
                action: IconButton(
                  icon: const Icon(FluentIcons.dismiss_24_regular),
                  onPressed: close,
                ),
              );
            },
          );
          setState(() => _isResettingPassword = false);
        } else {
          context.go('/dashboard');
        }
      }
    });

    Color buttonTextCol(Color bg) {
      return bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    }

    return Container(
      decoration: BoxDecoration(gradient: _theme.gradient),
      child: Center(
        child: ChoreographedEntrance(
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
                  child: _isResettingPassword
                      ? _buildResetPasswordView(isLoading, buttonTextCol)
                      : _buildLoginView(isLoading, buttonTextCol),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResetPasswordView(
    bool isLoading,
    Color Function(Color) buttonTextCol,
  ) {
    return Column(
      key: const ValueKey('reset'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          FluentIcons.lock_closed_24_regular,
          size: 64,
          color: _theme.primaryContentColor,
        ),
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
          'Enter your email to receive a reset link',
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: _theme.secondaryContentColor,
            decoration: TextDecoration.none,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextBox(
          controller: _emailController,
          placeholder: 'Email',
          prefix: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Icon(
              FluentIcons.mail_24_regular,
              color: _theme.primaryContentColor,
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
          onSubmitted: (_) => _sendPasswordReset(),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: isLoading ? null : _sendPasswordReset,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                _theme.primaryContentColor,
              ),
              foregroundColor: WidgetStateProperty.all(
                buttonTextCol(_theme.primaryContentColor),
              ),
            ),
            child: isLoading
                ? ProgressRing(
                    activeColor: buttonTextCol(_theme.primaryContentColor),
                  )
                : Text(
                    'Send Reset Link',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        HyperlinkButton(
          onPressed: () => setState(() => _isResettingPassword = false),
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.all(
              _theme.primaryContentColor.withValues(alpha: 0.9),
            ),
          ),
          child: Text(
            'Back to Login',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginView(bool isLoading, Color Function(Color) buttonTextCol) {
    return Column(
      key: const ValueKey('login'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/images/terminal_icon.png', width: 64, height: 64),
        const SizedBox(height: 24),
        Text(
          'Milow Terminal',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: _theme.primaryContentColor,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Secure Access Portal',
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: _theme.secondaryContentColor,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 32),
        if ((_canCheckBiometrics || _hasPin) && _hasSavedCredentials) ...[
          if (_canCheckBiometrics) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: isLoading ? null : _loginWithBiometrics,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                    _theme.primaryContentColor,
                  ),
                  foregroundColor: WidgetStateProperty.all(
                    buttonTextCol(_theme.primaryContentColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(FluentIcons.fingerprint_24_regular, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Login with Biometrics',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_hasPin) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: isLoading ? null : _showPinDialog,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                    _theme.primaryContentColor,
                  ),
                  foregroundColor: WidgetStateProperty.all(
                    buttonTextCol(_theme.primaryContentColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(FluentIcons.lock_closed_24_regular, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Login with PIN',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: Divider(
                  style: DividerThemeData(
                    decoration: BoxDecoration(
                      color: _theme.secondaryContentColor.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR',
                  style: GoogleFonts.outfit(
                    color: _theme.secondaryContentColor.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  style: DividerThemeData(
                    decoration: BoxDecoration(
                      color: _theme.secondaryContentColor.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        TextBox(
          controller: _emailController,
          placeholder: 'Email',
          prefix: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Icon(
              FluentIcons.mail_24_regular,
              color: _theme.primaryContentColor,
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
          onSubmitted: (_) => _login(),
        ),
        const SizedBox(height: 16),
        TextBox(
          controller: _passwordController,
          placeholder: 'Password',
          obscureText: _obscurePassword,
          prefix: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Icon(
              FluentIcons.lock_closed_24_regular,
              color: _theme.primaryContentColor,
            ),
          ),
          suffix: IconButton(
            icon: Icon(
              _obscurePassword
                  ? FluentIcons.eye_24_regular
                  : FluentIcons.eye_off_24_regular,
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
          onSubmitted: (_) => _login(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: HyperlinkButton(
            onPressed: isLoading
                ? null
                : () => setState(() => _isResettingPassword = true),
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.all(
                _theme.primaryContentColor.withValues(alpha: 0.9),
              ),
            ),
            child: Text(
              'Forgot password?',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: Button(
            onPressed: isLoading ? null : _login,
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
                    color: _theme.glassBorderColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            child: isLoading
                ? ProgressRing(activeColor: _theme.primaryContentColor)
                : Text(
                    'Login with Password',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: HyperlinkButton(
            onPressed: () => context.go('/signup'),
            child: Text(
              'Create Account',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: _theme.primaryContentColor,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
