import 'package:flutter_test/flutter_test.dart';

import '../support/story_work.dart';

/// Usage: I choose story work {choice}
Future<void> iChooseStoryWork(WidgetTester tester, String choice) => chooseWork(tester, choice);
