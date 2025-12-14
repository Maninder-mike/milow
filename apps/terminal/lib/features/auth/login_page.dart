import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'services/biometric_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _biometricService = BiometricService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _canCheckBiometrics = false;
  bool _hasSavedCredentials = false;
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
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

      // Auto-prompt if available and we have credentials?
      // Maybe not for now, let user click the button.
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
      // For now just close or shake?
      // Ideally keep dialog open and show error inside.
      // Current implementation pops dialog on success only.
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
        ),
      ),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: 0.2,
                ), // Fluent Colors.white
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FluentIcons.shield, size: 64, color: Colors.white),
                  const SizedBox(height: 24),
                  Text(
                    'Milow Admin',
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Secure Access Portal',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.7),
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
                          onPressed: _isLoading ? null : _loginWithBiometrics,
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(
                              Colors.white,
                            ),
                            foregroundColor: WidgetStateProperty.all(
                              const Color(0xFF6C5CE7),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(FluentIcons.fingerprint, size: 20),
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
                              Colors.white,
                            ),
                            foregroundColor: WidgetStateProperty.all(
                              const Color(0xFF6C5CE7),
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
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            style: DividerThemeData(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
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
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(FluentIcons.mail, color: Colors.white),
                    ),
                    placeholderStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: WidgetStateProperty.all(
                      BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
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
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(FluentIcons.lock, color: Colors.white),
                    ),
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? FluentIcons.red_eye
                            : FluentIcons.hide,
                        color: Colors.white,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    placeholderStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: WidgetStateProperty.all(
                      BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48, // Increased height for better touch target
                    child: Button(
                      // Changed from FilledButton to Button for "secondary" look if biometrics is primary, or keep FilledButton if password is still primary
                      onPressed: _isLoading ? null : _login,
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(
                          Colors.white.withValues(alpha: 0.2),
                        ),
                        foregroundColor: WidgetStateProperty.all(Colors.white),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                      child: _isLoading
                          ? const ProgressRing(activeColor: Colors.white)
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'New admin? ',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.7),
                          decoration: TextDecoration.none,
                          fontSize: 14,
                        ),
                      ),
                      HyperlinkButton(
                        onPressed: () => context.go('/signup'),
                        child: Text(
                          'Create Account',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
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
    );
  }
}
