import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/company_provider.dart';

class SecurityPanel extends ConsumerStatefulWidget {
  const SecurityPanel({super.key});

  @override
  ConsumerState<SecurityPanel> createState() => _SecurityPanelState();
}

class _SecurityPanelState extends ConsumerState<SecurityPanel> {
  bool? _enforce2FA;
  double? _passwordRotationDays;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyProvider);

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: Text(
          'Security',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      children: [
        InfoBar(
          title: const Text('Enterprise Grade Security'),
          content: const Text(
            'Changes here affect all users in your organization immediately.',
          ),
          severity: InfoBarSeverity.warning,
          isLong: true,
        ),
        const SizedBox(height: 24),
        companyAsync.when(
          data: (company) {
            _enforce2FA ??= company.enforce2fa;
            _passwordRotationDays ??= company.passwordRotationDays.toDouble();

            return _buildSettingsCard(
              context,
              children: [
                _buildRow(
                  context,
                  'Enforce 2FA',
                  'Require Two-Factor Auth for all staff',
                  ToggleSwitch(
                    checked: _enforce2FA!,
                    onChanged: _isLoading
                        ? null
                        : (v) async {
                            setState(() {
                              _enforce2FA = v;
                              _isLoading = true;
                            });
                            try {
                              await ref
                                  .read(companyRepositoryProvider)
                                  .updateSettings(company.id, {
                                    'enforce_2fa': v,
                                  });
                              ref.invalidate(companyProvider);
                            } catch (e) {
                              debugPrint('Error updating 2FA: $e');
                            } finally {
                              if (mounted) setState(() => _isLoading = false);
                            }
                          },
                  ),
                ),
                const SizedBox(height: 16),
                _buildRow(
                  context,
                  'Password Rotation',
                  'Days before forced reset',
                  SizedBox(
                    width: 200,
                    child: Slider(
                      value: _passwordRotationDays!,
                      min: 30,
                      max: 180,
                      divisions: 5,
                      onChanged: _isLoading
                          ? null
                          : (v) {
                              setState(() => _passwordRotationDays = v);
                            },
                      onChangeEnd: (v) async {
                        setState(() => _isLoading = true);
                        try {
                          await ref
                              .read(companyRepositoryProvider)
                              .updateSettings(company.id, {
                                'password_rotation_days': v.toInt(),
                              });
                          ref.invalidate(companyProvider);
                        } catch (e) {
                          debugPrint('Error updating rotation: $e');
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                      label: '${_passwordRotationDays!.round()} Days',
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: ProgressBar()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ],
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
      child: Column(children: children),
    );
  }

  Widget _buildRow(
    BuildContext context,
    String label,
    String subLabel,
    Widget control,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: FluentTheme.of(context).resources.textFillColorPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subLabel,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: FluentTheme.of(context).resources.textFillColorSecondary,
              ),
            ),
          ],
        ),
        control,
      ],
    );
  }
}
