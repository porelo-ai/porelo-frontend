import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import 'work_on_the_test_machine_was_started_with_a_key_its_provider_refuses.dart';

/// Usage: its tile shows what its agent wrote
///
/// Read through the machine's `Tail` from the end, as the stub's formatter shows it.
Future<void> itsTileShowsWhatItsAgentWrote(WidgetTester tester) async {
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
  final console = find.byKey(const ValueKey<String>('tile-console $refusedTask'));
  await pumpUntil(
    tester,
    () => console.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the console on the tile of $refusedTask',
  );
  final written = find.descendant(of: console, matching: find.byType(RichText));
  await pumpUntil(
    tester,
    () =>
        written.evaluate().isNotEmpty &&
        find.descendant(of: console, matching: find.text('Nothing written yet.')).evaluate().isEmpty,
    timeout: const Duration(seconds: 30),
    what: 'a line its agent wrote on the tile of $refusedTask',
  );
}
