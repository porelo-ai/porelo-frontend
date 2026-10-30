import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I open {'billing'} on {'this machine'} from the projects page
Future<void> iOpenOnFromTheProjectsPage(WidgetTester tester, String project, String machine) async {
  final row = find.byKey(ValueKey<String>('project $machine/$project'));
  await tester.tap(find.descendant(of: row, matching: find.byType(InkWell)).first);
  await World.settle(tester);
}
