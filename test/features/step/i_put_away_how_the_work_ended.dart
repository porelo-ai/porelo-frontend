import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I put away how the work ended
Future<void> iPutAwayHowTheWorkEnded(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('ended-put-away')).first);
  await World.settle(tester);
}
