import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';

/// Collapsible section for owner-operator load details
/// Only visible when driver type is ownerOperator or leaseOperator
class LoadDetailsSection extends StatefulWidget {
  final TextEditingController commodityController;
  final TextEditingController weightController;
  final TextEditingController piecesController;
  final List<TextEditingController> referenceNumberControllers;
  final String weightUnit;
  final ValueChanged<String> onWeightUnitChanged;
  final VoidCallback onAddReferenceNumber;
  final ValueChanged<int> onRemoveReferenceNumber;
  final bool initiallyExpanded;

  const LoadDetailsSection({
    required this.commodityController,
    required this.weightController,
    required this.piecesController,
    required this.referenceNumberControllers,
    required this.weightUnit,
    required this.onWeightUnitChanged,
    required this.onAddReferenceNumber,
    required this.onRemoveReferenceNumber,
    super.key,
    this.initiallyExpanded = false,
  });

  @override
  State<LoadDetailsSection> createState() => _LoadDetailsSectionState();
}

class _LoadDetailsSectionState extends State<LoadDetailsSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceContainer,
        borderRadius: BorderRadius.circular(tokens.shapeM),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          // Header - always visible
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(tokens.shapeM),
              bottom: _isExpanded
                  ? Radius.zero
                  : Radius.circular(tokens.shapeM),
            ),
            child: Padding(
              padding: EdgeInsets.all(tokens.spacingM),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(tokens.spacingS),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(tokens.shapeS),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: tokens.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Load Details',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Commodity, weight, pieces',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildContent(tokens, theme),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(DesignTokens tokens, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacingM,
        0,
        tokens.spacingM,
        tokens.spacingM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: theme.colorScheme.outlineVariant),
          SizedBox(height: tokens.spacingS),

          // Commodity
          _buildLabel('Commodity', tokens),
          SizedBox(height: tokens.spacingXS),
          _buildTextField(
            controller: widget.commodityController,
            hint: 'e.g., Dry Goods, Reefer, Flatbed',
            icon: Icons.category_outlined,
            tokens: tokens,
            theme: theme,
          ),
          SizedBox(height: tokens.spacingM),

          // Weight and Unit
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Weight', tokens),
                    SizedBox(height: tokens.spacingXS),
                    _buildTextField(
                      controller: widget.weightController,
                      hint: '0',
                      icon: Icons.scale_outlined,
                      keyboardType: TextInputType.number,
                      tokens: tokens,
                      theme: theme,
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Unit', tokens),
                    SizedBox(height: tokens.spacingXS),
                    _buildUnitSelector(tokens, theme),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacingM),

          // Pieces
          _buildLabel('Pieces / Pallets', tokens),
          SizedBox(height: tokens.spacingXS),
          _buildTextField(
            controller: widget.piecesController,
            hint: '0',
            icon: Icons.view_in_ar_outlined,
            keyboardType: TextInputType.number,
            tokens: tokens,
            theme: theme,
          ),
          SizedBox(height: tokens.spacingM),

          // Reference Numbers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLabel('Reference Numbers', tokens),
              FilledButton.tonalIcon(
                onPressed: widget.onAddReferenceNumber,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.tertiaryContainer,
                  foregroundColor: theme.colorScheme.onTertiaryContainer,
                  padding: EdgeInsets.symmetric(horizontal: tokens.spacingS),
                  minimumSize: const Size(0, 32),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacingXS),
          ...widget.referenceNumberControllers.asMap().entries.map((entry) {
            final index = entry.key;
            final controller = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: tokens.spacingS),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: controller,
                      hint: 'PO#, Booking#, etc.',
                      icon: Icons.tag_outlined,
                      tokens: tokens,
                      theme: theme,
                    ),
                  ),
                  if (widget.referenceNumberControllers.length > 1) ...[
                    SizedBox(width: tokens.spacingS),
                    IconButton(
                      onPressed: () => widget.onRemoveReferenceNumber(index),
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: theme.colorScheme.error,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, DesignTokens tokens) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: tokens.textSecondary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required DesignTokens tokens,
    required ThemeData theme,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: theme.textTheme.bodyMedium?.copyWith(color: tokens.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: tokens.textTertiary,
        ),
        prefixIcon: Icon(icon, color: theme.colorScheme.primary, size: 20),
        filled: true,
        fillColor: tokens.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.shapeS),
          borderSide: BorderSide(color: tokens.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.shapeS),
          borderSide: BorderSide(color: tokens.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.shapeS),
          borderSide: BorderSide(color: tokens.inputFocusedBorder, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: tokens.spacingM,
          vertical: tokens.spacingS,
        ),
        isDense: true,
      ),
    );
  }

  Widget _buildUnitSelector(DesignTokens tokens, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.inputBackground,
        borderRadius: BorderRadius.circular(tokens.shapeS),
        border: Border.all(color: tokens.inputBorder),
      ),
      child: Row(
        children: [
          _buildUnitOption('lbs', tokens, theme),
          _buildUnitOption('kg', tokens, theme),
        ],
      ),
    );
  }

  Widget _buildUnitOption(String unit, DesignTokens tokens, ThemeData theme) {
    final isSelected = widget.weightUnit == unit;
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onWeightUnitChanged(unit),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: tokens.spacingS),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(tokens.shapeXS),
          ),
          child: Center(
            child: Text(
              unit,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : tokens.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
