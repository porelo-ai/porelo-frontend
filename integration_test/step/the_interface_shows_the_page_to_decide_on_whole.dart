import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import 'the_test_machine_has_an_entry_a_standin_service_grants.dart';

/// Usage: the interface shows the page to decide on, whole
Future<void> theInterfaceShowsThePageToDecideOnWhole(WidgetTester tester) async {
  final link = find.byKey(const Key('grant-link'));
  await pumpUntil(
    tester,
    () => link.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the machine to answer with the page',
  );
  // The stand-in's own page, as it answered it: nothing assembled or shortened on the way.
  expect(tester.widget<SelectableText>(link).data, 'http://127.0.0.1:$standInPort/activate?user_code=WDJB-MJHT');
  expect(find.text('WDJB-MJHT'), findsOneWidget);
  expect(find.byKey(const Key('grant-waiting')), findsOneWidget);
}
