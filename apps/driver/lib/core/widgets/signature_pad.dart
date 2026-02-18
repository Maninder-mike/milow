import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A simple signature pad implementation using CustomPaint
class SignaturePad extends StatefulWidget {
  final double strokeWidth;
  final Color strokeColor;
  final Color backgroundColor;
  final Function(List<Offset>)? onDrawStart;
  final Function(List<Offset>)? onDrawEnd;
  final Function(List<Offset>)? onDrawUpdate;

  const SignaturePad({
    super.key,
    this.strokeWidth = 3.0,
    this.strokeColor = const Color(
      0xFF000000,
    ), // Default to black, will override
    this.backgroundColor = Colors.transparent,
    this.onDrawStart,
    this.onDrawEnd,
    this.onDrawUpdate,
  });

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<Offset?> _points = [];

  void clear() {
    setState(() {
      _points.clear();
    });
  }

  bool get hasSignature => _points.isNotEmpty;

  // Convert points to image bytes (PNG)
  Future<ui.Image?> toImage() async {
    if (_points.isEmpty) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = widget.strokeColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = widget.strokeWidth;

    // Calculate bounds
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (var point in _points) {
      if (point != null) {
        if (point.dx < minX) minX = point.dx;
        if (point.dy < minY) minY = point.dy;
        if (point.dx > maxX) maxX = point.dx;
        if (point.dy > maxY) maxY = point.dy;
      }
    }

    // Add padding
    const padding = 20.0;
    minX -= padding;
    minY -= padding;
    maxX += padding;
    maxY += padding;

    // Ensure positive dimensions
    if (maxX <= minX) maxX = minX + 1;
    if (maxY <= minY) maxY = minY + 1;

    // Draw
    for (int i = 0; i < _points.length - 1; i++) {
      if (_points[i] != null && _points[i + 1] != null) {
        // Offset points relative to minX, minY
        canvas.drawLine(
          _points[i]! - Offset(minX, minY),
          _points[i + 1]! - Offset(minX, minY),
          paint,
        );
      }
    }

    final picture = recorder.endRecording();
    return picture.toImage((maxX - minX).toInt(), (maxY - minY).toInt());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: GestureDetector(
        onPanStart: (details) {
          final renderBox = context.findRenderObject() as RenderBox;
          final point = renderBox.globalToLocal(details.globalPosition);
          setState(() {
            _points.add(point);
          });
          widget.onDrawStart?.call(_points.whereType<Offset>().toList());
        },
        onPanUpdate: (details) {
          final renderBox = context.findRenderObject() as RenderBox;
          final point = renderBox.globalToLocal(details.globalPosition);
          setState(() {
            _points.add(point);
          });
          widget.onDrawUpdate?.call(_points.whereType<Offset>().toList());
        },
        onPanEnd: (details) {
          setState(() {
            _points.add(null);
          });
          widget.onDrawEnd?.call(_points.whereType<Offset>().toList());
        },
        child: CustomPaint(
          painter: _SignaturePainter(
            points: _points,
            color: widget.strokeColor,
            strokeWidth: widget.strokeWidth,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  final Color color;
  final double strokeWidth;

  _SignaturePainter({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
