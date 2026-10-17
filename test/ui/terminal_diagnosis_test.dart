import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/wsl.dart';
import 'package:porelo_frontend/src/ui/terminal_diagnosis.dart';

/// `--diagnose-terminal`: every key and wheel event that reaches the terminal widget is shown and
/// logged, with the bytes the terminal would send, and those bytes are carried into WSL to be read
/// back there.
void main() {
  late Directory place;
  late File log;
  setUp(() {
    place = Directory.systemTemp.createTempSync('diagnose-');
    log = File('${place.path}/porelo-terminal-diagnose.txt');
  });
  tearDown(() => place.deleteSync(recursive: true));

  final wsl = Wsl(run: (arguments) async => (
        code: 0,
        printed: switch (arguments.join(' ')) {
          '-l -q' || '-l --running -q' => 'Ubuntu\n'.codeUnits,
          '-l -v' => '  NAME STATE VERSION\n* Ubuntu Running 2\n'.codeUnits,
          _ => <int>[],
        }
      ));

  testWidgets('a key, the bytes for it, and a wheel turn are shown and written to the log', (tester) async {
    await tester.pumpWidget(MaterialApp(home: TerminalDiagnosis(wsl: wsl, log: log)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('diagnose-key-events-only')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(tester.getCenter(find.byKey(const Key('diagnose-wheel')))));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -40)));
    await tester.pumpAndSettle();

    final written = log.readAsStringSync();
    expect(written, contains('running WSL distributions: Ubuntu'));
    expect(written, contains('input path: key events alone'));
    expect(written, contains('key down: logical Key A'));
    expect(written, contains('character a'));
    expect(written, contains('terminal would send a'));
    expect(written, contains(r'terminal would send \r'));
    expect(written, contains(r'tmux would be sent \e[<64;1;1M'));
    expect(
        find.byWidgetPredicate((widget) => widget is SelectableText && (widget.data ?? '').contains('tmux would be sent')),
        findsOneWidget,
        reason: 'shown on screen as well as written');
  });

  testWidgets('what was typed goes into the chosen distribution and what od read is shown', (tester) async {
    final sent = <({String distribution, List<int> bytes, bool pseudoconsole})>[];
    await tester.pumpWidget(MaterialApp(
      home: TerminalDiagnosis(
        wsl: wsl,
        log: log,
        throughWsl: (distribution, bytes, {required pseudoconsole}) async {
          sent.add((distribution: distribution, bytes: bytes, pseudoconsole: pseudoconsole));
          return '0000000   a  \\r\n0000002\n';
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('diagnose-key-events-only')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.tap(find.byKey(const Key('diagnose-distribution')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubuntu').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('diagnose-through-pseudoconsole')));
    await tester.pumpAndSettle();

    expect(sent.single.distribution, 'Ubuntu');
    expect(sent.single.bytes, <int>[0x61, 0x0d]);
    expect(sent.single.pseudoconsole, isTrue);
    expect(log.readAsStringSync(), contains('od -c read in Ubuntu'));
    expect(log.readAsStringSync(), contains(r'a  \r'));
  });
}
