import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I answer in Needs you
Future<void> iAnswerInNeedsYou(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('running-answer')));
  await World.settle(tester);
}
