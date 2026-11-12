import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';

/// Usage: the window hands the idea in
Future<void> theWindowHandsTheIdeaIn(WidgetTester tester) => walked(tester, '3 the window hands the idea in', () async {
  // The window hands it in by itself once the discussion ended; the planner's answer is the story it names.
  try {
    await pumpUntil(
      tester,
      () => probeHolds(['story-id', Walk.title]),
      timeout: const Duration(minutes: 3),
      what: 'the planner to hold a story titled ${Walk.title}',
    );
  } on TestFailure catch (failure) {
    // What porelo lists of the discussion, the row the window's hand-in is keyed on.
    final rows = (await theProjectsTasks()).where((each) => theContainerOf(each) == Walk.discussion).toList();
    fail('${failure.message}; porelo lists ${Walk.discussion} as $rows');
  }
});
