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
                      _buildHeaderIcon(
                        icon: Icons.rate_review_rounded,
                        title: 'How can we help?',
                        subtitle:
                            'Your thoughts matter. Help us shape the future of Milow.',
                      ),
                      SizedBox(height: tokens.spacingXL * 1.5),
                      _buildSectionHeader('Feedback Type'),
                      ValueListenableBuilder<String>(
                        valueListenable: ValueNotifier(_type),
                        builder: (context, value, _) {
                          return Wrap(
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
                                    fontWeight: FontWeight.w600,
                                    color: _type == t
                                        ? colorScheme.onPrimary
                                        : tokens.textPrimary,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      tokens.shapeButton,
                                    ),
                                    side: BorderSide(
                                      color: _type == t
                                          ? Colors.transparent
                                          : colorScheme.outlineVariant
                                                .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  showCheckmark: false,
                                ),
                            ],
                          );
                        },
                      ),
                      SizedBox(height: tokens.spacingXL),
                      _buildSectionHeader('Your Message'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLabel('Description'),
                          ListenableBuilder(
                            listenable: _messageController,
                            builder: (context, _) {
                              final wordCount =
                                  _messageController.text.trim().isEmpty
                                  ? 0
                                  : _messageController.text
                                        .trim()
                                        .split(RegExp(r'\s+'))
                                        .length;
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 8,
                                  right: 4,
                                ),
                                child: Text(
                                  '$wordCount words',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: wordCount < 10
                                        ? tokens.error
                                        : tokens.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: _messageController,
                        maxLines: 10,
                        style: textTheme.bodyLarge?.copyWith(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: _inputDecoration(
                          hint: 'Tell us what\'s on your mind...',
                          prefixIcon: Icons.chat_bubble_outline_rounded,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter a message.';
                          }
                          final words = v.trim().split(RegExp(r'\s+'));
                          if (words.length < 10) {
                            return 'Please write at least 10 words.';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: tokens.spacingXL),
                      _buildSectionHeader('Contact Information'),
                      _buildLabel('Email or Phone (Optional)'),
                      TextFormField(
                        controller: _contactController,
                        style: textTheme.bodyLarge?.copyWith(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration(
                          hint: 'Email or phone number',
                          prefixIcon: Icons.alternate_email_rounded,
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
                      SizedBox(height: tokens.spacingL),
                      Container(
                        padding: EdgeInsets.all(tokens.spacingM),
                        decoration: BoxDecoration(
                          color: tokens.infoContainer.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(tokens.shapeM),
                          border: Border.all(
                            color: tokens.infoContainer.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 24,
                              color: tokens.info,
                            ),
                            SizedBox(width: tokens.spacingM),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pro Tip',
                                    style: textTheme.labelLarge?.copyWith(
                                      color: tokens.info,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'This opens your email app directly. You can attach screenshots or videos there to help us understand the issue better.',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: tokens.textPrimary.withValues(
                                        alpha: 0.8,
                                      ),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
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

  Widget _buildHeaderIcon({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(icon, size: 32, color: colorScheme.primary),
          ),
          SizedBox(height: tokens.spacingL),
          Text(
            title,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacingL),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: tokens.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacingM, left: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: context.tokens.textSecondary.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    IconData? prefixIcon,
  }) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InputDecoration(
      hintText: hint,
      hintStyle: textTheme.bodyMedium?.copyWith(color: tokens.textTertiary),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: primaryColor, size: 20)
          : null,
      filled: true,
      fillColor: tokens.inputBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.shapeS),
        borderSide: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.shapeS),
        borderSide: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.shapeS),
        borderSide: BorderSide(color: primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.shapeS),
        borderSide: BorderSide(color: tokens.error, width: 1),
      ),
      contentPadding: const EdgeInsets.all(16),
    );
  }
}
