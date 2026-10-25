import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: room member removal is unavailable
Future<void> roomMemberRemovalIsUnavailable(WidgetTester tester) async {
  final buttons = find.byWidgetPredicate(
    (widget) =>
        widget is OutlinedButton &&
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith('member-remove '),
  );
  expect(buttons, findsNWidgets(World.backend.membersOf['checkout']!.length));
  for (final button in tester.widgetList<OutlinedButton>(buttons)) {
    expect(button.onPressed, isNull, reason: 'an unavailable method must not be callable again');
  }
}
