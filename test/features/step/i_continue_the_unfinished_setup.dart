import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I continue the unfinished setup
Future<void> iContinueTheUnfinishedSetup(WidgetTester tester) => World.tapInView(tester, 'resume-setup-continue');
