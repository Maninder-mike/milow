import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'services/biometric_service.dart';
import 'auth_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _biometricService = BiometricService();

  late AuthTheme _theme;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _canCheckBiometrics = false;
  bool _hasSavedCredentials = false;
  bool _hasPin = false;

  bool _isResettingPassword = false;

  @override
  void initState() {
    super.initState();
    _theme = AuthTheme.getRandom();
    _checkBiometricAvailability();
    _checkPinAvailability();
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

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Save credentials on successful login
      await _biometricService.saveCredentials(email, password);

      if (mounted) {
        final hasPin = await _biometricService.hasPin();
        if (!hasPin && mounted) {
          await _showSetPinDialog();
        }
        if (mounted) {
          context.go('/dashboard');
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        _showError('Unexpected error occurred');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showSetPinDialog() async {
    final pinController = TextEditingController();
    await showDialog<String>(
      context: context,
      builder: (context) {
        return ContentDialog(
          title: const Text('Create a PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Set a PIN for faster login next time.'),
              const SizedBox(height: 16),
              TextBox(
                controller: pinController,
                placeholder: 'Enter 4-digit PIN',
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
              ),
            ],
          ),
          actions: [
            Button(
              child: const Text('Skip'),
              onPressed: () => Navigator.pop(context),
            ),
            FilledButton(
              child: const Text('Save PIN'),
              onPressed: () async {
                if (pinController.text.length == 4) {
                  await _biometricService.setPin(pinController.text);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _loginWithPin() async {
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
                onSubmitted: (value) => _verifyAndLogin(value),
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
              onPressed: () => _verifyAndLogin(pinController.text),
            ),
          ],
        );
      },
    );
  }

  Future<void> _verifyAndLogin(String pin) async {
    if (await _biometricService.verifyPin(pin)) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
      }
      setState(() => _isLoading = true);
      try {
        final credentials = await _biometricService.getCredentials();
        if (credentials != null) {
          await Supabase.instance.client.auth.signInWithPassword(
            email: credentials['email']!,
            password: credentials['password']!,
          );
          if (mounted) {
            context.go('/dashboard');
          }
        } else {
          if (mounted) {
            _showError('No saved credentials found.');
          }
        }
      } catch (e) {
        if (mounted) {
          _showError('Login failed');
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      // Show PIN error?
    }
  }

  Future<void> _loginWithBiometrics() async {
    setState(() => _isLoading = true);
    try {
      final authenticated = await _biometricService.authenticate();
      if (authenticated) {
        final credentials = await _biometricService.getCredentials();
        if (credentials != null) {
          await Supabase.instance.client.auth.signInWithPassword(
            email: credentials['email']!,
            password: credentials['password']!,
          );
          if (mounted) {
            context.go('/dashboard');
          }
        } else {
          if (mounted) {
            _showError(
              'No saved credentials found. Please login with password first.',
            );
          }
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        _showError('Biometric authentication failed');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Please enter your email address');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'milow-terminal://reset-password',
      );
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: const Text('Email Sent'),
              content: Text('Password reset instructions sent to $email'),
              severity: InfoBarSeverity.success,
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
            );
          },
        );
        setState(() => _isResettingPassword = false);
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('Failed to send reset email');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            icon: const Icon(FluentIcons.clear),
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
                    ? Column(
                        key: const ValueKey('reset'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            FluentIcons.lock,
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
                            controller: _emailController,
                            placeholder: 'Email',
                            prefix: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Icon(
                                FluentIcons.mail,
                                color: _theme.primaryContentColor,
                              ),
                            ),
                            placeholderStyle: TextStyle(
                              color: _theme.secondaryContentColor,
                            ),
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
                              onPressed: _isLoading ? null : _sendPasswordReset,
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
                                      'Send Reset Link',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          HyperlinkButton(
                            onPressed: () =>
                                setState(() => _isResettingPassword = false),
                            style: ButtonStyle(
                              foregroundColor: WidgetStateProperty.all(
                                _theme.primaryContentColor.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                            ),
                            child: Text(
                              'Back to Login',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        key: const ValueKey('login'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/terminal_icon.png',
                            width: 64,
                            height: 64,
                          ),
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
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: _theme.secondaryContentColor,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 32),
                          if ((_canCheckBiometrics || _hasPin) &&
                              _hasSavedCredentials) ...[
                            if (_canCheckBiometrics) ...[
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _loginWithBiometrics,
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
                                      const Icon(
                                        FluentIcons.fingerprint,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Login with Biometrics',
                                        style: GoogleFonts.inter(
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
                                  onPressed: _isLoading ? null : _loginWithPin,
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
                                      const Icon(FluentIcons.lock, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Login with PIN',
                                        style: GoogleFonts.inter(
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
                                        color: _theme.secondaryContentColor
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    'OR',
                                    style: GoogleFonts.inter(
                                      color: _theme.secondaryContentColor
                                          .withValues(alpha: 0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    style: DividerThemeData(
                                      decoration: BoxDecoration(
                                        color: _theme.secondaryContentColor
                                            .withValues(alpha: 0.3),
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
                                FluentIcons.mail,
                                color: _theme.primaryContentColor,
                              ),
                            ),
                            placeholderStyle: TextStyle(
                              color: _theme.secondaryContentColor,
                            ),
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
                                FluentIcons.lock,
                                color: _theme.primaryContentColor,
                              ),
                            ),
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? FluentIcons.red_eye
                                    : FluentIcons.hide,
                                color: _theme.primaryContentColor,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            placeholderStyle: TextStyle(
                              color: _theme.secondaryContentColor,
                            ),
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
                              onPressed: _isLoading
                                  ? null
                                  : () => setState(
                                      () => _isResettingPassword = true,
                                    ),
                              style: ButtonStyle(
                                foregroundColor: WidgetStateProperty.all(
                                  _theme.primaryContentColor.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Forgot password?',
                                style: GoogleFonts.inter(
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
                              onPressed: _isLoading ? null : _login,
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
                                  ? ProgressRing(
                                      activeColor: _theme.primaryContentColor,
                                    )
                                  : Text(
                                      'Login with Password',
                                      style: GoogleFonts.inter(
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
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: _theme.primaryContentColor,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
