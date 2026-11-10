// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// A host's approved main brought to central, as the machine streams it and as it refuses.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });

  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  // Harm: a push of repositories nobody named, or a stage read as the end, says work reached central that did not.
  test(
    'the repositories named are asked for, each stage arrives, and only the last reply names what was pushed',
    () async {
      final asked = <Map<String, dynamic>>[];
      daemon.stream('PushToCentral', (parameters) async* {
        asked.add(parameters);
        yield <String, dynamic>{'repository': 'payments-api', 'stage': 'pushing'};
        yield <String, dynamic>{
          'pushed': <String>['payments-api'],
          'upToDate': <String>['billing'],
        };
      });
      final replies = await (await connect()).pushToCentral('checkout', repositories: ['payments-api']).toList();
      expect(asked.single, <String, dynamic>{
        'project': 'checkout',
        'repositories': <String>['payments-api'],
      });
      expect(replies.first.isFinal, isFalse);
      expect(replies.first.stage, 'pushing');
      expect(replies.last.isFinal, isTrue);
      expect(replies.last.pushed, <String>['payments-api']);
      expect(replies.last.upToDate, <String>['billing']);
    },
  );

  // Harm: a token the forge refused is said as anything else, or what reached central before it is lost.
  test('a refused token comes back as that refusal, with the forge, its status and what was pushed before', () async {
    daemon.fails('PushToCentral', 'org.fuin.porelo.Tasks1.CentralTokenRefused', <String, dynamic>{
      'credential': 'acme.central',
      'storeCommand': <String>[],
      'repository': 'billing',
      'pushed': <String>['payments-api'],
      'upToDate': <String>[],
      'forge': 'git.acme.example',
      'status': 401,
    });
    final refused = await (await connect())
        .pushToCentral('checkout')
        .toList()
        .then<Object?>((_) => null, onError: (Object e) => e);
    expect(refused, isA<CentralPushRefusal>());
    final refusal = refused! as CentralPushRefusal;
    expect(refusal.kind, 'CentralTokenRefused');
    expect(refusal.forge, 'git.acme.example');
    expect(refusal.status, 401);
    expect(refusal.repository, 'billing');
    expect(refusal.pushed, <String>['payments-api']);
  });

  // Harm: a command the machine names with a line break in it is offered to run, doing what nobody read.
  test(
    'a command with a word that holds a control character is offered as none, and a wrong type left unsaid',
    () async {
      daemon.fails('PushToCentral', 'org.fuin.porelo.Tasks1.MissingCentralToken', <String, dynamic>{
        'credential': 'acme.central',
        'storeCommand': <String>['porelo', 'vault', 'put', 'acme.central\nrm -rf ~'],
      });
      final refused = await (await connect())
          .pushToCentral('checkout')
          .toList()
          .then<Object?>((_) => null, onError: (Object e) => e);
      final refusal = refused! as CentralPushRefusal;
      expect(refusal.storeCommand, isEmpty);
      expect(refusal.credential, 'acme.central');
      expect(refusal.status, isNull);
    },
  );

  // Harm: an older machine reads as one that failed to push, rather than one that cannot.
  test('a machine without it says so', () async {
    final refused = await (await connect())
        .pushToCentral('checkout')
        .toList()
        .then<Object?>((_) => null, onError: (Object e) => e);
    expect(refused, isA<FeatureNotSupported>());
  });
}
