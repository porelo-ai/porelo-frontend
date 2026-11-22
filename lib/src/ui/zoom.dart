import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Draws [child] at [percent] of its usual size, text and icons alike, as a browser's zoom does: the child is laid
/// out in a space the zoom makes smaller or larger and then scaled to fill the window, so nothing is cut off and a
/// press lands where it is seen.
///
/// The child keeps one place in the tree at every zoom, so a change of zoom loses no state.
class Zoomed extends StatelessWidget {
  /// Takes the zoom and what it draws.
  const Zoomed({super.key, required this.percent, required this.child});

  /// How large everything is drawn, in percent of its usual size.
  final int percent;

  /// What is drawn.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final factor = percent / 100;
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth / factor, box.maxHeight / factor);
        return FittedBox(
          key: const Key('zoomed'),
          fit: BoxFit.fill,
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: size,
            child: MediaQuery(
              data: media.copyWith(
                size: size,
                padding: media.padding / factor,
                viewPadding: media.viewPadding / factor,
                viewInsets: media.viewInsets / factor,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Ctrl+Plus and Ctrl+Minus zoom the window in and out, and Ctrl+0 brings it back to its usual size, as in a
/// browser; the keypad's keys do the same. A terminal that has the keys reads them first, as its program may.
class ZoomKeys extends StatelessWidget {
  /// Takes what each key does and the window it holds the keys for.
  const ZoomKeys({super.key, required this.zoomIn, required this.zoomOut, required this.reset, required this.child});

  /// One step larger.
  final VoidCallback zoomIn;

  /// One step smaller.
  final VoidCallback zoomOut;

  /// The usual size.
  final VoidCallback reset;

  /// The window.
  final Widget child;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      // A plus is typed with Shift on some keyboards and without it on others.
      for (final shift in [false, true]) ...{
        SingleActivator(LogicalKeyboardKey.equal, control: true, shift: shift): zoomIn,
        SingleActivator(LogicalKeyboardKey.add, control: true, shift: shift): zoomIn,
      },
      const SingleActivator(LogicalKeyboardKey.numpadAdd, control: true): zoomIn,
      const SingleActivator(LogicalKeyboardKey.minus, control: true): zoomOut,
      const SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true): zoomOut,
      const SingleActivator(LogicalKeyboardKey.digit0, control: true): reset,
      const SingleActivator(LogicalKeyboardKey.numpad0, control: true): reset,
    },
    child: child,
  );
}
