import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/discussion_start_dialog.dart';

/// Usage: the discussion's Start says {words}
Future<void> theDiscussionsStartSays(WidgetTester tester, String words) async {
  expect(find.descendant(of: find.byType(DiscussionStartDialog), matching: find.textContaining(words)), findsOneWidget);
}
