import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:signature/signature.dart';
import 'package:milow/core/constants/design_tokens.dart';

class InspectionSignaturePad extends StatefulWidget {
  final Function(Uint8List?) onSigned;

  const InspectionSignaturePad({required this.onSigned, super.key});

  @override
  State<InspectionSignaturePad> createState() => _InspectionSignaturePadState();
}

class _InspectionSignaturePadState extends State<InspectionSignaturePad> {
  late SignatureController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.transparent,
      onDrawEnd: _onDrawEnd,
    );
  }

  Future<void> _onDrawEnd() async {
    if (_controller.isNotEmpty) {
      final signature = await _controller.toPngBytes();
      widget.onSigned(signature);
    } else {
      widget.onSigned(null);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetColor = isDark ? Colors.white : Colors.black;

    // Only recreate if color actually changed to avoid unnecessary rebuilds/execution
    if (_controller.penColor != targetColor) {
      final points = _controller.points;
      _controller.dispose();
      _controller = SignatureController(
        penStrokeWidth: 3,
        penColor: targetColor,
        exportBackgroundColor: Colors.transparent,
        onDrawEnd: _onDrawEnd,
        points: points,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Driver Signature',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                _controller.clear();
                widget.onSigned(null);
              },
              icon: Icon(Icons.clear, size: 18, color: tokens.error),
              label: Text('Clear', style: TextStyle(color: tokens.error)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(tokens.shapeM),
            border: Border.all(color: tokens.inputBorder, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tokens.shapeM),
            child: Signature(
              controller: _controller,
              backgroundColor:
                  Colors.transparent, // Background handled by Container
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Sign above to verify this inspection report.',
          style: GoogleFonts.outfit(fontSize: 12, color: tokens.textTertiary),
        ),
      ],
    );
  }
}
