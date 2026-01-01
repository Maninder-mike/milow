import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:milow/core/constants/design_tokens.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _contactController = TextEditingController();
  String _type = 'Suggestion';

  @override
  void dispose() {
    _messageController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final type = _type;
    final msg = _messageController.text.trim();
    final contact = _contactController.text.trim();

    final subject = Uri.encodeComponent('Milow Feedback: $type');
    final body = Uri.encodeComponent('''Type: $type
Message:
$msg

Contact (optional): $contact
''');
    final uri = Uri.parse(
      'mailto:info@maninder.co.in?subject=$subject&body=$body',
    );

    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app.')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks! Email composer opened.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error launching email app.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: tokens.scaffoldAltBackground,
      appBar: AppBar(
        backgroundColor: tokens.scaffoldAltBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: tokens.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Send Feedback',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(tokens.spacingL),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How can we help?',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                      SizedBox(height: tokens.spacingS),
                      Text(
                        'Your feedback helps us improve Milow for everyone.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                      SizedBox(height: tokens.spacingXL),
                      Container(
                        padding: EdgeInsets.all(tokens.spacingL),
                        decoration: BoxDecoration(
                          color: tokens.surfaceContainer,
                          borderRadius: BorderRadius.circular(
                            tokens.shapeL + tokens.spacingXS,
                          ),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(tokens.spacingS),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      tokens.shapeS + 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.category_outlined,
                                    size: 20,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                SizedBox(width: tokens.spacingM),
                                Text(
                                  'Feedback Type',
                                  style: textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: tokens.spacingM),
                            Wrap(
                              spacing: tokens.spacingS,
                              runSpacing: tokens.spacingS,
                              children: [
                                for (final t in const [
                                  'Suggestion',
                                  'Complaint',
                                  'Bug',
                                  'Other',
                                ])
                                  ChoiceChip(
                                    label: Text(t),
                                    selected: _type == t,
                                    onSelected: (selected) {
                                      if (selected) setState(() => _type = t);
                                    },
                                    selectedColor: colorScheme.primary,
                                    backgroundColor: tokens.inputBackground,
                                    labelStyle: textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: _type == t
                                          ? colorScheme.onPrimary
                                          : tokens.textPrimary,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        tokens.shapeM,
                                      ),
                                      side: BorderSide(
                                        color: _type == t
                                            ? Colors.transparent
                                            : colorScheme.outlineVariant,
                                      ),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: tokens.spacingXS,
                                      vertical: tokens.spacingXS,
                                    ),
                                    showCheckmark: false,
                                  ),
                              ],
                            ),
                            SizedBox(height: tokens.spacingL),
                            _buildLabel('Your Message'),
                            SizedBox(height: tokens.spacingS),
                            TextFormField(
                              controller: _messageController,
                              maxLines: 6,
                              style: textTheme.bodyMedium?.copyWith(
                                color: tokens.textPrimary,
                              ),
                              decoration: _inputDecoration(
                                hint:
                                    'Tell us what\'s on your mind (min. 10 words)...',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Please enter a message.';
                                }
                                final words = v.trim().split(RegExp(r'\s+'));
                                if (words.length < 10) {
                                  return 'Please write at least 10 words (${words.length}/10).';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: tokens.spacingL),
                            Row(
                              children: [
                                _buildLabel('Contact Info'),
                                SizedBox(width: tokens.spacingS),
                                Text(
                                  '(Optional)',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: tokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: tokens.spacingS),
                            TextFormField(
                              controller: _contactController,
                              style: textTheme.bodyMedium?.copyWith(
                                color: tokens.textPrimary,
                              ),
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecoration(
                                hint: 'Email or phone number',
                                prefixIcon: Icons.contact_mail_outlined,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return null;
                                }
                                final digits = v.replaceAll(RegExp(r'\D'), '');
                                if (digits.length >= 10) {
                                  return null;
                                }
                                if (v.contains('@')) {
                                  return null;
                                }
                                return 'Enter a valid phone (10+ digits) or email.';
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: tokens.spacingL),
                      Container(
                        padding: EdgeInsets.all(tokens.spacingM),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(tokens.shapeM),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                            SizedBox(width: tokens.spacingM),
                            Expanded(
                              child: Text(
                                'Opens your email app — no login required! You can attach photos or videos directly in the email.',
                                style: textTheme.bodySmall?.copyWith(
                                  color: tokens.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: tokens.spacingXL),
                    ],
                  ),
                ),
              ),
            ),

            // Fixed Bottom Button
            Padding(
              padding: EdgeInsets.all(tokens.spacingL),
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.shapeL),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.send_rounded, size: 20),
                    SizedBox(width: tokens.spacingM),
                    Text(
                      'Send Feedback',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Text(
      text,
      style: textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: tokens.textPrimary,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    IconData? prefixIcon,
  }) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      hintText: hint,
      hintStyle: textTheme.bodyMedium?.copyWith(color: tokens.textTertiary),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: colorScheme.primary, size: 20)
          : null,
      filled: true,
      fillColor: tokens.inputBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.shapeL),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.shapeL),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.shapeL),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.shapeL),
        borderSide: BorderSide(color: tokens.error, width: 1),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: tokens.spacingM,
        vertical: tokens.spacingM,
      ),
    );
  }
}
