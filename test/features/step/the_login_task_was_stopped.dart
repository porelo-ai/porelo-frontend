import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the login task {'porelo-login-an-agent'} was stopped
Future<void> theLoginTaskWasStopped(WidgetTester tester, String task) async {
  expect(World.backend.stops, <String>[task]);
}
