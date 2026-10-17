import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the push moves before it is forwarded
///
/// The task pushed again while its push was being read: the machine refuses the forward, typed.
Future<void> thePushMovesBeforeItIsForwarded(WidgetTester tester) async {
  World.backend.refuseTheGate = const VarlinkException('org.fuin.porelo.Tasks1.MovedSinceReview',
      <String, dynamic>{'name': 'migrate', 'reviewed': '9a3c1f2', 'now': 'b7e21d40c9'});
}
