import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the login stores what {'an-agent'} signed in with
Future<void> theLoginStoresWhatSignedInWith(WidgetTester tester, String agent) async {
  World.backend.readinessOf.remove(agent);
}
