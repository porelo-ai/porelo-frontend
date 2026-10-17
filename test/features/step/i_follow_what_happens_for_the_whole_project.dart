import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I follow what happens for the whole project
Future<void> iFollowWhatHappensForTheWholeProject(WidgetTester tester) => World.tapInView(tester, 'talk-whole-project');
