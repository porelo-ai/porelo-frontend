import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_stop_feed.dart';
import 'package:porelo_host/porelo_host.dart';

void main() {
  List<String> feed(String host) => hostStopFeedCommand(
    act: HostAct.ownAccount,
    project: 'demo',
    needs: const ['vault'],
    ssh: '/usr/bin/ssh',
    sshOptions: const [],
    host: host,
  );

  // Harm: a host a card may name is refused here alone, or something ssh would read otherwise reaches it.
  for (final host in ['worker@203.0.113.7', 'worker@orchard.example.org', 'worker@2001:db8::7', 'worker@::1']) {
    test('the stop feed reaches $host', () => expect(feed(host), contains(host)));
  }
  for (final host in ['worker@999.999.999.999', 'worker@-oProxyCommand=x', '-l@203.0.113.7', 'worker', 'a@b@c']) {
    test('the stop feed refuses $host', () => expect(() => feed(host), throwsFormatException));
  }

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
