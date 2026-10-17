import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the screen of {'porelo-billing-shell'} was asked for at most {3} times
Future<void> theScreenOfWasAskedForAtMostTimes(WidgetTester tester, String work, int times) async {
  expect(World.backend.screensAsked[work] ?? 0, lessThanOrEqualTo(times));
  expect(World.backend.screensAsked[work] ?? 0, greaterThan(0));
}
