import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: removal is refused for absent member {'anna'}
Future<void> removalIsRefusedForAbsentMember(WidgetTester tester, String person) async {
  final refusal = find.byKey(const Key('messages-problem'));
  expect(refusal, findsOneWidget, reason: 'an absent member must be refused in its own place');
  expect(tester.widget<Text>(refusal).data, contains(person), reason: 'the refusal must identify the absent person');
  expect(find.byKey(const Key('member-removal-kept')), findsNothing, reason: 'a refusal is not a successful removal');
}
