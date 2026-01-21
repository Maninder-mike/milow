import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/widgets/m3_spring_button.dart';

/// A split button that offers a primary action and a secondary dropdown menu.
/// Used for "Save" vs "Save as Template".
class SplitSaveButton extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onSaveAsTemplate;
  final bool isLoading;

  const SplitSaveButton({
    required this.onSave,
    required this.onSaveAsTemplate,
    super.key,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    // M3-style standardized elevation
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary Action Button (Left side)
        M3SpringButton(
          onTap: isLoading ? null : onSave,
          child: SizedBox(
            height: 36, // Smaller touch target
            child: FilledButton.icon(
              onPressed: null, // M3SpringButton handles tap
              style: FilledButton.styleFrom(
                disabledBackgroundColor: theme.colorScheme.primary,
                disabledForegroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(tokens.shapeFull),
                    bottomLeft: Radius.circular(tokens.shapeFull),
                    topRight: Radius.zero,
                    bottomRight: Radius.zero,
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: tokens.spacingM),
              ),
              icon: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(
                isLoading ? 'Saving...' : 'Save',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 1), // Tiny gap
        // Dropdown Menu Button (Right side)
        SizedBox(
          height: 36,
          child: MenuAnchor(
            builder: (context, controller, child) {
              return FilledButton(
                onPressed: isLoading
                    ? null
                    : () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          controller.open();
                        }
                      },
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.zero,
                      bottomLeft: Radius.zero,
                      topRight: Radius.circular(tokens.shapeFull),
                      bottomRight: Radius.circular(tokens.shapeFull),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  minimumSize: const Size(36, 36), // Smaller square target
                ),
                child: const Icon(Icons.arrow_drop_down, size: 20),
              );
            },
            menuChildren: [
              MenuItemButton(
                onPressed: onSaveAsTemplate,
                leadingIcon: const Icon(Icons.save_as_outlined),
                child: const Text('Save as Template'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
