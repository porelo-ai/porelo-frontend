import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';

/// Usage: I start work on the first carried repository of the project
Future<void> iStartWorkOnTheFirstCarriedRepositoryOfTheProject(WidgetTester tester) => pictured(tester, () async {
  final carried = await theCarriedRepositories();
  expect(carried, isNotEmpty, reason: 'the host carries a repository of ${Rehearsal.project}');
  final repository = carried.first;
  Rehearsal.startedRepository = repository;
  await toTheProjectOnTheHost(tester);
  await chooseFromTheMenu(tester, find.byKey(Key('repository-menu $repository')), 'Start work in $repository');
  // The form asks the machine before Start is offered: whether it can start, the sign-in, the model.
  final go = find.byKey(const Key('start-go'));
  await pumpUntil(
    tester,
    () => go.evaluate().isNotEmpty && tester.widget<ButtonStyleButton>(go.first).onPressed != null,
    timeout: const Duration(minutes: 2),
    what: 'the form to offer Start',
  );
  Rehearsal.startedName = theFieldsText(tester, const Key('start-name'));
  Rehearsal.startedModel = theFieldsText(tester, const Key('start-model'));
  await tester.tap(go.first);
  await pumpFor(tester);
  await pumpUntil(
    tester,
    () => go.evaluate().isEmpty,
    timeout: const Duration(minutes: 10),
    what: 'the start to finish',
  );
});
