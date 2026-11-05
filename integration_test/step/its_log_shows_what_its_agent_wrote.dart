import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/log_view.dart';

import '../support/e2e.dart';
import 'work_on_the_test_machine_was_started_with_a_key_its_provider_refuses.dart';

/// Usage: its log shows what its agent wrote
///
/// Read through the machine's `Tail`, as the stub's formatter shows it, from its row's *Read its log*.
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
  final read = find.byKey(const Key('tile-read-log'));
  await pumpUntil(tester, () => read.evaluate().isNotEmpty, timeout: const Duration(seconds: 30), what: 'its log');
  await tester.ensureVisible(read.first);
  await tester.pump();
  await tester.tap(read.first);
  await tester.pump();
  final written = find.descendant(of: find.byType(LogView), matching: find.byType(RichText));
  await pumpUntil(
    tester,
    () => written.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'a line its agent wrote in the log of $refusedTask',
  );
}
