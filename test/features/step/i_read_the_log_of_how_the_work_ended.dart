import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I read the log of how the work ended
Future<void> iReadTheLogOfHowTheWorkEnded(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('ended-read-log')).first);
  await World.settle(tester);
}
