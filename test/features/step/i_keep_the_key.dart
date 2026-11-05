import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I keep the key {'SHA256:personalKeyOfThePerson'}
Future<void> iKeepTheKey(WidgetTester tester, String key) async {
  final button = find.byKey(Key('refused-key-keep-$key'));
  await tester.ensureVisible(button);
  await World.settle(tester);
  await tester.tap(button);
  await World.settle(tester);
}
