import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';

class InfoTooltip extends StatelessWidget {
  final String message;
  final String? title;

  const InfoTooltip({required this.message, super.key, this.title});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return IconButton(
      icon: Icon(
        Icons.info_outline_rounded,
        size: 20,
        color: tokens.textTertiary,
      ),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: tokens.surfaceContainer,
          showDragHandle: true,
          builder: (context) => Container(
            padding: EdgeInsets.fromLTRB(
              tokens.spacingM,
              0,
              tokens.spacingM,
              tokens.spacingXL,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: tokens.spacingS),
                ],
                Text(message, style: Theme.of(context).textTheme.bodyLarge),
                SizedBox(height: tokens.spacingM),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
