import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I leave the wizard while it works
Future<void> iLeaveTheWizardWhileItWorks(WidgetTester tester) async {
  await World.tapInView(tester, 'wizard-leave');
  await World.tapInView(tester, 'wizard-confirm-leave');
}
