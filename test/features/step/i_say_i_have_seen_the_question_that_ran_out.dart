import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I say I have seen the question that ran out
Future<void> iSayIHaveSeenTheQuestionThatRanOut(WidgetTester tester) async {
  final seen = find.byKey(const Key('ran-out-seen')).first;
  await tester.ensureVisible(seen);
  await World.settle(tester);
  await tester.tap(seen);
  await World.settle(tester);
}
