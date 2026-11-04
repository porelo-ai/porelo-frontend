import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I leave the session
///
/// By going elsewhere on the page: a session has no way out of its own.
Future<void> iLeaveTheSession(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('work-view-list')));
  await World.settle(tester);
}
