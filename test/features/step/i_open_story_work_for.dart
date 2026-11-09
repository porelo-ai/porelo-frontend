import 'package:flutter_test/flutter_test.dart';

import '../support/story_work.dart';

/// Usage: I open story work for {story}
Future<void> iOpenStoryWorkFor(WidgetTester tester, String story) async {
  await workTap(tester, 'planning-menu $story');
  await workTap(tester, 'planning-start $story');
}
