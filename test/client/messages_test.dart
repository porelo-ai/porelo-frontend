import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

/// What the messaging replies are read as, including what an older daemon leaves out.
void main() {
  test("a peer's use of the day is read, and absent stays unknown rather than zero", () {
    final counted = TalkPeer.from(const <String, dynamic>{
      'name': 'reviewer',
      'perDay': 20,
      'mode': 'prompt',
      'held': false,
      'sentToday': 3,
      'receivedToday': 0,
    });
    expect(counted.sentToday, 3);
    expect(counted.receivedToday, 0);
    final older = TalkPeer.from(const <String, dynamic>{'name': 'reviewer', 'perDay': 20});
    expect(older.sentToday, isNull);
    expect(older.receivedToday, isNull);
  });

  test('which way a held message was going is read, and absent says nothing', () {
    expect(HeldMessage.from(const <String, dynamic>{'direction': 'in'}).direction, 'in');
    expect(HeldMessageRead.from(const <String, dynamic>{'direction': 'out'}).direction, 'out');
    expect(HeldMessage.from(const <String, dynamic>{}).direction, isEmpty);
  });

  // Harm: an invitation read as a made account sends the person after a password that does not exist, and the reset
  // they then ask for ends that account's sessions in every room.
  test('a join answer is an invitation only where it says invited true', () {
    Map<String, dynamic> answer(Object? invited) => <String, dynamic>{
      'transport': 'matrix',
      'shown': '',
      'login': <String, dynamic>{'user': '@anna:example.org'},
      'invited': ?invited,
    };
    expect(MessagesJoined.from(answer(true)).invited, isTrue, reason: 'the daemon said the account was invited');
    expect(MessagesJoined.from(answer(false)).invited, isFalse, reason: 'the daemon said one was made');
    expect(MessagesJoined.from(answer(null)).invited, isFalse, reason: 'an older daemon that does not say made one');
    for (final wrong in <Object>['true', 1, <Object?>[], <String, Object?>{}]) {
      expect(MessagesJoined.from(answer(wrong)).invited, isFalse, reason: 'a field not a bool is not coerced: $wrong');
    }
  });
}
