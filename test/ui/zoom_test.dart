import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/zoom.dart';

/// How wide [finder] is drawn on the screen, after every scale above it.
double _drawnWidth(WidgetTester tester, Finder finder) =>
    tester.getBottomRight(finder).dx - tester.getTopLeft(finder).dx;

void main() {
  // Harm: at a zoom the window is drawn larger than it is laid out, so a press lands beside what is seen, or the keys
  // do nothing.
  testWidgets('Ctrl+Plus draws everything larger, and a press still lands on what is seen', (tester) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var percent = 100;
    var pressed = 0;
    late StateSetter set;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          set = setState;
          return MaterialApp(
            builder: (context, child) => ZoomKeys(
              zoomIn: () => set(() => percent = 150),
              zoomOut: () => set(() => percent = 90),
              reset: () => set(() => percent = 100),
              child: Zoomed(percent: percent, child: child!),
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomRight,
                child: FilledButton(autofocus: true, onPressed: () => pressed++, child: const Text('Press')),
              ),
            ),
          );
        },
      ),
    );
    final before = _drawnWidth(tester, find.text('Press'));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(percent, 150);
    expect(_drawnWidth(tester, find.text('Press')), closeTo(before * 1.5, 0.5));
    expect(tester.getBottomRight(find.byType(FilledButton)).dx, closeTo(1280, 0.5), reason: 'nothing is cut off');
    await tester.tap(find.text('Press'));
    expect(pressed, 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(percent, 100);
    expect(_drawnWidth(tester, find.text('Press')), closeTo(before, 0.5));
  });
}
