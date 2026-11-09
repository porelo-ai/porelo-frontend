import 'package:flutter_test/flutter_test.dart';

import '../support/story_work.dart';

/// Usage: I resolve the story reading with {choice}
Future<void> iResolveTheStoryReadingWith(WidgetTester tester, String choice) =>
    workTap(tester, 'reading-resolve $storyReadingIssue $choice');
