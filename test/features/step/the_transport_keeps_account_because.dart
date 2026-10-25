import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the transport keeps account {'@anna:localhost'} because {'Used elsewhere.'}
Future<void> theTransportKeepsAccountBecause(WidgetTester tester, String user, String why) async {
  World.backend.retainedMessageAccounts[user] = why;
}
