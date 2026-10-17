import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine will refuse the next file with {'NotRunning'}
Future<void> theMachineWillRefuseTheNextFileWith(WidgetTester tester, String refusal) async {
  // What each refusal carries, as the contract names it.
  final parameters = switch (refusal) {
    'NotRunning' => <String, dynamic>{'task': 'porelo-checkout-shell'},
    'FileNameRefused' => <String, dynamic>{'name': 'notes.txt', 'reason': 'a name already taken by Porelo'},
    'HandInInProgress' => <String, dynamic>{'name': 'notes.txt', 'received': 1048576, 'bytes': 4194304},
    'FileDiffers' => <String, dynamic>{'expected': 'aa', 'actual': 'bb'},
    _ => <String, dynamic>{},
  };
  World.backend.refuseTheHandIn = VarlinkException('org.fuin.porelo.Tasks1.$refusal', parameters);
}
