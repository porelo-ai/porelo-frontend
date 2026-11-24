import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the review lists {'a, b, c'} in that order
Future<void> theReviewListsInThatOrder(WidgetTester tester, String paths) async {
  final expected = paths.split(',').map((each) => each.trim()).toList();
  // A list builds only what is near its viewport: the last is scrolled to, so every row of it is there to be read.
  final first = find.byKey(ValueKey<String>('review-file ${expected.first}'));
  await tester.scrollUntilVisible(
    find.byKey(ValueKey<String>('review-file ${expected.last}')),
    100,
    scrollable: find.ancestor(of: first, matching: find.byType(Scrollable)).first,
  );
  final rows = find.byWidgetPredicate(
    (each) => each.key is ValueKey<String> && (each.key! as ValueKey<String>).value.startsWith('review-file '),
  );
  final shown = <({String path, double y})>[
    for (final element in rows.evaluate())
      (
        path: ((element.widget.key! as ValueKey<String>).value).substring('review-file '.length),
        y: tester.getTopLeft(find.byWidget(element.widget)).dy,
      ),
  ]..sort((a, b) => a.y.compareTo(b.y));
  expect(shown.map((each) => each.path).toList(), expected);
}
