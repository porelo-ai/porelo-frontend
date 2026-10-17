import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: the interface says it is following it
Future<void> theInterfaceSaysItIsFollowingIt(WidgetTester tester) async {
  final problem = find.byKey(const Key('follow-problem'));
  expect(problem, findsNothing, reason: problem.evaluate().isEmpty ? '' : tester.widget<Text>(problem).data);
  expect(tester.widget<Text>(find.byKey(const Key('follow-says'))).data, startsWith('Following'));
  await tester.tap(find.byKey(const Key('follow-done')));
  // Going to it asks the machine for its projects again first, and only then chooses this one:
  // on a slow runner that is well past one frame, so the project's own header is waited for.
  await pumpUntil(
    tester,
    () => find.byKey(const Key('project-menu')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the project it made to be chosen',
  );
}
