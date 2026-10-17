import 'package:flutter_test/flutter_test.dart';

/// Usage: a machine notice says {'cannot be reached'}
Future<void> aMachineNoticeSays(WidgetTester tester, String words) async {
  expect(_notices(words), findsWidgets);
}

/// Text in a notice about a machine, which is never a tile.
Finder _notices(String words) => find.descendant(
  of: find.byWidgetPredicate((widget) => '${widget.key}'.contains("'machine-notice ")),
  matching: find.textContaining(words, findRichText: true),
);
