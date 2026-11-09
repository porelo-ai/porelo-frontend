import 'package:flutter_test/flutter_test.dart';

import '../support/story_work.dart';

/// Usage: story work is prepared with {condition}
Future<void> storyWorkIsPreparedWith(WidgetTester tester, String condition) => prepareWork(tester, condition);
