import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I agree to the first task
Future<void> iAgreeToTheFirstTask(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('first-start-yes')));
  await World.settle(tester);
}
