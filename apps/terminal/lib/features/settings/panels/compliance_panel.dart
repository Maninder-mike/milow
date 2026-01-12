import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/company_provider.dart';

class CompliancePanel extends ConsumerStatefulWidget {
  const CompliancePanel({super.key});

  @override
  ConsumerState<CompliancePanel> createState() => _CompliancePanelState();
}

class _CompliancePanelState extends ConsumerState<CompliancePanel> {
  // Local state for optimistic UI or just to hold value before save
  // We will initialize these from the provider data
  String? _selectedRuleSet;
  double? _maxSpeed;
  bool _isLoading = false;

  final List<String> _ruleSets = [
    'US Federal 70/8',
    'US Federal 60/7',
    'Canada Cycle 1',
    'Canada Cycle 2',
    'Texas Intrastate',
  ];

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyProvider);

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: Text(
          'Compliance',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      children: [
        Text(
          'Manage Hours of Service (HOS) rules and safety limits.',
          style: GoogleFonts.outfit(
            color: FluentTheme.of(context).resources.textFillColorSecondary,
          ),
        ),
        const SizedBox(height: 24),
        companyAsync.when(
          data: (company) {
            // Initialize local state if not set yet (first load)
            // Note: This pattern resets local edits on every provider refresh.
            // For settings, it's usually fine as we want to see latest server state.
            // If user is editing, we might want to avoid this, but keep it simple for now.
            _selectedRuleSet ??= company.hosRuleSet ?? 'US Federal 70/8';
            _maxSpeed ??= company.maxGovernanceSpeed ?? 65.0;

            return _buildSettingsCard(
              context,
              children: [
                _buildRow(
                  context,
                  'HOS Rule Set',
                  'Default cycle for new drivers',
                  ComboBox<String>(
                    value: _selectedRuleSet,
                    items: _ruleSets.map((e) {
                      return ComboBoxItem(value: e, child: Text(e));
                    }).toList(),
                    onChanged: _isLoading
                        ? null
                        : (val) async {
                            if (val != null) {
                              setState(() {
                                _selectedRuleSet = val;
                                _isLoading = true;
                              });
                              try {
                                await ref
                                    .read(companyRepositoryProvider)
                                    .updateSettings(company.id, {
                                      'hos_rule_set': val,
                                    });
                                // Refresh to confirm save
                                ref.invalidate(companyProvider);
                              } catch (e) {
                                debugPrint('Error updating HOS: $e');
                                // Revert or show error
                              } finally {
                                if (mounted) setState(() => _isLoading = false);
                              }
                            }
                          },
                  ),
                ),
                const SizedBox(height: 16),
                _buildRow(
                  context,
                  'Max Governance Speed',
                  'Alert when drivers exceed this limit',
                  SizedBox(
                    width: 200,
                    child: Slider(
                      value: _maxSpeed!,
                      min: 55,
                      max: 85,
                      onChanged: _isLoading
                          ? null
                          : (v) {
                              setState(() => _maxSpeed = v);
                            },
                      onChangeEnd: (v) async {
                        setState(() => _isLoading = true);
                        try {
                          await ref
                              .read(companyRepositoryProvider)
                              .updateSettings(company.id, {
                                'max_governance_speed': v,
                              });
                          ref.invalidate(companyProvider);
                        } catch (e) {
                          debugPrint('Error updating speed: $e');
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                      label: '${_maxSpeed!.round()} MPH',
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: ProgressBar()),
          error: (error, stack) =>
              Center(child: Text('Error loading settings: $error')),
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
