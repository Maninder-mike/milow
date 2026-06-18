import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:terminal/core/widgets/ui_hardening.dart';
import 'package:terminal/features/settings/providers/company_provider.dart';

class IntegrationPanel extends ConsumerStatefulWidget {
  const IntegrationPanel({super.key});

  @override
  ConsumerState<IntegrationPanel> createState() => _IntegrationPanelState();
}

class _IntegrationPanelState extends ConsumerState<IntegrationPanel> {
  final TextEditingController _webhookController = TextEditingController();
  List<dynamic>? _apiKeys;
  bool _isLoading = false;

  @override
  void dispose() {
    _webhookController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyProvider);

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: Text(
          'Integrations',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      children: [
        Text(
          'Manage API access and third-party webhooks.',
          style: GoogleFonts.outfit(
            color: FluentTheme.of(context).resources.textFillColorSecondary,
          ),
        ),
        const SizedBox(height: 24),
        companyAsync.when(
          data: (company) {
            // Initialize local keys list if not yet loaded (or updated)
            if (_apiKeys == null) {
              _apiKeys = List.from(company.apiKeys ?? []);
              _webhookController.text = company.dispatchWebhookUrl ?? '';
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(context, 'API Keys'),
                const SizedBox(height: 8),
                _buildSettingsCard(
                  context,
                  children: [
                    if (_apiKeys!.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          'No API keys generated.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ..._apiKeys!.map(
                      (key) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildApiKeyRow(context, key.toString()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Button(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              final newKey =
                                  'mk_live_${_generateRandomString(16)}';
                              final updatedList = List<String>.from(_apiKeys!)
                                ..add(newKey);

                              try {
                                await ref
                                    .read(companyRepositoryProvider)
                                    .updateApiKeys(company.id, updatedList);
                                setState(() {
                                  _apiKeys = updatedList;
                                });
                                ref.invalidate(companyProvider);
                              } catch (e) {
                                debugPrint('Error generating key: $e');
                              } finally {
                                if (mounted) {
                                  setState(() => _isLoading = false);
                                }
                              }
                            },
                      child: const Text('Generate New Key'),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                _buildSectionHeader(context, 'Webhooks'),
                const SizedBox(height: 8),
                _buildSettingsCard(
                  context,
                  children: [
                    InfoLabel(
                      label: 'Dispatch Events URL',
                      child: TextBox(
                        controller: _webhookController,
                        placeholder:
                            'https://api.yourcompany.com/webhooks/milow',
                        onChanged: (v) {
                          // Allow typing freely
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                setState(() => _isLoading = true);
                                try {
                                  await ref
                                      .read(companyRepositoryProvider)
                                      .updateSettings(company.id, {
                                        'dispatch_webhook_url':
                                            _webhookController.text,
                                      });
                                  ref.invalidate(companyProvider);
                                  if (context.mounted) {
                                    displayInfoBar(
                                      context,
                                      builder: (context, close) {
                                        return InfoBar(
                                          title: const Text('Webhook Saved'),
                                          severity: InfoBarSeverity.success,
                                          onClose: close,
                                        );
                                      },
                                    );
                                  }
                                } catch (e) {
                                  debugPrint('Error saving webhook: $e');
                                } finally {
                                  if (mounted) {
                                    setState(() => _isLoading = false);
                                  }
                                }
                              },
                        child: const Text('Save Webhook'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const IntegrationSkeleton(),
          error: (err, stack) => StandardErrorState(
            message: 'Failed to load integration settings: $err',
            onRetry: () => ref.invalidate(companyProvider),
          ),
        ),
      ],
    );
  }

  String _generateRandomString(int length) {
    const chars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    Random rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
      ),
    );
  }

  Widget _buildApiKeyRow(BuildContext context, String key) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).resources.subtleFillColorSecondary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                FluentIcons.key_24_regular,
                size: 16,
              ),
              const SizedBox(width: 8),
              SelectableText(
                key,
                style: GoogleFonts.sourceCodePro(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(FluentIcons.copy_24_regular, size: 14),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: key));
              displayInfoBar(
                context,
                builder: (context, close) {
                  return InfoBar(
                    title: const Text('Copied to clipboard'),
                    severity: InfoBarSeverity.success,
                    onClose: close,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: FluentTheme.of(context).resources.textFillColorPrimary,
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class IntegrationSkeleton extends StatelessWidget {
  const IntegrationSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonBox(width: 100, height: 16),
        const SizedBox(height: 12),
        _buildSkeletonCard(
          context,
          children: [
            const SkeletonBox(width: double.infinity, height: 40),
            const SizedBox(height: 12),
            const SkeletonBox(width: 150, height: 32),
          ],
        ),
        const SizedBox(height: 32),
        const SkeletonBox(width: 100, height: 16),
        const SizedBox(height: 12),
        _buildSkeletonCard(
          context,
          children: [
            const SkeletonBox(width: 120, height: 14),
            const SizedBox(height: 8),
            const SkeletonBox(width: double.infinity, height: 36),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerRight,
              child: SkeletonBox(width: 120, height: 32),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSkeletonCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
