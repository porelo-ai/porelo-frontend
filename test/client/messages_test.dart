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
}
