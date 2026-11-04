import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: what {'porelo-billing-shell'} used was not asked for
Future<void> whatUsedWasNotAskedFor(WidgetTester tester, String work) async {
  expect(World.backend.usageAsked[work], isNull);
}
