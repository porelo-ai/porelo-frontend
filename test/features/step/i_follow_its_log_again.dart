import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I follow its log again
Future<void> iFollowItsLogAgain(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('running-follow-log')));
  await World.settle(tester);
}
