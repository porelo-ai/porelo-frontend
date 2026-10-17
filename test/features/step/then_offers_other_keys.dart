import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: {'example.org'} then offers other keys
Future<void> thenOffersOtherKeys(WidgetTester tester, String host) async {
  // Between being shown and being confirmed: the machine asks again and records nothing.
  World.backend.hostsOffer[host] = const <HostKey>[
    HostKey(type: 'ssh-ed25519', fingerprint: 'SHA256:somebodyElseEntirelyXXXXXXXXXXXXXXXXXXXXXXX'),
  ];
}
