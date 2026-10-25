import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the room still displays member {'anna'}
Future<void> theRoomStillDisplaysMember(WidgetTester tester, String person) async {
  expect(
    find.byKey(ValueKey<String>('member $person')),
    findsOneWidget,
    reason: 'a refusal must not optimistically remove a member from the last confirmed list',
  );
}
