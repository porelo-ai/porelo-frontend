import 'package:flutter_test/flutter_test.dart';

import 'i_store_the_credential_from_the_start.dart';
import '../support/world.dart';

/// Usage: I use the sign-in found on the machine
Future<void> iUseTheSigninFoundOnTheMachine(WidgetTester tester) async {
  askedBeforeStoring = World.backend.canStartAsked;
  await World.tapInView(tester, 'start-import');
}
