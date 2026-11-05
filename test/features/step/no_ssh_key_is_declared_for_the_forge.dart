import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: no ssh key is declared for the forge
///
/// As Porelo answers it: with no single key declared for the address, the push is not tried at all.
Future<void> noSshKeyIsDeclaredForTheForge(WidgetTester tester) async {
  const address = 'ssh://git@github.com/acme/money.git';
  World.backend
    ..refuseTheKeyFor = address
    ..theKeyRefusal = const <String, dynamic>{
      'outcome': 'NO_CREDENTIAL',
      'address': address,
      'source': '',
      'id': '',
      'fingerprint': '',
      'forge': 'UNKNOWN',
      'command': <String>['porelo', 'credentials', 'keys'],
      'message': 'No single SSH credential is declared for $address; the push was not attempted.',
    };
}
