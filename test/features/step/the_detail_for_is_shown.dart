import 'package:flutter_test/flutter_test.dart';

import 'package:porelo_frontend/src/ui/panes.dart';

/// Usage: the detail for {'porelo-checkout-shell'} is shown
Future<void> theDetailForIsShown(WidgetTester tester, String work) async {
  expect(find.byType(WorkDetail), findsOneWidget);
  expect(
    find.descendant(of: find.byType(WorkDetail), matching: find.text(work)),
    findsOneWidget,
  );
}
