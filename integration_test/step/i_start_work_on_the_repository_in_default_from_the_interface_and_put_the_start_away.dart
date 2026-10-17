import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import 'the_test_machine_has_a_repository_to_work_on.dart';

/// Opens default as the window offers it: Work, "New work", the test machine, "Default" (walk 10:
/// Default is no project listed under Projects any more).
Future<void> openTheDefaultFromWork(WidgetTester tester) async {
  await toThePlace(tester, 'work');
  await tester.tap(find.byKey(const Key('new-work')));
  await pumpFor(tester);
  final machine = find.byKey(ValueKey<String>('new-work-on ${E2e.name}'));
  if (machine.evaluate().isNotEmpty) {
    await tester.tap(machine);
    await pumpFor(tester);
  }
  final inDefault = find.byKey(const ValueKey<String>('new-work-in default'));
  if (inDefault.evaluate().isNotEmpty) {
    await tester.tap(inDefault);
    await pumpFor(tester);
  }
  await pumpUntil(
    tester,
    () =>
        find.byKey(const Key('default-dialog')).evaluate().isNotEmpty &&
        find.text('Asking the machine…').evaluate().isEmpty,
    what: 'default, read from the machine',
  );
}

/// Opens default's repositories, as the window offers them.
Future<void> openTheDefault(WidgetTester tester) async {
  if (find.byKey(const Key('default-dialog')).evaluate().isNotEmpty) return;
  await openTheDefaultFromWork(tester);
}

/// Usage: I start work on the repository {'e2e-default'} in default from the interface, and put the start away
///
/// The way into default: New work under Work, Default, the repository's address, "Start work on it". The start
/// form that follows is put away: what is measured here is the repository going in.
Future<void> iStartWorkOnTheRepositoryInDefaultFromTheInterfaceAndPutTheStartAway(
  WidgetTester tester,
  String name,
) async {
  await openTheDefaultFromWork(tester);
  await tester.enterText(find.byKey(const Key('default-address')), theRepositoryThere!);
  await pumpFor(tester);
  await tester.tap(find.byKey(const Key('default-start-new')));
  await pumpUntil(
    tester,
    () =>
        find.byKey(const Key('start-go')).evaluate().isNotEmpty ||
        find.byKey(const Key('default-problem')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 60),
    what: 'the machine to put $name into default and the start to open',
  );
  expect(find.byKey(const Key('default-problem')), findsNothing);
  await tester.tap(find.widgetWithText(TextButton, 'Not now').last);
  await pumpFor(tester);
}
