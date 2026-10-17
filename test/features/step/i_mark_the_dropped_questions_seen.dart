import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I mark the dropped questions seen
Future<void> iMarkTheDroppedQuestionsSeen(WidgetTester tester) async {
  await tester.tap(
    find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('missed-questions-seen '),
    ),
  );
  await World.settle(tester);
}
