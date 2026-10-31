import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I search the repositories for {'web'}
Future<void> iSearchTheRepositoriesFor(WidgetTester tester, String typed) async {
  // The filter in the header of the forge page's Repositories list.
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
