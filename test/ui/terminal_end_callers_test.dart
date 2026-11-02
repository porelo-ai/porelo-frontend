import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/forge_connection.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/ui/forges_view.dart';
import 'package:porelo_frontend/src/ui/host_key_dialog.dart';
import 'package:porelo_frontend/src/ui/unlock_terminal.dart';

import '../features/support/world.dart' show FakeForge, World;

/// A terminal whose program does its work and ends with [code] only while the terminal closes, as one put away at the
/// moment it finished does; none, as one whose end was never seen.
class _EndsOnClose implements SessionChannel {
  _EndsOnClose(this.code, {this.onClose});

  /// What it ends with, or null for an end never seen.
  final int? code;

  /// What the program did before it ended.
  final void Function()? onClose;

  final _output = StreamController<List<int>>.broadcast();
  final _ended = Completer<int>();

  @override
  Stream<List<int>> get output => _output.stream;

  @override
  void send(String input) {}

  @override
  void resize({required int columns, required int rows}) {}

  @override
  Future<int> get ended => _ended.future;

  @override
  Future<void> close() async {
    onClose?.call();
    if (code case final code? when !_ended.isCompleted) _ended.complete(code);
  }
}

Future<void> _putAway(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('unlock-cancel')));
  await World.settle(tester);
  await tester.tap(find.byKey(const Key('unlock-cancel-yes')));
  await World.settle(tester);
}

void main() {
  // Harm: a Scaleway key Scaleway accepted and kept as its terminal closed taken as refused, so the host setup asks for
  // it again although it is kept; or one refused, or put away unseen, taken as kept.
  for (final (code, kept) in [(0, true), (1, false), (null, false)]) {
    testWidgets('a provider key ending with $code while its terminal closes is taken as accepted: $kept', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      bool? accepted;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => accepted = await openHostKeyDialog(
                context,
                open: (executable, arguments, {columns = 80, rows = 24}) => _EndsOnClose(code),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await World.settle(tester);

      await _putAway(tester);

      expect(accepted, kept, reason: 'the program ended with $code while its terminal closed');
    });
  }

  // Harm: a forge token stored as its terminal closed taken as cancelled, so the forge is never added; or a failed or
  // cancelled store taken as done.
  for (final (code, connects) in [(0, true), (1, false), (null, false)]) {
    testWidgets('a forge token stored by a program ending with $code as its terminal closes connects: $connects', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tokens = MemoryForgeTokens();
      final forges = ForgeConnection(
        tokens,
        forgeFor: (token, _) => FakeForge()..tokensTried.add(token),
        openTerminal: (executable, arguments, {int columns = 80, int rows = 24}) =>
            _EndsOnClose(code, onClose: () => unawaited(tokens.write(arguments.last, 'ghp_accepted'))),
      );
      addTearDown(forges.dispose);
      var said = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgeForm(useToken: true, forges: forges, onDone: (words) => said = words),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('forge-address')), 'git.example.org');
      final connect = find.byKey(const Key('forge-connect'));
      await tester.ensureVisible(connect);
      await tester.tap(connect);
      await World.settle(tester);

      await _putAway(tester);

      expect(
        said,
        connects ? contains('is set up') : isNot(contains('is set up')),
        reason: 'the program ended with $code while its terminal closed',
      );
    });
  }

  // Harm: a terminal whose navigator went away while it was open never returning to its caller, so whatever the caller
  // holds for it, a running mark or a card copy, stays held for good.
  testWidgets('a terminal whose navigator goes away returns to its caller with its end', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TerminalEnd? returned;
    var letGo = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              try {
                returned = await runInATerminal(
                  context,
                  title: 'Run',
                  explanation: 'It runs.',
                  machine: Machine.local(),
                  command: const ['true'],
                  open: (executable, arguments, {columns = 80, rows = 24}) => _EndsOnClose(3),
                );
              } finally {
                letGo = true;
              }
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await World.settle(tester);
    expect(find.byKey(const Key('unlock-terminal')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await World.settle(tester);

    expect(letGo, isTrue, reason: 'the caller’s own end ran');
    expect(returned, (started: true, code: 3));
  });

  // Harm: a program that ended while its terminal closed never told to the caller that waits on its exit, so what it
  // did is taken as never done.
  testWidgets('an exit seen while the terminal closes reaches its exit callback', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final exits = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => runInATerminal(
              context,
              title: 'Run',
              explanation: 'It runs.',
              machine: Machine.local(),
              command: const ['true'],
              open: (executable, arguments, {columns = 80, rows = 24}) => _EndsOnClose(4),
              onExit: exits.add,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await World.settle(tester);

    await _putAway(tester);

    expect(exits, [4]);
  });
}
