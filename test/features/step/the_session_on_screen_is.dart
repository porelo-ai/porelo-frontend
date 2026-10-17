import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the session on screen is {'porelo-billing-audit'}
Future<void> theSessionOnScreenIs(WidgetTester tester, String task) async {
  expect(World.sessions.current?.task, task);
  expect(find.byKey(const Key('terminal')), findsOneWidget);
  expect(find.textContaining(task), findsWidgets);
}
