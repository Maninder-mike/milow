import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/theme/m3_expressive_motion.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: M3ExpressiveMotion.durationEmphasis,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: M3ExpressiveMotion.decelerated,
    );
    _animController.forward();
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      AppDialogs.showWarning(context, 'Please enter your email');
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      AppDialogs.showWarning(context, 'Please enter a valid email');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'milow://reset-password',
      );
      if (mounted) {
        setState(() => _emailSent = true);
      }
    } on AuthException catch (e) {
      if (mounted) {
        AppDialogs.showError(context, e.message);
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(context, 'Failed to send reset email');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
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
                          'Forgot Password',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          'Recover your account',
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
                  child: _emailSent
                      ? _buildSuccessContent()
                      : _buildFormContent(),
                ),
              ),
            ],
          ),
        ),
      ),

      // Bottom Button
      bottomNavigationBar: !_emailSent
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
                  onPressed: _isLoading ? null : _sendResetLink,
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
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Send Reset Link',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                            SizedBox(width: tokens.spacingS),
                            const Icon(Icons.send, size: 20),
                          ],
                        ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildFormContent() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: tokens.spacingXL + tokens.spacingS),

        // App Icon
        Center(
          child: Container(
            padding: EdgeInsets.all(tokens.spacingL),
            decoration: BoxDecoration(
              color: tokens.surfaceContainer,
              borderRadius: BorderRadius.circular(
                tokens.shapeXL + tokens.spacingXS,
              ),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Image.asset(
              'assets/images/milow_icon_beta.png',
              width: 80,
              height: 80,
              fit: BoxFit.contain,
            ),
          ),
        ),

        SizedBox(height: tokens.spacingXL),

        // Description
        Text(
          'Forgot your password?',
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        SizedBox(height: tokens.spacingS),
        Text(
          "No worries! Enter your email address and we'll send you a link to reset your password.",
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: tokens.textSecondary,
            height: 1.5,
          ),
        ),

        SizedBox(height: tokens.spacingXL + tokens.spacingS),

        // Email Field
        _buildLabel('Email Address'),
        SizedBox(height: tokens.spacingS),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: textTheme.bodyLarge?.copyWith(color: tokens.textPrimary),
          decoration: _inputDecoration(
            hint: 'name@email.com',
            prefixIcon: Icons.alternate_email,
          ),
        ),

        SizedBox(height: tokens.spacingXL),

        // Back to login link
        Center(
          child: TextButton(
            onPressed: () => context.go('/login'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back, size: 16),
                SizedBox(width: tokens.spacingS),
                Text(
                  'Back to Sign In',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessContent() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: tokens.spacingXL * 2),

        // Success Icon
        Center(
          child: Container(
            padding: EdgeInsets.all(tokens.spacingL),
            decoration: BoxDecoration(
              color: tokens.surfaceContainer,
              borderRadius: BorderRadius.circular(
                tokens.shapeXL + tokens.spacingXS,
              ),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Icon(
              Icons.mark_email_read_outlined,
              size: 80,
              color: colorScheme.primary,
            ),
          ),
        ),

        SizedBox(height: tokens.spacingXL),

        // Success Message
        Text(
          'Check Your Email',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: tokens.textPrimary,
          ),
        ),
        SizedBox(height: tokens.spacingM),
        Text(
          'We sent a password reset link to',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
        ),
        SizedBox(height: tokens.spacingXS),
        Text(
          _emailController.text.trim(),
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.primary,
          ),
        ),

        SizedBox(height: tokens.spacingXL + tokens.spacingS),

        // Info Card
        Container(
          padding: EdgeInsets.all(tokens.spacingM),
          decoration: BoxDecoration(
            color: tokens.surfaceContainer,
            borderRadius: BorderRadius.circular(
              tokens.shapeL + tokens.spacingXS,
            ),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(tokens.spacingS + 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(tokens.shapeM),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              SizedBox(width: tokens.spacingM),
              Expanded(
                child: Text(
                  "Didn't receive the email? Check your spam folder or try again.",
                  style: textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: tokens.spacingXL + tokens.spacingS),

        // Resend Button
        OutlinedButton(
          onPressed: () => setState(() => _emailSent = false),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.shapeL),
            ),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Text(
            'Resend Email',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
        ),

        SizedBox(height: tokens.spacingM),

        // Back to login
        FilledButton(
          onPressed: () => context.go('/login'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.shapeL),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Back to Sign In',
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
      ],
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
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return InputDecoration(
      hintText: hint,
      hintStyle: textTheme.bodyMedium?.copyWith(color: tokens.textTertiary),
      prefixIcon: Icon(prefixIcon, color: colorScheme.primary, size: 20),
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
