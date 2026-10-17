import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import '../support/e2e.dart';
import '../support/new_person.dart';

/// Usage: I make the vault, choosing its passphrase in the terminal the interface opens
///
/// From the machine's header, where a missing store is marked. The passphrase is made up here and
/// typed into the terminal only, as a person types it: it is a test account's, emptied each walk.
Future<void> iMakeTheVaultChoosingItsPassphraseInTheTerminalTheInterfaceOpens(WidgetTester tester) async {
  if (!walkingAsANewPerson) return;
  final make = find.byKey(const Key('vault-act'));
  await pumpUntil(tester, () => make.evaluate().isNotEmpty, what: 'the store marked in the header');
  await pumpFor(tester, const Duration(seconds: 2));
  final said = tester.widget<Tooltip>(find.ancestor(of: make, matching: find.byType(Tooltip)).first).message;
  noteTheWindow(tester, 'before the store, its mark says: $said');
  await tester.tap(make);
  await pumpUntil(
    tester,
    () => find.byKey(const Key('unlock-terminal')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the terminal on the machine',
  );
  await pumpFor(tester, const Duration(seconds: 3));
  noteTheWindow(tester, 'the terminal opened');
  final random = Random.secure();
  final passphrase = List<String>.generate(24, (_) => 'abcdefghijkmnpqrstuvwxyz23456789'[random.nextInt(32)]).join();
  final terminal = tester.widget<TerminalView>(find.byKey(const Key('unlock-terminal'))).terminal;
  for (var time = 0; time < 2; time++) {
    terminal.textInput(passphrase);
    terminal.keyInput(TerminalKey.enter);
    await pumpFor(tester, const Duration(seconds: 2));
  }
  await pumpUntil(
    tester,
    () => find.byKey(const Key('unlock-ended')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 60),
    what: 'the store to be made',
  );
  noteTheWindow(tester, 'the terminal ended');
  final ended = tester.widget<Text>(find.byKey(const Key('unlock-ended'))).data!;
  expect(ended, isNot(contains('ended with')), reason: ended);
  await tester.tap(find.byKey(const Key('unlock-done')));
  await pumpFor(tester, const Duration(seconds: 2));
}
