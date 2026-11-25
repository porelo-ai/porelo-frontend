// Linux only: it stands the mock daemon on a unix socket.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

void main() {
  late MockDaemon daemon;
  late List<Map<String, dynamic>> set;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
    set = <Map<String, dynamic>>[];
    daemon
      ..method(
        'Forges',
        (_) => <String, dynamic>{
          // As Porelo answered it, recorded from its running code: an entry that does not read names no adapter.
          'forges': <Map<String, dynamic>>[
            <String, dynamic>{'host': 'github.com', 'adapter': 'github', 'comments': 'EXTENDED'},
            <String, dynamic>{'host': 'a b', 'adapter': '', 'unreadable': 'its host is not a DNS name'},
            <String, dynamic>{
              'host': 'forge.example',
              'adapter': '',
              'unreadable': 'its comments are neither extended nor trusted',
            },
          ],
          'adapters': <String>['github', 'stub-forge'],
        },
      )
      ..method('ForgeSet', (parameters) {
        set.add(parameters);
        return <String, dynamic>{};
      });
  });

  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  // Harm: a forge set up under My forges is sent under other names than the interface's and refused, so no task
  // reaches it; or comments go TRUSTED nobody chose.
  test('ForgeSet sends host, adapter and comments only where given', () async {
    final client = await connect();

    await client.forgeSet('github.com', 'github');
    await client.forgeSet('forge.example', 'github', comments: 'TRUSTED');

    expect(set, [
      {'host': 'github.com', 'adapter': 'github'},
      {'host': 'forge.example', 'adapter': 'github', 'comments': 'TRUSTED'},
    ]);
  });

  // Harm: a forge the machine reads as trusted is shown extended, or one it cannot read is shown as known.
  test('Forges reads every forge with its comments and what was unreadable, and the installed adapters', () async {
    final answer = await (await connect()).forges();

    expect(answer.adapters, ['github', 'stub-forge']);
    expect(
      [for (final each in answer.forges) (each.host, each.adapter, each.trusted, each.unreadable)],
      [
        ('github.com', 'github', false, null),
        ('a b', '', false, 'its host is not a DNS name'),
        ('forge.example', '', false, 'its comments are neither extended nor trusted'),
      ],
    );
  });

  // Harm: a refusal Porelo answers with reaches the window under another name or without its values, so the forge's
  // page says the wrong reason or none.
  test(
    'the refusals of Forges and ForgeSet reach the window by name with their values, as Porelo answers them',
    () async {
      daemon
        ..fails('Forges', 'org.fuin.porelo.Tasks1.ForgeFileUnreadable', {
          'reason': 'forges.yml is not YAML: while parsing a flow sequence',
        })
        ..fails('ForgeSet', 'org.fuin.porelo.Tasks1.AdapterNotInstalled', {'adapter': 'gitlab'});
      final client = await connect();

      await expectLater(
        client.forges(),
        throwsA(
          isA<VarlinkException>()
              .having((error) => error.simpleName, 'name', 'ForgeFileUnreadable')
              .having((error) => error.parameters['reason'], 'reason', contains('not YAML')),
        ),
      );
      await expectLater(
        client.forgeSet('gitlab.com', 'gitlab'),
        throwsA(
          isA<VarlinkException>()
              .having((error) => error.simpleName, 'name', 'AdapterNotInstalled')
              .having((error) => error.parameters['adapter'], 'adapter', 'gitlab'),
        ),
      );
      daemon.fails('ForgeSet', 'org.varlink.service.InvalidParameter', {'parameter': 'host'});
      await expectLater(
        client.forgeSet('a b', 'github'),
        throwsA(isA<VarlinkException>().having((error) => error.simpleName, 'name', 'InvalidParameter')),
      );
    },
  );

  // Harm: an older Porelo without forges breaks the window's every call to it instead of this one feature.
  test('a machine without the forge methods answers that it does not support them', () async {
    daemon
      ..remove('Forges')
      ..remove('ForgeSet');
    final client = await connect();

    await expectLater(client.forges(), throwsA(isA<FeatureNotSupported>()));
    await expectLater(client.forgeSet('github.com', 'github'), throwsA(isA<FeatureNotSupported>()));
  });
}
