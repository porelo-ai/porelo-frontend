// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/machine.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// The stand-in's host whose main is ahead of central, over a real socket, as the window brings it there.
void main() {
  late MockDaemon daemon;
  late MockMachine machine;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
    machine = MockMachine(daemon, situation: 'central-ahead', pace: Duration.zero);
  });

  tearDown(() async {
    await machine.close();
    await daemon.stop();
  });

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  Future<Repository> paymentsApi(PoreloClient client) async => (await client.projects())
      .firstWhere((project) => project.name == 'checkout')
      .repositoryStates
      .firstWhere((each) => each.name == 'payments-api');

  // Harm: the window cannot be shown a push that brings work to central and then stands there, so the button and its
  // answer are first seen working before a real host.
  test('a push brings payments-api to central, and the machine then lists it at central', () async {
    final client = await connect();
    expect((await paymentsApi(client)).central, 'ahead');
    final replies = await client.pushToCentral('checkout', repositories: ['payments-api']).toList();
    expect(replies.map((each) => each.stage).whereType<String>(), ['reading', 'pushing', 'pushed']);
    expect(replies.last.pushed, ['payments-api']);
    expect((await paymentsApi(client)).central, 'up-to-date');
    expect((await paymentsApi(client)).ahead, 0);
  });

  // Harm: a refused token cannot be tried against the stand-in, and the main stays ahead whatever it said.
  test('a token central refuses brings nothing, and the main stays ahead', () async {
    machine.centralRefusesToken = true;
    final client = await connect();
    final refused = await client
        .pushToCentral('checkout', repositories: ['payments-api'])
        .toList()
        .then<Object?>((_) => null, onError: (Object e) => e);
    expect((refused! as CentralPushRefusal).kind, 'CentralTokenRefused');
    expect((await paymentsApi(client)).central, 'ahead');
  });
}
