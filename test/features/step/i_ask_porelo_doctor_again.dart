import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I ask porelo doctor again
Future<void> iAskPoreloDoctorAgain(WidgetTester tester) async {
  await World.tapInView(tester, 'ask-doctor-again');
}
