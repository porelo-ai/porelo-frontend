// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// `default`, the project work goes to without a project: its repositories listed,
/// added by address and taken out, as the contract names each field.
void main() {
  late MockDaemon daemon;
  late Map<String, dynamic> asked;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });

  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  void answering(String method, Map<String, dynamic> reply) => daemon.method(method, (parameters) {
        asked = parameters;
        return reply;
      });

  test('its repositories say which followed project names one too', () async {
    answering('DefaultRepositories', <String, dynamic>{
      'repositories': <Map<String, dynamic>>[
        <String, dynamic>{'name': 'api', 'upstream': 'git@github.com:acme/api.git', 'checkout': '/home/me/api', 'claimedBy': 'payments'},
      ],
    });

    final found = (await (await connect()).defaultRepositories()).single;

    expect(found.name, 'api');
    expect(found.upstream, 'git@github.com:acme/api.git');
    expect(found.checkout, '/home/me/api');
    expect(found.claimedBy, 'payments');
  });

  test('one is added by its address, with a name only where one was given', () async {
    answering('AddToDefault', <String, dynamic>{
      'repository': <String, dynamic>{'name': 'tools', 'upstream': 'git@example.org:acme/tools.git', 'checkout': '', 'claimedBy': ''},
    });
    final client = await connect();

    final added = await client.addToDefault('git@example.org:acme/tools.git');
    expect(asked, <String, dynamic>{'upstream': 'git@example.org:acme/tools.git'});
    expect(added.name, 'tools');

    await client.addToDefault('git@example.org:acme/tools.git', name: ' toolbox ');
    expect(asked['name'], 'toolbox');
  });

  test('one is taken out by its name, and the answer names the key the machine forgot', () async {
    answering('RemoveFromDefault', <String, dynamic>{
      'removed': true,
      'keys': <Map<String, dynamic>>[
        <String, dynamic>{
          'entry': 'deploy/default/api',
          'repository': 'api',
          'upstream': 'git@github.com:acme/api.git',
          'publicKey': 'ssh-ed25519 AAAAapi porelo@vm',
          'fingerprint': 'SHA256:api',
          'title': 'porelo vm default/api',
          'writeAccess': true,
          'made': false,
        },
      ],
    });

    final done = await (await connect()).removeFromDefault('api');

    expect(asked, <String, dynamic>{'name': 'api'});
    expect(done.removed, isTrue);
    expect(done.keys.single.title, 'porelo vm default/api');
  });

  test('one that was not there any more is said as not taken out, with no key', () async {
    answering('RemoveFromDefault', <String, dynamic>{'removed': false, 'keys': <Object>[]});

    final done = await (await connect()).removeFromDefault('gone');

    expect(done.removed, isFalse);
    expect(done.keys, isEmpty);
  });
}
