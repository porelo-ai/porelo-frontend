// Linux only: it stands the mock daemon on a unix socket.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// The four calls that carry a credential from this computer to a host, held to the parameters and fields of the
/// daemon's interface, over a real unix socket.
void main() {
  late MockDaemon daemon;
  late Map<String, List<Map<String, dynamic>>> asked;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
    asked = <String, List<Map<String, dynamic>>>{};
    Map<String, dynamic> Function(Map<String, dynamic>) recorded(String method, Map<String, dynamic> reply) =>
        (parameters) {
          asked.putIfAbsent(method, () => <Map<String, dynamic>>[]).add(parameters);
          return reply;
        };
    daemon
      ..method(
        'ImportableCredentials',
        recorded('ImportableCredentials', <String, dynamic>{
          'rows': <Map<String, dynamic>>[
            <String, dynamic>{'agent': 'an-agent', 'provider': 'other-provider', 'kind': 'oauth'},
          ],
        }),
      )
      ..method(
        'CredentialReceiver',
        recorded('CredentialReceiver', <String, dynamic>{
          'outcome': 'READY',
          'key': 'a2V5',
          'until': '2099-01-01T00:00:00Z',
        }),
      )
      ..method(
        'SealCredential',
        recorded('SealCredential', <String, dynamic>{
          'outcome': 'SEALED',
          'sealed': 'c2VhbGVk',
          'name': 'an-agent',
          'kind': 'oauth',
          'detail': '',
        }),
      )
      ..method(
        'ReceiveCredential',
        recorded('ReceiveCredential', <String, dynamic>{'outcome': 'EXISTS', 'detail': 'kept'}),
      );
  });

  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  // Harm: a parameter named other than the interface names it is dropped or refused by the daemon, so a host never
  // stores what was carried, or a seal names an entry and an agent at once, which the daemon refuses.
  test('each carry call sends exactly the parameters the interface names', () async {
    final client = await connect();
    await client.importableCredentials();
    await client.credentialReceiver();
    await client.sealCredential(key: 'a2V5', name: 'an-agent');
    await client.sealCredential(key: 'a2V5', agent: 'an-agent', provider: 'other-provider');
    await client.sealCredential(
      key: 'a2V5',
      agent: 'an-agent',
      provider: 'other-provider',
      configDirectory: '/home/somebody/.agent',
    );
    await client.receiveCredential(sealed: 'c2VhbGVk', name: 'an-agent', kind: 'oauth', replace: true);
    expect(asked, <String, List<Map<String, dynamic>>>{
      'ImportableCredentials': <Map<String, dynamic>>[<String, dynamic>{}],
      'CredentialReceiver': <Map<String, dynamic>>[<String, dynamic>{}],
      'SealCredential': <Map<String, dynamic>>[
        <String, dynamic>{'key': 'a2V5', 'name': 'an-agent'},
        <String, dynamic>{'key': 'a2V5', 'agent': 'an-agent', 'provider': 'other-provider'},
        <String, dynamic>{
          'key': 'a2V5',
          'agent': 'an-agent',
          'provider': 'other-provider',
          'configDirectory': '/home/somebody/.agent',
        },
      ],
      'ReceiveCredential': <Map<String, dynamic>>[
        <String, dynamic>{'sealed': 'c2VhbGVk', 'name': 'an-agent', 'kind': 'oauth', 'replace': true},
      ],
    });
  });

  // Harm: a reply field read under another name comes back empty, so a refusal reads as nothing said, a host's key
  // is lost, or the host is handed an empty seal under no name.
  test("every field of each carry call's reply is read as the interface names it", () async {
    final client = await connect();
    final rows = await client.importableCredentials();
    expect(rows.map((row) => (row.agent, row.provider, row.kind)), <(String, String, String)>[
      ('an-agent', 'other-provider', 'oauth'),
    ]);
    final receiver = await client.credentialReceiver();
    expect((receiver.outcome, receiver.key, receiver.until), ('READY', 'a2V5', '2099-01-01T00:00:00Z'));
    final sealed = await client.sealCredential(key: receiver.key, name: 'an-agent');
    expect(
      (sealed.outcome, sealed.sealed, sealed.name, sealed.kind, sealed.detail),
      ('SEALED', 'c2VhbGVk', 'an-agent', 'oauth', ''),
    );
    final received = await client.receiveCredential(
      sealed: sealed.sealed,
      name: sealed.name,
      kind: sealed.kind,
      replace: false,
    );
    expect((received.outcome, received.detail), ('EXISTS', 'kept'));
  });
}
