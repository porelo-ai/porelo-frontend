import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:porelo_frontend/src/ui/session_terminal.dart';
import 'package:xterm/xterm.dart';

import '../support/terminal_drag.dart';

/// What a session's terminal on screen does with a task's write to the clipboard after the person's drag in it.
///
/// The harm: a task's write taken as the person's copy because it equals the text they dragged across. No program in
/// the task is told of this window's drag, so such a write is a guess, or text the task staged on the screen to be
/// dragged; pasted into a shell later, it runs there.
void main() {
  late CopyToClipboard before;
  late List<String> copied;
  setUp(() {
    before = copyToClipboard;
    copied = <String>[];
    copyToClipboard = (text) async => copied.add(text);
  });
  tearDown(() => copyToClipboard = before);

  const viewKey = Key('the-terminal');

  testWidgets('a write of exactly the text just dragged across is held, and copied only on Copy', (tester) async {
    final channel = _Channel();
    final session = Session(
      task: 'porelo-sluice-dry-sluice',
      machine: const Machine(name: 'laptop', socketPath: ''),
      open: (executable, arguments, {int columns = 80, int rows = 24}) => channel,
    );
    addTearDown(session.leave);
    final controller = TerminalController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                width: 800,
                height: 300,
                child: SessionTerminal(
                  session: session,
                  viewKey: viewKey,
                  theme: TerminalThemes.defaultTheme,
                  controller: controller,
                  textStyle: const TerminalStyle(),
                  padding: EdgeInsets.zero,
                ),
              ),
              TerminalCopyAsk(session: session),
            ],
          ),
        ),
      ),
    );
    // The task has not asked for the mouse, so the drag selects in this window.
    channel.prints('\x1b[2J\x1b[Hcopy me');
    await tester.pump();
    await dragAcrossTheTopLine(tester, find.byKey(viewKey), 'copy me'.length);
    expect(controller.selection, isNotNull, reason: 'the drag selected in this window');

    channel.prints('\x1b]52;c;${base64.encode(utf8.encode('copy me'))}\x07');
    // The output arrives after the first frame; what it changed is drawn in the next.
    await tester.pump();
    await tester.pump();
    expect(copied, isEmpty, reason: 'a write equal to the drag is not the person’s copy');
    expect(session.held?.text, 'copy me');

    await tester.tap(find.byKey(const Key('terminal-copy-allow')));
    await tester.pump();
    expect(copied, <String>['copy me']);
    expect(session.held, isNull);
  });
}

class _Channel implements SessionChannel {
  final StreamController<List<int>> _output = StreamController<List<int>>.broadcast();
  final Completer<int> _ended = Completer<int>();

  void prints(String words) => _output.add(utf8.encode(words));

  void ends() {
    if (!_ended.isCompleted) _ended.complete(0);
  }

  @override
  Stream<List<int>> get output => _output.stream;

  @override
  void send(String input) {}

  @override
  void resize({required int columns, required int rows}) {}

  @override
  Future<int> get ended => _ended.future;

  @override
  Future<void> close() async => ends();
}
