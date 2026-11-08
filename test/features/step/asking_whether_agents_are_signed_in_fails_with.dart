import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: asking whether agents are signed in fails with {'a refusal'}
///
/// `a refusal` is the machine refusing the question; `a lost connection` is the connection gone as it is asked.
Future<void> askingWhetherAgentsAreSignedInFailsWith(WidgetTester tester, String how) async {
  World.backend.signInsFail = how == 'a lost connection'
      ? const VarlinkDisconnected('the tunnel closed')
      : const VarlinkException('org.fuin.porelo.Tasks1.Failed', <String, dynamic>{
          'message': 'the vault could not be read',
        });
}
