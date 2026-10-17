import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I discard the unfinished setup
Future<void> iDiscardTheUnfinishedSetup(WidgetTester tester) => World.tapInView(tester, 'resume-setup-discard');
