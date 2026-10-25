import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/expand_list_rows.dart';

/// Usage: what needs a person shows no message
Future<void> whatNeedsAPersonShowsNoMessage(WidgetTester tester) async {
  await expandListRows(tester);
  expect(
    find.descendant(
      of: find.byKey(const Key('open-attention')),
      matching: find.byWidgetPredicate(
        (each) => each.key is ValueKey<String> && (each.key! as ValueKey<String>).value.startsWith('held-message '),
      ),
    ),
    findsNothing,
  );
}
