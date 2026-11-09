import 'package:flutter_test/flutter_test.dart';

import '../support/story_work.dart';

/// Usage: story work proves {proof}
Future<void> storyWorkProves(WidgetTester tester, String proof) => proveWork(tester, proof);
