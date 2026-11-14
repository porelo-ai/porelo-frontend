import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/porelo_planning.dart';

/// Usage: the planning page has its i
Future<void> thePlanningPageHasItsI(WidgetTester tester) async {
  final info = find.byKey(const ValueKey<String>('explanation-open planning'));
  expect(find.descendant(of: find.byType(PlanningScreen), matching: info), findsOneWidget);
}
