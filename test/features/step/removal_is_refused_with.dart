import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: removal is refused with {'The transport refused.'}
Future<void> removalIsRefusedWith(WidgetTester tester, String message) async {
  final refusal = find.byKey(const Key('messages-problem'));
  expect(refusal, findsOneWidget, reason: 'a refusal needs its own place');
  expect(tester.widget<Text>(refusal).data, contains(message), reason: 'the daemon refusal must reach the person');
  expect(find.byKey(const Key('member-removal-kept')), findsNothing, reason: 'a refusal is not a successful removal');
}
