import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: no tile says {'Cannot be reached'}
Future<void> noTileSays(WidgetTester tester, String words) async {
  expect(find.descendant(of: workRows(), matching: find.textContaining(words)), findsNothing);
  expect(find.descendant(of: causeRows(), matching: find.textContaining(words)), findsNothing);
}
