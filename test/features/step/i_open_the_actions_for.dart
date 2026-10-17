import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';

import '../support/world.dart';

/// Usage: I open the actions for {'porelo-checkout-shell'}
Future<void> iOpenTheActionsFor(WidgetTester tester, String work) async {
  await tester.tap(find.byTooltip('What $work can be told to do'));
  await World.settle(tester);
  expect(find.byType(CommandMenu), findsWidgets);
}
