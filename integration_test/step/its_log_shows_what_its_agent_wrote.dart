import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/log_view.dart';

import '../support/e2e.dart';
import 'work_on_the_test_machine_was_started_with_a_key_its_provider_refuses.dart';

/// Usage: its log shows what its agent wrote
///
/// Read through the machine's `Tail`, as the stub's formatter shows it, by its row's way to the log.
Future<void> itsLogShowsWhatItsAgentWrote(WidgetTester tester) async {
  await toThePlace(tester, 'work');
  // The list and not *Running*, which is where the page stands if it was left there.
  final list = find.byKey(const Key('work-view-list'));
  if (list.evaluate().isNotEmpty) {
    await tester.tap(list);
    await tester.pump();
  }
  // A row is folded until it is opened, and reads nothing until then. One past the window's edge is not
  // drawn at all, so it is scrolled to.
  final fold = find.byKey(const ValueKey<String>('tile-fold $refusedTask'));
  final page = find.descendant(of: find.byKey(const Key('work-page')), matching: find.byType(Scrollable));
  await pumpUntil(
    tester,
    () {
      if (fold.evaluate().isEmpty && page.evaluate().isNotEmpty) {
        final position = tester.state<ScrollableState>(page.first).position;
        final next = position.pixels + 200;
        position.jumpTo(next > position.maxScrollExtent ? 0 : next);
      }
      return fold.evaluate().isNotEmpty;
    },
    timeout: const Duration(seconds: 30),
    what: 'the row of $refusedTask',
  );
  await tester.ensureVisible(fold.first);
  await tester.pump();
  await tester.tap(fold.first);
  await tester.pump();
  // *Follow its log* while its task still runs, *Read its log* once it has stopped; of this row, as
  // another may stand open.
  final row = find.byElementPredicate((element) {
    final key = '${element.widget.key}';
    return key.contains("'tile ") && key.endsWith(" $refusedTask'>]");
  });
  final follow = find.descendant(of: row, matching: find.byKey(const Key('tile-follow')));
  final read = find.descendant(of: row, matching: find.byKey(const Key('tile-read-log')));
  await pumpUntil(
    tester,
    () => follow.evaluate().isNotEmpty || read.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the way to its log',
  );
  final way = follow.evaluate().isNotEmpty ? follow : read;
  await tester.ensureVisible(way.first);
  await tester.pump();
  await tester.tap(way.first);
  await tester.pump();
  // Each line is a SelectableText; the head and the words of an empty log are not.
  final written = find.descendant(of: find.byType(LogView), matching: find.byType(SelectableText));
  await pumpUntil(
    tester,
    () => written.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'a line its agent wrote in the log of $refusedTask',
  );
}
