import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/new_person.dart';

/// Usage: I add the machine I was given, knowing only how I log into it
///
/// What a new person knows: the login, `user@host`. Not a socket, not a uid, and no daemon is
/// running there yet: the wizard finds where Porelo is, offers to start it, and watches it.
Future<void> iAddTheMachineIWasGivenKnowingOnlyHowILogIntoIt(WidgetTester tester) async {
  if (!walkingAsANewPerson) return;
  await watchAnotherMachine(tester);
  noteTheWindow(tester, 'the wizard opens');
  await tester.enterText(find.byKey(const Key('machine-name')), E2e.name);
  // Porelo runs there already, set up by somebody else: only connecting to it is offered and wanted.
  await choose(tester, 'machine-admin', 'machine-admin-no');
  await choose(tester, 'machine-kind-choice', 'machine-raise-it');
  await goOnInTheWizard(tester);
  await tester.enterText(find.byKey(const Key('machine-host')), E2e.host);
  await pumpFor(tester);
  noteTheWindow(tester, 'the login typed, and nothing else');
  await tester.tap(find.byKey(const Key('try-it')));
  await pumpUntil(
    tester,
    () =>
        find.byKey(const Key('host-key-accept')).evaluate().isNotEmpty ||
        find.byKey(const Key('trial-result')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the trial or the host key question',
  );
  await trustTheHostKeyIfAsked(tester);
  await pumpUntil(
    tester,
    () => find.byKey(const Key('trial-result')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the trial to say something',
  );
  noteTheWindow(tester, 'tried');
  if (find.byKey(const Key('start-it')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('start-it')));
    await pumpUntil(
      tester,
      () =>
          find.byKey(const Key('start-result')).evaluate().isNotEmpty &&
          !find.text('Trying…').evaluate().isNotEmpty &&
          find.byKey(const Key('trial-result')).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 90),
      what: 'Porelo to be started there and tried again',
    );
    await pumpFor(tester, const Duration(seconds: 1));
    noteTheWindow(tester, 'started');
  }
  final said = tester.widget<SelectableText>(find.byKey(const Key('trial-result'))).data!;
  expect(said, startsWith('Reached Porelo'), reason: said);
  await tester.tap(find.byKey(const Key('watch-it')));
  await untilTheDialogCloses(tester);
}
