import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: there is no field to type into
Future<void> thereIsNoFieldToTypeInto(WidgetTester tester) async {
  expect(find.byType(TextField), findsNothing);
}
