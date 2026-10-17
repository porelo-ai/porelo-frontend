import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import '../support/e2e.dart';

/// Usage: I store a token for {'https://e2e-typed.invalid/'} by typing it into a terminal on the machine
Future<void> iStoreATokenForByTypingItIntoATerminalOnTheMachine(WidgetTester tester, String match) async {
  await openTheConnectionWizard(tester);
  await tester.enterText(find.byKey(const Key('connection-match')), match);
  await choose(tester, 'connection-kind', 'kind-TOKEN');
  await tester.tap(find.byKey(const Key('wizard-next')));
  await pumpUntilShown(tester, const Key('connection-way'));
  await choose(tester, 'connection-way', 'way-vault');
  await tester.tap(find.byKey(const Key('wizard-next')));
  await untilTheMachineChecked(tester);
  await tester.tap(find.byKey(const Key('connection-add')));
  await pumpUntil(
    tester,
    () => find.byKey(const Key('unlock-terminal')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the terminal on the machine',
  );
  // Typed the way a keyboard types into it: into the terminal, whose bytes go to ssh and on to
  // `vault put`. The interface never holds the value in a field of its own.
  await pumpFor(tester, const Duration(seconds: 3));
  final terminal = tester.widget<TerminalView>(find.byKey(const Key('unlock-terminal'))).terminal;
  terminal.textInput('e2e-typed-token');
  terminal.keyInput(TerminalKey.enter);
  await pumpUntil(
    tester,
    () => find.byKey(const Key('unlock-ended')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'vault put to end',
  );
  final ended = tester.widget<Text>(find.byKey(const Key('unlock-ended'))).data!;
  debugPrint('the terminal ended with: $ended');
  // vault put succeeded, so no code is named: an ssh forward running beside it once made this -1.
  expect(ended, isNot(contains('ended with')), reason: ended);
  await tester.tap(find.byKey(const Key('unlock-done')));
  await pumpFor(tester);
}
