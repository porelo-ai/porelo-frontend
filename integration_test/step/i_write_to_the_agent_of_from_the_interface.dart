import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: I write {'stop, the schema changed'} to the agent of {'porelo-e2e-talk-e2e-talk'} from the interface
Future<void> iWriteToTheAgentOfFromTheInterface(WidgetTester tester, String words, String task) async {
  // The message dialog is closed first, and the task is acted on from its tile's menu, as a person
  // would: its machine, then its project.
  if (find.byKey(const Key('held-message-close')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('held-message-close')));
    await pumpFor(tester);
  }
  // Every machine's work is on the work page.
  await toThePlace(tester, 'work');
  final tile = find.byWidgetPredicate(
    (widget) => widget is Card && '${widget.key}'.contains("'tile ") && '${widget.key}'.endsWith(" $task'>]"),
  );
  final page = find.descendant(of: find.byKey(const Key('work-page')), matching: find.byType(Scrollable));
  for (var i = 0; i < 40 && tile.evaluate().isEmpty && page.evaluate().isNotEmpty; i++) {
    await tester.drag(page.first, const Offset(0, -120));
    await pumpFor(tester, const Duration(milliseconds: 100));
  }
  if (tile.evaluate().isNotEmpty) await tester.ensureVisible(tile.first);
  await pumpFor(tester);
  expect(tile, findsOneWidget, reason: 'no tile of $task on any machine');
  // Keyed by its work, so each tile's menu can be told apart.
  await tester.tap(find.descendant(of: tile, matching: find.byKey(ValueKey<String>('tile-menu $task'))));
  await pumpFor(tester);
  final item = find.ancestor(
    of: find.text('Write to its agent'),
    matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
  );
  // The menu is taller than a 720-pixel window when the tile sits low (CI's leased machine, run
  // 36884349003): scrolled inside the menu until the entry can be pressed, not only made "visible".
  await pumpFor(tester);
  final menu = find.ancestor(of: item, matching: find.byType(Scrollable));
  if (item.hitTestable().evaluate().isEmpty && menu.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(item.hitTestable(), 60, scrollable: menu.first);
    await pumpFor(tester);
  }
  await tester.tap(item.hitTestable());
  await pumpFor(tester);
  await tester.enterText(find.byKey(const Key('words')), words);
  await tester.pump();
  await tester.tap(find.byKey(const Key('words-confirm')));
  await pumpUntil(
    tester,
    () => find.textContaining('Written into the inbox of $task').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the machine to write it',
  );
}
