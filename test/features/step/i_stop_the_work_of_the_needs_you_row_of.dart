import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I stop the work of the Needs you row of {issue}
Future<void> iStopTheWorkOfTheNeedsYouRowOf(WidgetTester tester, String issue) async {
  for (final key in <String>['story-work-stop $issue', 'story-work-stop-confirm']) {
    final control = find.byKey(Key(key));
    await tester.ensureVisible(control);
    await tester.tap(control);
    await World.settle(tester);
  }
}
