import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: there is a tab for {'porelo-billing-shell'}
Future<void> thereIsATabFor(WidgetTester tester, String work) async {
  expect(
    find.descendant(
      of: find.byKey(const Key('running-tabs')),
      matching: find.byWidgetPredicate(
        (widget) => '${widget.key}'.startsWith("[<'running-tab ") && '${widget.key}'.endsWith("/$work'>]"),
      ),
    ),
    findsOneWidget,
  );
}
