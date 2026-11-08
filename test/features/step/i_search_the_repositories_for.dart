import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I search the repositories for {'web'}
Future<void> iSearchTheRepositoriesFor(WidgetTester tester, String typed) async {
  // The leaf head keeps its repository filter in sight.
  final filter = find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        '${widget.key}'.startsWith("[<'forge-repositories ") &&
        '${widget.key}'.endsWith("-filter'>]"),
  );
  expect(filter, findsOneWidget, reason: 'the filter of the Repositories list');
  await tester.enterText(filter, typed);
  await World.settle(tester);
}
