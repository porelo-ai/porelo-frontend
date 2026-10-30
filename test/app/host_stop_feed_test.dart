import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_stop_feed.dart';
import 'package:porelo_host/porelo_host.dart';

void main() {
  // Harm: accepting a retired stop can install obsolete trust or deliver credentials to an old helper.
  for (final need in ['wireguard', 'forge-certificate', 'forge-password', 'identities', 'forge-central-token']) {
    test('the retired $need stop is refused before a command exists', () {
      for (final act in HostAct.values) {
        expect(
          () => hostStopFeedCommand(
            act: act,
            project: 'demo',
            needs: [need],
            ssh: '/usr/bin/ssh',
            sshOptions: const [],
            host: 'worker@203.0.113.7',
          ),
          throwsFormatException,
          reason: 'no process may receive a retired setup need',
        );
      }
    });
  }
}
