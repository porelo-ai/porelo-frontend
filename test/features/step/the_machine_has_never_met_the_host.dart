import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine has never met the host {'example.org'}
Future<void> theMachineHasNeverMetTheHost(WidgetTester tester, String host) async {
  // GitHub's own published pair, as Porelo measured them.
  World.backend.hostsOffer[host] = const <HostKey>[
    HostKey(type: 'ssh-ed25519', fingerprint: 'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU'),
    HostKey(type: 'ssh-rsa', fingerprint: 'SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s'),
  ];
}
