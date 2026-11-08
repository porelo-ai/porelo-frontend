import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I close the wizard
Future<void> iCloseTheWizard(WidgetTester tester) async {
  await World.tapInView(tester, 'wizard-leave');
  if (find.byKey(const Key('wizard-confirm-leave')).evaluate().isNotEmpty) {
    await World.tapInView(tester, 'wizard-confirm-leave');
  }
  await World.settle(tester);
}
