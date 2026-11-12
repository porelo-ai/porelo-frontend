import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/attention.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';
import '../step/what_needs_a_person_says_its_provider_refused_it.dart';
import '../step/work_on_the_test_machine_was_started_with_a_key_its_provider_refuses.dart';

/// Usage: the failed task's card stays, with a warning and a Needs-you entry to its result
Future<void> theFailedTasksCardStaysWithAWarningAndANeedsyouEntryToItsResult(WidgetTester tester) => walked(
  tester,
  "12 [failed-card] read: the failed task's card stays, with a warning and a Needs-you entry to its result",
  () async {
    // Its entry under what needs a person, in its provider's words.
    await whatNeedsAPersonSaysItsProviderRefusedIt(tester);
    // Its card kept on the work page, saying its agent ended.
    await toThePlace(tester, 'work');
    final card = find.byKey(ValueKey<String>('tile-state ${Demand.ended.name}'));
    final tile = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('tile ') &&
          (widget.key! as ValueKey<String>).value.endsWith(' $refusedTask'),
    );
    await pumpUntil(
      tester,
      () => find.descendant(of: tile, matching: card).evaluate().isNotEmpty,
      timeout: const Duration(minutes: 2),
      what: 'the card of $refusedTask to stay, saying its agent ended',
    );
  },
);
