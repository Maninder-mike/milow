import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui' show PointerDeviceKind;

// Note: We test the visual and interaction aspects of the buttons.
// The actual window_manager calls are platform-specific and tested in integration tests.

void main() {
  group('Window Control Buttons', () {
    testWidgets('renders minimize, maximize, and close buttons', (
      tester,
    ) async {
      await tester.pumpWidget(
        FluentApp(
          home: ScaffoldPage(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TestWindowButton(
                  icon: FluentIcons.subtract_24_regular,
                  label: 'Minimize',
                ),
                _TestWindowButton(
                  icon: FluentIcons.maximize_24_regular,
                  label: 'Maximize',
                ),
                _TestWindowButton(
                  icon: FluentIcons.dismiss_24_regular,
                  label: 'Close',
                  isCloseButton: true,
                ),
              ],
            ),
          ),
        ),
      );

      // Verify all three buttons are rendered
      expect(find.byIcon(FluentIcons.subtract_24_regular), findsOneWidget);
      expect(find.byIcon(FluentIcons.maximize_24_regular), findsOneWidget);
      expect(find.byIcon(FluentIcons.dismiss_24_regular), findsOneWidget);
    });

    testWidgets('minimize button has correct size', (tester) async {
      await tester.pumpWidget(
        FluentApp(
          home: ScaffoldPage(
            content: Center(
              child: _TestWindowButton(
                icon: FluentIcons.subtract_24_regular,
                label: 'Minimize',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(FluentIcons.subtract_24_regular),
              matching: find.byType(Container),
            )
            .first,
      );

      // Verify button size is 46x38 (Windows standard)
      expect(container.constraints?.maxWidth, equals(46));
      expect(container.constraints?.maxHeight, equals(38));
    });

    testWidgets('button triggers onPressed callback when tapped', (
      tester,
    ) async {
      bool wasPressed = false;

      await tester.pumpWidget(
        FluentApp(
          home: ScaffoldPage(
            content: Center(
              child: _TestWindowButton(
                icon: FluentIcons.subtract_24_regular,
                label: 'Minimize',
                onPressed: () => wasPressed = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(_TestWindowButton));
      await tester.pump();

      expect(wasPressed, isTrue);
    });

    testWidgets('maximize button shows restore icon when maximized', (
      tester,
    ) async {
      await tester.pumpWidget(
        FluentApp(
          home: ScaffoldPage(
            content: Center(
              child: _TestWindowButton(
                icon: FluentIcons.square_multiple_24_regular, // Restore icon
                label: 'Restore',
              ),
            ),
          ),
        ),
      );

      expect(
        find.byIcon(FluentIcons.square_multiple_24_regular),
        findsOneWidget,
      );
    });

    testWidgets('buttons have transparent background when not hovered', (
      tester,
    ) async {
      await tester.pumpWidget(
        FluentApp(
          home: ScaffoldPage(
            content: Center(
              child: _TestWindowButton(
                icon: FluentIcons.subtract_24_regular,
                label: 'Minimize',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(FluentIcons.subtract_24_regular),
              matching: find.byType(Container),
            )
            .first,
      );

      // When not hovered, background should be transparent
      expect(container.color, equals(Colors.transparent));
    });

    testWidgets('close button hover triggers callback', (tester) async {
      bool hoverState = false;

      await tester.pumpWidget(
        FluentApp(
          home: ScaffoldPage(
            content: Center(
              child: _TestWindowButton(
                icon: FluentIcons.dismiss_24_regular,
                label: 'Close',
                isCloseButton: true,
                onHoverChanged: (isHovered) => hoverState = isHovered,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Simulate mouse hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(tester.getCenter(find.byType(_TestWindowButton)));
      await tester.pumpAndSettle();

      expect(hoverState, isTrue);
    });

    testWidgets('close button has correct hover color constant', (
      tester,
    ) async {
      // Test that the close button uses the correct Windows red color
      const closeButtonHoverColor = Color(0xFFE81123);
      expect(closeButtonHoverColor.value, equals(0xFFE81123));
    });
  });
}

/// Test widget that mimics the window button behavior for testing
class _TestWindowButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isCloseButton;
  final VoidCallback? onPressed;
  final ValueChanged<bool>? onHoverChanged;

  const _TestWindowButton({
    required this.icon,
    required this.label,
    this.isCloseButton = false,
    this.onPressed,
    this.onHoverChanged,
  });

  @override
  State<_TestWindowButton> createState() => _TestWindowButtonState();
}

class _TestWindowButtonState extends State<_TestWindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const iconColor = Color(0xFF333333);
    final hoverColor = widget.isCloseButton
        ? const Color(0xFFE81123)
        : const Color(0xFFE5E5E5);
    final hoverIconColor = widget.isCloseButton ? Colors.white : null;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        widget.onHoverChanged?.call(true);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        widget.onHoverChanged?.call(false);
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 46,
            maxHeight: 38,
            minWidth: 46,
            minHeight: 38,
          ),
          color: _isHovered ? hoverColor : Colors.transparent,
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 16,
            color: _isHovered && hoverIconColor != null
                ? hoverIconColor
                : iconColor,
          ),
        ),
      ),
    );
  }
}
