import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/attention_view.dart';

/// Usage: no tile says {'Cannot be reached'}
Future<void> noTileSays(WidgetTester tester, String words) async {
  expect(find.descendant(of: find.byType(TaskTile), matching: find.textContaining(words)), findsNothing);
}
