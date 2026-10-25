// Linux only: these calls cross a real unix socket.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

void main() {
  late MockDaemon daemon;
  late PoreloClient client;

  setUp(() async {
    daemon = MockDaemon();
    daemon.membersOf['checkout'] = [
      {'person': 'anna', 'user': '@anna:room'},
      {'person': 'bea', 'user': '@bea:room'},
    ];
    daemon.membersOf['other'] = [
      {'person': 'anna', 'user': '@anna:other'},
    ];
    await daemon.start();
    client = await PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));
  });
  tearDown(() => daemon.stop());

  // Harm: sending the wrong project or person leaves the intended account in the room.
  test('removal changes only the requested project and person over the socket', () async {
    final result = await client.removeMessageMember('checkout', 'anna');
    expect(result.user, isEmpty, reason: 'nothing remained in the removal reply');
    expect(result.kept, isFalse, reason: 'the mock removed the account');
    expect(result.why, isEmpty);
    expect((await client.messageMembers('checkout')).map((each) => each.person), ['bea']);
    expect((await client.messageMembers('other')).single.user, '@anna:other');
  });

  // Harm: an absent member answered as success hides an account that was never removed.
  test('an unknown person is refused over the socket without changing members', () async {
    await expectLater(
      client.removeMessageMember('checkout', 'missing'),
      throwsA(
        isA<VarlinkException>()
            .having((error) => error.simpleName, 'refusal', 'NoSuchMember')
            .having((error) => error.parameters['person'], 'person', 'missing'),
      ),
    );
    expect((await client.messageMembers('checkout')).map((each) => each.person), ['anna', 'bea']);
  });

  // Harm: dropping kept or why can imply an account was deleted when the transport retained it.
  test('a kept account and its explanation survive the wire with tolerant fields', () async {
    daemon.method(
      'RemoveMessageMember',
      (_) => {
        'user': '@anna:room',
        'kept': true,
        'why': 'Still used by another room.\nAccount retained.',
        'future': 42,
      },
    );
    final answer = await client.removeMessageMember('checkout', 'anna');
    expect(answer.user, '@anna:room');
    expect(answer.kept, isTrue);
    expect(answer.why, 'Still used by another room.\nAccount retained.');
    daemon.method('RemoveMessageMember', (_) => {});
    final older = await client.removeMessageMember('checkout', 'anna');
    expect((older.user, older.kept, older.why), ('', false, ''));
    daemon.method('RemoveMessageMember', (_) => {'user': 4, 'kept': 'true', 'why': false});
    final malformed = await client.removeMessageMember('checkout', 'anna');
    expect((malformed.user, malformed.kept, malformed.why), ('', false, ''));
  });

  // Harm: a transport refusal treated as success leaves the account active without warning.
  test('transport refusals preserve their message and exit code over the socket', () async {
    for (final code in [75, 77, 78]) {
      daemon.fails('RemoveMessageMember', 'org.fuin.porelo.Tasks1.ConversationRefused', {
        'message': 'Transport says: refusal $code.\nTry at the machine.',
        'code': code,
      });
      await expectLater(
        client.removeMessageMember('checkout', 'anna'),
        throwsA(
          isA<VarlinkException>()
              .having((error) => error.simpleName, 'refusal', 'ConversationRefused')
              .having(
                (error) => error.parameters['message'],
                'message',
                'Transport says: refusal $code.\nTry at the machine.',
              )
              .having((error) => error.parameters['code'], 'code', code),
        ),
      );
    }
    expect((await client.messageMembers('checkout')).map((each) => each.person), ['anna', 'bea']);
  });

  // Harm: an older removal method must not disable reading the room or claim removal succeeded.
  test('a missing removal method disables only removal', () async {
    daemon.remove('RemoveMessageMember');
    await expectLater(
      client.removeMessageMember('checkout', 'anna'),
      throwsA(isA<FeatureNotSupported>().having((error) => error.method, 'method', 'RemoveMessageMember')),
    );
    expect((await client.messageMembers('checkout')).map((each) => each.person), ['anna', 'bea']);
  });
}
