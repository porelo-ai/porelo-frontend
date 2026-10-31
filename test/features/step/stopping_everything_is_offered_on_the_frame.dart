import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: stopping everything is offered on the frame
Future<void> stoppingEverythingIsOfferedOnTheFrame(WidgetTester tester) async {
  // On the frame, not in a menu. Somebody reaching for this has realized something is wrong and
  // does not yet know what; a person in that minute does not go hunting through menus. The frame's
  // stop is the rail's, for every machine; one machine's is in the menu of its own page.
  final stop = find.byKey(const Key('stop-everywhere'));
  expect(stop, findsOneWidget);
  expect(tester.widget<TextButton>(stop).onPressed, isNotNull, reason: 'the stop on the frame cannot be pressed');
}
