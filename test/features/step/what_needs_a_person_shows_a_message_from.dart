import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: what needs a person shows a message from {'porelo-checkout-shell'}
Future<void> whatNeedsAPersonShowsAMessageFrom(WidgetTester tester, String task) async {
  expect(
    find.byWidgetPredicate(
      (each) =>
          each.key is ValueKey<String> &&
          (each.key! as ValueKey<String>).value.startsWith('held-message ') &&
          (each.key! as ValueKey<String>).value.contains('/$task/'),
    ),
    findsOneWidget,
  );
}
