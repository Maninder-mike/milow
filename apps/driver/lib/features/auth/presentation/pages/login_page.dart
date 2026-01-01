import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/services/profile_service.dart';
import 'package:milow/core/services/logging_service.dart';
import 'package:milow/l10n/app_localizations.dart';
import 'package:milow/core/constants/design_tokens.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _loginError;
  bool _emailValid = false;

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

  void _validateEmail(String value) {
    final trimmed = value.trim();
    final valid = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(trimmed);
    setState(() {
      _emailValid = valid;
    });
  }

  Future<void> _signIn() async {
    // Validation
    if (_emailController.text.trim().isEmpty) {
      AppDialogs.showWarning(
        context,
        AppLocalizations.of(context)!.pleaseEnterEmail,
      );
      return;
    }
    if (!_emailValid) {
      AppDialogs.showWarning(
        context,
        AppLocalizations.of(context)!.pleaseEnterValidEmail,
      );
      return;
    }
    if (_passwordController.text.isEmpty) {
      AppDialogs.showWarning(
        context,
        AppLocalizations.of(context)!.pleaseEnterPassword,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _loginError = null;
    });
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (res.session != null && mounted) {
        AppDialogs.showSuccess(
          context,
          '${AppLocalizations.of(context)!.welcomeBack}!',
        );
        context.go('/dashboard');
      } else {
        setState(
          () => _loginError = AppLocalizations.of(context)!.invalidCredentials,
        );
      }
    } on AuthException catch (e) {
      setState(() => _loginError = e.message);
    } catch (_) {
      setState(() => _loginError = AppLocalizations.of(context)!.signInFailed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _loginError = null;
    });

    try {
      unawaited(logger.logAuth('google_sign_in_started'));

      const webClientId =
          '799615226888-jrbav7ltvmiims5vj0mg153qcvg247l3.apps.googleusercontent.com';

      unawaited(logger.debug('GoogleSignIn', 'Initializing with client ID'));
      await GoogleSignIn.instance.initialize(serverClientId: webClientId);

      unawaited(logger.debug('GoogleSignIn', 'Starting authentication dialog'));
      final googleUser = await GoogleSignIn.instance.authenticate();
      unawaited(
        logger.info('GoogleSignIn', 'User authenticated: ${googleUser.email}'),
      );

      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        unawaited(
          logger.error(
            'GoogleSignIn',
            'ID token is null',
            extras: {'email': googleUser.email},
          ),
        );
        throw Exception('Failed to get Google ID token');
      }

      unawaited(
        logger.debug('GoogleSignIn', 'Signing in to Supabase with ID token'),
      );
      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      if (response.session != null && mounted) {
        unawaited(
          logger.logAuth('google_sign_in_success', userId: response.user?.id),
        );

        try {
          await ProfileService.updateProfile({
            'email': googleUser.email,
            'full_name': googleUser.displayName,
            'avatar_url': googleUser.photoUrl,
            'role': 'driver',
          });
          unawaited(logger.info('GoogleSignIn', 'Profile synced successfully'));
        } catch (e) {
          unawaited(
            logger.warning(
              'GoogleSignIn',
              'Profile sync failed',
              extras: {'error': e.toString()},
            ),
          );
        }

        if (mounted) {
          AppDialogs.showSuccess(
            context,
            AppLocalizations.of(context)!.signedInWithGoogle,
          );
          context.go('/dashboard');
        }
      } else {
        unawaited(
          logger.error(
            'GoogleSignIn',
            'Session creation failed',
            extras: {
              'hasUser': response.user != null,
              'hasSession': response.session != null,
            },
          ),
        );
        throw Exception('Failed to create session');
      }
    } on AuthException catch (error) {
      unawaited(
        logger.error(
          'GoogleSignIn',
          'Auth exception',
          error: error,
          extras: {'message': error.message, 'statusCode': error.statusCode},
        ),
      );
      setState(() => _loginError = error.message);
    } catch (error, stackTrace) {
      unawaited(
        logger.error(
          'GoogleSignIn',
          'Unexpected error during sign-in',
          error: error,
          stackTrace: stackTrace,
          extras: {'errorType': error.runtimeType.toString()},
        ),
      );
      setState(
        () => _loginError = AppLocalizations.of(context)!.googleSignInFailed,
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
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
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacingL,
                vertical: tokens.spacingXL + tokens.spacingS,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(),
                  SizedBox(height: tokens.spacingL),
                  Text(
                    AppLocalizations.of(context)!.welcomeBack,
                    style: textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  SizedBox(height: tokens.spacingS),
                  Text(
                    AppLocalizations.of(context)!.signInSubtitle,
                    style: textTheme.bodyLarge?.copyWith(
                      color: tokens.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: tokens.spacingXL + tokens.spacingS),

                  // Email Field
                  _buildLabel(AppLocalizations.of(context)!.emailAddress),
                  SizedBox(height: tokens.spacingS),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: _validateEmail,
                    style: textTheme.bodyLarge?.copyWith(
                      color: tokens.textPrimary,
                    ),
                    decoration: _inputDecoration(
                      hint: AppLocalizations.of(context)!.emailHint,
                      prefixIcon: Icons.alternate_email_rounded,
                      suffixIcon: _emailValid
                          ? Icons.check_circle_rounded
                          : null,
                      suffixColor: tokens.success,
                    ),
                  ),

                  SizedBox(height: tokens.spacingM + tokens.spacingXS),

                  // Password Field
                  _buildLabel(AppLocalizations.of(context)!.password),
                  SizedBox(height: tokens.spacingS),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: textTheme.bodyLarge?.copyWith(
                      color: tokens.textPrimary,
                    ),
                    decoration: _inputDecoration(
                      hint: AppLocalizations.of(context)!.enterPasswordHint,
                      prefixIcon: Icons.lock_rounded,
                      suffixIcon: _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      onSuffixTap: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),

                  SizedBox(height: tokens.spacingM),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.go('/forgot-password'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                        foregroundColor: colorScheme.primary,
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.forgotPassword,
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: tokens.spacingL),

                  // Sign In Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _signIn,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(tokens.shapeL),
                        ),
                        backgroundColor: colorScheme.primary,
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
                                  AppLocalizations.of(context)!.signIn,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                                SizedBox(width: tokens.spacingS),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20,
                                ),
                              ],
                            ),
                    ),
                  ),

                  // Error message
                  if (_loginError != null) ...[
                    SizedBox(height: tokens.spacingM),
                    Container(
                      padding: EdgeInsets.all(tokens.spacingM),
                      decoration: BoxDecoration(
                        color: tokens.errorContainer,
                        borderRadius: BorderRadius.circular(tokens.shapeM),
                        border: Border.all(
                          color: tokens.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: tokens.error,
                            size: 20,
                          ),
                          SizedBox(width: tokens.spacingS + 2),
                          Expanded(
                            child: Text(
                              _loginError!,
                              style: textTheme.bodySmall?.copyWith(
                                color: tokens.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: tokens.spacingXL),

                  // Or divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: colorScheme.outlineVariant),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: tokens.spacingM,
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.orContinueWith,
                          style: textTheme.bodyMedium?.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: colorScheme.outlineVariant),
                      ),
                    ],
                  ),

                  SizedBox(height: tokens.spacingL),

                  // Google Sign In
                  _buildGoogleButton(),

                  SizedBox(height: tokens.spacingXL),

                  // Sign up link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${AppLocalizations.of(context)!.dontHaveAccount} ',
                        style: textTheme.bodyMedium?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/signup'),
                        child: Text(
                          AppLocalizations.of(context)!.signUp,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
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

  Widget _buildLogo() {
    final tokens = context.tokens;
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.shapeL + tokens.spacingXS),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.shapeL + tokens.spacingXS),
        child: Image.asset(
          'assets/images/milow_icon_beta.png',
          width: 100,
          height: 100,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final tokens = context.tokens;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: _isGoogleLoading ? null : _signInWithGoogle,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.shapeL),
          ),
          side: BorderSide(color: colorScheme.outlineVariant),
          backgroundColor: tokens.surfaceContainer,
        ),
        child: _isGoogleLoading
            ? Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.0,
                    strokeCap: StrokeCap.round,
                    color: colorScheme.primary,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CachedNetworkImage(
                    imageUrl: 'https://www.google.com/favicon.ico',
                    width: 20,
                    height: 20,
                    memCacheHeight: 40,
                    memCacheWidth: 40,
                    errorWidget: (context, url, error) {
                      return Text(
                        'G',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: tokens.info,
                        ),
                      );
                    },
                  ),
                  SizedBox(width: tokens.spacingM),
                  Text(
                    AppLocalizations.of(context)!.continueWithGoogle,
                    style: textTheme.bodyLarge?.copyWith(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
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

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
    Color? suffixColor,
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
              icon: Icon(
                suffixIcon,
                color: suffixColor ?? colorScheme.primary,
                size: 20,
              ),
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
