import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the forge's repository {'acme/api'} is not listed
Future<void> theForgesRepositoryIsNotListed(WidgetTester tester, String name) async {
  expect(find.byWidgetPredicate((widget) => '${widget.key}'.startsWith("[<'forge-page ")), findsOneWidget);
  expect(find.byKey(ValueKey<String>('repository $name')), findsNothing);
}
