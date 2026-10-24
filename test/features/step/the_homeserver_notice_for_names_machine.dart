import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the homeserver notice for {'checkout'} names machine {'vm'}
Future<void> theHomeserverNoticeForNamesMachine(WidgetTester tester, String project, String machine) async {
  final row = find.descendant(
    of: find.byKey(const Key('open-attention')),
    matching: find.byKey(ValueKey<String>('homeserver-unforwarded $machine/$project')),
  );
  expect(row, findsOneWidget);
  final line = find.descendant(of: row, matching: find.byKey(const Key('needs-machine')));
  expect(tester.widget<Text>(line).data, 'on $machine', reason: 'the failed forward names its own machine');
}
