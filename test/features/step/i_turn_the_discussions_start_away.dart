import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/discussion_start_dialog.dart';

import '../support/world.dart';

/// Usage: I turn the discussion's Start away
Future<void> iTurnTheDiscussionsStartAway(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(DiscussionStartDialog), matching: find.text('Cancel')));
  await World.settle(tester);
}
