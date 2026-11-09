import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';

/// Usage: I sign in to the agent of the first carried repository from New work
Future<void> iSignInToTheAgentOfTheFirstCarriedRepositoryFromNewWork(WidgetTester tester) => pictured(tester, () async {
  final carried = await theCarriedRepositories();
  expect(carried, isNotEmpty, reason: 'the host carries a repository of ${Rehearsal.project}');
  // The agents the host says are not signed in, before the window asks: the one it signs in is among them.
  Rehearsal.notSignedIn = await theAgentsNotSignedInOnTheHost();
  await toTheProjectOnTheHost(tester);
  await chooseFromTheMenu(
    tester,
    find.byKey(Key('repository-menu ${carried.first}')),
    'Start work in ${carried.first}',
  );
  // The form asks the host whether its agent is signed in; the sign-in is offered, and pressable, only once it has.
  final signIn = find.byKey(const Key('start-sign-in-button'));
  final anyway = find.byKey(const Key('start-sign-in-anyway'));
  final go = find.byKey(const Key('start-go'));
  bool pressable(Finder button) =>
      button.evaluate().isNotEmpty && tester.widget<ButtonStyleButton>(button.first).onPressed != null;
  await pumpUntil(
    tester,
    () => pressable(signIn) || pressable(go) || anyway.evaluate().isNotEmpty,
    timeout: const Duration(minutes: 2),
    what: 'the form to say whether the agent is signed in',
  );
  if (!pressable(signIn)) {
    // Its browser login is the person's, so a host whose agent is signed in, or holds a sign-in of its own, has
    // none for the rehearsal to drive.
    return notRunBecause(
      'the agent of ${carried.first} on ${Rehearsal.hostName} is signed in, or holds a sign-in of its own, '
      'so there is no sign-in to drive',
    );
  }
  await tester.ensureVisible(signIn.first);
  await tester.tap(signIn.first);
  await pumpFor(tester);
});
