import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import 'i_start_work_on_the_repository_in_default_from_the_interface_and_put_the_start_away.dart';
import '../support/new_person.dart';
import 'the_test_machine_has_a_repository_to_work_on.dart';

/// Usage: I start work on it in default, as the window offers
///
/// The row the overview lists first, its start tile, the repository's address, and "Start work on
/// it": the repository goes into default on the way.
Future<void> iStartWorkOnItInDefaultAsTheWindowOffers(WidgetTester tester) async {
  if (!walkingAsANewPerson) return;
  // Work without a project starts under Work (walk 10: Default left Projects).
  await openTheDefaultFromWork(tester);
  noteTheWindow(tester, 'default, which repository');
  await tester.enterText(find.byKey(const Key('default-address')), theRepositoryThere!);
  await pumpFor(tester);
  await tester.tap(find.byKey(const Key('default-start-new')));
  await pumpUntil(
    tester,
    () =>
        find.byKey(const Key('start-agent')).evaluate().isNotEmpty ||
        find.byKey(const Key('start-no-agents')).evaluate().isNotEmpty ||
        find.byKey(const Key('default-problem')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 60),
    what: 'the start to open',
  );
  await pumpFor(tester, const Duration(seconds: 3));
  noteTheWindow(tester, 'starting work, as it opens');
}
