// Linux only: it stands the mock daemon on a unix socket.
@Tags(<String>['linux'])
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// A host's identity as the daemon's interface shapes it; the private halves are stand-ins, never real keys.
Map<String, dynamic> _identity({bool private = true}) => <String, dynamic>{
  'host': 'orchard',
  'organization': <String, dynamic>{
    'public': 'ssh-ed25519 AAAAorganization porelo',
    if (private)
      'private': '-----BEGIN OPENSSH PRIVATE KEY-----\nSECRET-ORGANIZATION\n-----END OPENSSH PRIVATE KEY-----\n',
  },
  'repositories': <Map<String, dynamic>>[
    <String, dynamic>{
      'project': 'garden',
      'repository': 'acme/garden',
      'address': 'https://forge.example/acme/garden.git',
      'key_id': 7,
      'title': 'porelo host orchard project garden',
      'public': 'ssh-ed25519 AAAArepository porelo',
      if (private)
        'private': '-----BEGIN OPENSSH PRIVATE KEY-----\nSECRET-REPOSITORY\n-----END OPENSSH PRIVATE KEY-----\n',
    },
  ],
  'ssh_host_keys': <Map<String, dynamic>>[
    <String, dynamic>{
      'type': 'ed25519',
      'public': 'ssh-ed25519 AAAAhostkey root@orchard',
      if (private) 'private': '-----BEGIN OPENSSH PRIVATE KEY-----\nSECRET-HOST\n-----END OPENSSH PRIVATE KEY-----\n',
    },
  ],
};

void main() {
  late MockDaemon daemon;
  var stopped = false;
  late Map<String, List<Map<String, dynamic>>> asked;

  setUp(() async {
    daemon = MockDaemon();
    stopped = false;
    await daemon.start();
    asked = <String, List<Map<String, dynamic>>>{};
    Map<String, dynamic> Function(Map<String, dynamic>) recorded(String method, Map<String, dynamic> reply) =>
        (parameters) {
          asked.putIfAbsent(method, () => <Map<String, dynamic>>[]).add(parameters);
          return reply;
        };
    daemon
      ..method('HostIdentityKeep', recorded('HostIdentityKeep', <String, dynamic>{}))
      ..method('HostIdentityRead', recorded('HostIdentityRead', <String, dynamic>{'identity': _identity()}))
      ..method(
        'HostIdentityPublic',
        recorded('HostIdentityPublic', <String, dynamic>{'identity': _identity(private: false)}),
      )
      ..method(
        'HostIdentities',
        recorded('HostIdentities', <String, dynamic>{
          'hosts': <String>['lemon', 'orchard'],
        }),
      );
  });

  tearDown(() async {
    if (!stopped) await daemon.stop();
  });

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  // Harm: a parameter named other than the interface names it is refused, so no identity is ever kept or read; or the
  // identity read is changed on its way to the host's setup, which then refuses it.
  test('each call sends the parameters the interface names and reads its answer', () async {
    final client = await connect();
    final read = await client.hostIdentityRead('orchard');
    expect(jsonDecode(read.json), _identity());
    expect(read.host, 'orchard');
    await client.hostIdentityKeep('orchard', read);
    await client.hostIdentityKeep('orchard', read, replace: true);
    final public = await client.hostIdentityPublic('orchard');
    expect(public.host, 'orchard');
    expect(public.sshHostKeys, [(type: 'ed25519', public: 'ssh-ed25519 AAAAhostkey root@orchard')]);
    expect(public.ed25519, 'ssh-ed25519 AAAAhostkey', reason: 'the key alone, as a host answers with it');
    expect(public.repositories, [(project: 'garden', repository: 'acme/garden')]);
    expect(await client.hostIdentities(), ['lemon', 'orchard']);
    expect(asked, <String, List<Map<String, dynamic>>>{
      'HostIdentityRead': [
        <String, dynamic>{'host': 'orchard'},
      ],
      'HostIdentityKeep': [
        <String, dynamic>{'host': 'orchard', 'identity': _identity(), 'replace': false},
        <String, dynamic>{'host': 'orchard', 'identity': _identity(), 'replace': true},
      ],
      'HostIdentityPublic': [
        <String, dynamic>{'host': 'orchard'},
      ],
      'HostIdentities': [<String, dynamic>{}],
    });
  });

  // Harm: an identity printed in a log or an error carries a host's private keys out of the vault.
  test('an identity never says its keys when printed', () async {
    final read = await (await connect()).hostIdentityRead('orchard');
    expect('$read', isNot(contains('SECRET')));
    expect('$read', isNot(contains('PRIVATE KEY')));
  });

  // Harm: a refusal is taken for "no identity", and a host is set up anew under keys the forge does not know.
  for (final (error, failure) in <(String, TypeMatcher<HostIdentityFailure>)>[
    ('org.fuin.porelo.Tasks1.HostIdentityUnknown', isA<HostIdentityUnknown>()),
    ('org.fuin.porelo.Tasks1.HostIdentityExists', isA<HostIdentityExists>()),
    ('org.fuin.porelo.Tasks1.VaultLocked', isA<HostIdentityVaultShut>()),
    ('org.fuin.porelo.Tasks1.HostIdentityNotReadOnAHost', isA<HostIdentityRefused>()),
    ('org.varlink.service.InvalidParameter', isA<HostIdentityRefused>()),
  ]) {
    test('$error is its own failure', () async {
      final client = await connect();
      daemon.fails('HostIdentityPublic', error, <String, dynamic>{'host': 'orchard'});
      daemon.fails('HostIdentityKeep', error, <String, dynamic>{'host': 'orchard'});
      await expectLater(client.hostIdentityPublic('orchard'), throwsA(failure));
      await expectLater(client.hostIdentityKeep('orchard', await client.hostIdentityRead('orchard')), throwsA(failure));
    });
  }

  // Harm: a refusal on a host's own Porelo reads as a fault nobody can act on, or as no identity.
  test("a host's Porelo refusing a keep says so in words of its own", () async {
    final client = await connect();
    daemon.fails('HostIdentityKeep', 'org.fuin.porelo.Tasks1.HostIdentityNotReadOnAHost', <String, dynamic>{});
    await expectLater(
      client.hostIdentityKeep('orchard', await client.hostIdentityRead('orchard')),
      throwsA(isA<HostIdentityRefused>().having((refused) => refused.words, 'words', contains("a host's own Porelo"))),
    );
  });

  // Harm: an answer that is no identity escapes as an error nobody maps, and a start or a keeping breaks on it.
  test('an answer that is no identity is a refusal of its own', () async {
    final client = await connect();
    daemon
      ..method('HostIdentityRead', (_) => <String, dynamic>{'identity': 7})
      ..method('HostIdentityPublic', (_) => <String, dynamic>{'identity': 'orchard'});
    await expectLater(client.hostIdentityRead('orchard'), throwsA(isA<HostIdentityRefused>()));
    await expectLater(client.hostIdentityPublic('orchard'), throwsA(isA<HostIdentityRefused>()));
  });

  // Harm: an older Porelo, or one that went away, is taken for a vault with no identity for the host.
  test('a Porelo without the methods, and one gone, is never no identity', () async {
    final client = await connect();
    daemon.remove('HostIdentityPublic');
    await expectLater(client.hostIdentityPublic('orchard'), throwsA(isA<HostIdentityUnsupported>()));
    await daemon.stop();
    stopped = true;
    await expectLater(client.hostIdentityPublic('orchard'), throwsA(isA<HostIdentityUnreached>()));
    await expectLater(client.hostIdentities(), throwsA(isA<HostIdentityUnreached>()));
  });
}
