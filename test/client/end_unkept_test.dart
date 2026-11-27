// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/machine.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// Approve, Reject and Landed carry the machine's sentence when a push's end could not be kept, over a real socket.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });

  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  const sentence = 'The record of task fix could not be written.';

  // Harm: the sentence is lost on the way, and the person is never told the end was not kept.
  test('all three replies carry the sentence the machine sent', () async {
    final machine = MockMachine(daemon, pace: Duration.zero)..endUnkept = sentence;
    addTearDown(machine.close);
    final client = await connect();

    expect((await client.approve('checkout', 'fix', 'main')).endUnkept, sentence);
    expect((await client.reject('checkout', 'fix')).endUnkept, sentence);
    expect((await client.landed('checkout', 'fix', branch: 'main')).endUnkept, sentence);
  });

  // Harm: a reply without the field is read as a warning, and every forward then says one.
  test('a reply without the field carries none', () async {
    final machine = MockMachine(daemon, pace: Duration.zero);
    addTearDown(machine.close);
    final client = await connect();

    expect((await client.approve('checkout', 'fix', 'main')).endUnkept, isNull);
    expect((await client.reject('checkout', 'fix')).endUnkept, isNull);
    final landed = await client.landed('checkout', 'fix', branch: 'main');
    expect(landed.landed, isTrue);
    expect(landed.endUnkept, isNull);
  });

  // Harm: a blank sentence or one of the wrong type is shown as a warning, or throws and loses the answer.
  test('a blank sentence or one that is no string reads as none, and the rest of the reply is kept', () async {
    daemon
      ..method('Approve', (_) => <String, dynamic>{'forwarded': 'fix', 'branch': 'main', 'endUnkept': '  '})
      ..method('Reject', (_) => <String, dynamic>{'rejected': 'fix', 'told': true, 'endUnkept': 7})
      ..method(
        'Landed',
        (_) => <String, dynamic>{
          'landed': true,
          'commit': 'c0ffee9',
          'detail': '',
          'endUnkept': <String>['a'],
        },
      );
    final client = await connect();

    final forwarded = await client.approve('checkout', 'fix', 'main');
    expect(forwarded.endUnkept, isNull);
    expect(forwarded.branch, 'main');
    final rejected = await client.reject('checkout', 'fix');
    expect(rejected.endUnkept, isNull);
    expect(rejected.told, isTrue);
    final landed = await client.landed('checkout', 'fix', branch: 'main');
    expect(landed.endUnkept, isNull);
    expect(landed.commit, 'c0ffee9');
  });

  // Harm: a field a newer machine adds beside the sentence makes the reply unreadable, and the action looks failed.
  test('a field the window does not know beside the sentence is ignored', () async {
    daemon.method(
      'Approve',
      (_) => <String, dynamic>{'forwarded': 'fix', 'branch': 'main', 'endUnkept': sentence, 'endKeptAt': 'later'},
    );
    final client = await connect();

    final forwarded = await client.approve('checkout', 'fix', 'main');

    expect(forwarded.endUnkept, sentence);
    expect(forwarded.forwarded, 'fix');
  });
}
