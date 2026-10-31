import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I open the actions for {'porelo-checkout-shell'}
Future<void> iOpenTheActionsFor(WidgetTester tester, String work) async {
  // The menu on its row on the work page: a click on the row opened the work over the list, and
  // that is closed to reach the row again, as a person does.
  final menu = find.byTooltip('What $work can be told to do');
  if (menu.evaluate().isEmpty) {
    await closeWhatCoversThePage(tester);
    await toTheTile(tester, work);
  }
  await tester.ensureVisible(menu.first);
  await tester.pump();
  await tester.tap(menu.first);
  await World.settle(tester);
  expect(find.byType(CommandMenu), findsWidgets);
}
