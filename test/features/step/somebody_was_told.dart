import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: somebody was told {'jira needs a grant for porelo-checkout-shell'}
Future<void> somebodyWasTold(WidgetTester tester, String words) async {
  expect(World.notifier.raised.map((each) => each.body), contains(contains(words)));
}
