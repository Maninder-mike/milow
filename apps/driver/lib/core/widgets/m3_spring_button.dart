import 'package:flutter/material.dart';
import '../theme/m3_expressive_motion.dart';

/// A button wrapper that adds a physics-based spring scale effect on tap.
/// This aligns with the M3 Expressive motion guidelines for responsive interaction.
class M3SpringButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  const M3SpringButton({
    required this.child,
    super.key,
    this.onTap,
    this.scaleDown = 0.95,
  });

  @override
  State<M3SpringButton> createState() => _M3SpringButtonState();
}

class _M3SpringButtonState extends State<M3SpringButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: M3ExpressiveMotion.durationShort,
    );
    _scale = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(
        parent: _controller,
        curve: M3ExpressiveMotion.standard,
        reverseCurve: M3ExpressiveMotion.spring,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
