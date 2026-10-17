import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import 'i_start_work_on_the_repository_in_default_from_the_interface_and_put_the_start_away.dart';

/// Usage: I take {'e2e-default'} out of default from the interface
Future<void> iTakeOutOfDefaultFromTheInterface(WidgetTester tester, String name) async {
  // From default's own menu, where taking one out lives.
  await openTheDefault(tester);
  await tester.tap(find.byKey(ValueKey<String>('default-remove $name')));
  await pumpUntil(
    tester,
    () => find.byKey(ValueKey<String>('default-repository $name')).evaluate().isEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the machine to take $name out of default',
  );
  expect(find.textContaining('is out of default'), findsOneWidget);
  await tester.tap(find.byKey(const Key('default-close')));
  await pumpFor(tester);
}
