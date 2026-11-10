import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../../support/expand_list_rows.dart';

/// Usage: I review the work {'porelo-checkout-migrate'} from its tile
///
/// From the row its push at the gate has under *Needs you*, whose one action is the review.
Future<void> iReviewTheWorkFromItsTile(WidgetTester tester, String work) async {
  final open = find.byKey(const Key('open-attention'));
  await expandListRows(tester, within: open);
  final row = find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('attention-row gate ') && key.value.endsWith('/$work');
  });
  final review = find.descendant(
    of: find.descendant(of: open, matching: row),
    matching: find.byKey(const Key('gate-review')),
  );
  expect(review, findsOneWidget, reason: 'no push of $work waits under Needs you');
  await tester.ensureVisible(review);
  await tester.tap(review);
  await World.settle(tester);
}
