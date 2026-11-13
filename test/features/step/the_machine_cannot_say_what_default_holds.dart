import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine cannot say what default holds
Future<void> theMachineCannotSayWhatDefaultHolds(WidgetTester tester) async {
  World.backend.defaultReadFails = const VarlinkDisconnected('the connection was reset');
}
