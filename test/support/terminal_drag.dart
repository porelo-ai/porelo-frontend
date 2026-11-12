import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

/// Has the person drag with the main mouse button across the first [length] cells of the top line of [terminal]'s
/// screen, as a copy in it would, and waits out the terminal's own wait for a second tap.
Future<void> dragAcrossTheTopLine(WidgetTester tester, Finder terminal, int length) async {
  final render = tester.state<TerminalViewState>(terminal).renderTerminal;
  final buffer = tester.widget<TerminalView>(terminal).terminal;
  final top = buffer.buffer.height - buffer.viewHeight;
  Offset middle(int x) {
    final size = render.cellSize;
    return render.localToGlobal(render.getOffset(CellOffset(x, top)) + Offset(size.width / 2, size.height / 2));
  }

  final gesture = await tester.startGesture(middle(0), kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
  await gesture.moveTo(middle(length - 1));
  await gesture.up();
  await tester.pump(kDoubleTapTimeout * 2);
}
