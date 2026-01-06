import 'package:fluent_ui/fluent_ui.dart';

/// A widget that implements Fluent 2 motion choreography.
/// It provides a combined fade and slide transition for page elements.
class ChoreographedEntrance extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Offset offset;
  final double scale;
  final Duration delay;

  const ChoreographedEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.offset = const Offset(0, 0.05), // Subtle slide up
    this.scale = 1.0,
    this.delay = Duration.zero,
  });

  @override
  State<ChoreographedEntrance> createState() => _ChoreographedEntranceState();
}

class _ChoreographedEntranceState extends State<ChoreographedEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );

    _offset = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _scale = Tween<double>(
      begin: widget.scale,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}
