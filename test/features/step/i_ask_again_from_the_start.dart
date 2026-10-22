import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import 'i_store_the_credential_from_the_start.dart';

/// Usage: I ask again from the start
Future<void> iAskAgainFromTheStart(WidgetTester tester) async {
  askedBeforeStoring = World.backend.canStartAsked;
  await World.tapInView(tester, 'start-ask-again');
}
