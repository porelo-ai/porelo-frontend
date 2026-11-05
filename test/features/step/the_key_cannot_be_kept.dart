import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the key {'/home/alice/.ssh/id_locked'} cannot be kept
Future<void> theKeyCannotBeKept(WidgetTester tester, String key) async {
  final keep = tester.widget<ButtonStyleButton>(find.byKey(Key('refused-key-keep-$key')));
  expect(keep.onPressed, isNull, reason: 'a key the machine cannot sign with must not be kept for the address');
}
