// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// The keyslot methods proposed for Porelo, spoken over a real socket to a stand-in daemon.
///
/// **Built against the proposal, not against a daemon that has them**: when the keyslots are built, the names
/// and fields here are what has to match, and nothing above this layer should change.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });

  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(
      Backend(socketPath: daemon.socketPath, label: 'mock'));

  Map<String, dynamic> slot(String id, {bool self = false}) => <String, dynamic>{
        'id': id,
        'name': 'laptop',
        'storage': 'USER_SCOPED',
        'enrolled': '2026-09-18T08:00:00Z',
        'lastUsed': '',
        'self': self,
        'recovery': false,
      };

  test('enrolling sends the name, the share and the declared storage, and reads the slot back', () async {
    Map<String, dynamic>? asked;
    daemon.method('EnrollDevice', (parameters) {
      asked = parameters;
      return <String, dynamic>{'outcome': 'ENROLLED', 'slot': slot('slot-1'), 'detail': ''};
    });

    final enrolled = await (await connect())
        .enrollDevice(name: 'laptop', share: 'c2hhcmU=', storage: KeyslotStorage.userScoped);

    expect(asked, <String, dynamic>{'name': 'laptop', 'share': 'c2hhcmU=', 'storage': 'USER_SCOPED'});
    expect(enrolled.outcome, KeyslotOutcome.enrolled);
    expect(enrolled.slot?.id, 'slot-1');
    expect(enrolled.slot?.storage, KeyslotStorage.userScoped);
  });

  test('the list reads every slot, the recovery passphrase marked as one', () async {
    daemon.method('Keyslots', (_) => <String, dynamic>{
          'slots': <Map<String, dynamic>>[
            <String, dynamic>{...slot('slot-0'), 'name': 'recovery passphrase', 'recovery': true},
            slot('slot-1', self: true),
          ],
        });

    final slots = await (await connect()).keyslots();

    expect(slots.map((each) => each.id), <String>['slot-0', 'slot-1']);
    expect(slots.first.recovery, isTrue);
    expect(slots.last.self, isTrue);
  });

  test('revoking names the slot and reads back what remains', () async {
    Map<String, dynamic>? asked;
    daemon.method('RevokeKeyslot', (parameters) {
      asked = parameters;
      return <String, dynamic>{'outcome': 'LAST_WAY_IN', 'remaining': <dynamic>[slot('slot-1')], 'detail': ''};
    });

    final revoked = await (await connect()).revokeKeyslot('slot-1');

    expect(asked, <String, dynamic>{'id': 'slot-1'});
    expect(revoked.outcome, KeyslotOutcome.lastWayIn);
    expect(revoked.remaining.single.id, 'slot-1');
  });

  test('unlocking sends only what was given, and a rejected share comes back as such', () async {
    Map<String, dynamic>? asked;
    daemon.method('UnlockWithShare', (parameters) {
      asked = parameters;
      return <String, dynamic>{'outcome': 'SHARE_REJECTED', 'until': '', 'detail': ''};
    });

    final unlocked = await (await connect()).unlockWithShare(share: 'c2hhcmU=', minutes: 30);

    expect(asked, <String, dynamic>{'share': 'c2hhcmU=', 'minutes': 30}, reason: 'as built, unlocking takes no keyslot id, so none is sent');
    expect(unlocked.outcome, KeyslotOutcome.shareRejected);
    expect(unlocked.slot, isNull);
  });

  test('until Porelo builds keyslots, every keyslot method says it is not there', () async {
    final client = await connect();

    await expectLater(client.keyslots(), throwsA(isA<FeatureNotSupported>()));
    await expectLater(
      client.unlockWithShare(share: 'c2hhcmU='),
      throwsA(isA<FeatureNotSupported>()),
    );
  });
}
