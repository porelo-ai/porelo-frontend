import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/mailboxes.dart';

import '../features/support/world.dart' show FakeBackend;

class _Machine extends FakeBackend {
  _Machine() : super(const []);

  /// What the machine lists now.
  List<HeldMessage> listed = const [];

  /// How many times the stream was listened to.
  int listens = 0;

  /// The stream of the last listen.
  late StreamController<TalkEvent> stream;

  @override
  Future<List<HeldMessage>> messagesHeld({String? task}) async => listed;

  @override
  Stream<TalkEvent> talk() {
    listens++;
    stream = StreamController<TalkEvent>();
    return stream.stream;
  }
}

const _held = HeldMessage(
  task: 'porelo-demo-demo',
  standing: 'held',
  message: 'one.json',
  id: 'one',
  role: 'ROLE_USER',
  peer: 'reviewer',
  kind: 'message',
  at: '2026-11-02T08:00:00Z',
  reason: 'the peer is held',
  direction: 'out',
);

void main() {
  late _Machine machine;
  late Mailboxes mailboxes;

  setUp(() {
    machine = _Machine();
    mailboxes = Mailboxes();
    addTearDown(mailboxes.dispose);
  });

  // Harm: a message waits for a person while the screen says nothing needs them.
  test('a message held with no word from the stream is still found', () async {
    mailboxes.watch(machine);
    await pumpEventQueue();
    expect(mailboxes.waiting, isEmpty);
    machine.listed = const [_held];
    mailboxes.askAgain();
    await pumpEventQueue();
    expect(mailboxes.waiting.single.message, 'one.json');
  });

  // Harm: the stream ended once, with its connection or an unreadable record, and no event ever comes again.
  test('a stream that ended is listened to again, and one that lives is not', () async {
    mailboxes.watch(machine);
    await pumpEventQueue();
    mailboxes.askAgain();
    expect(machine.listens, 1);
    await machine.stream.close();
    await pumpEventQueue();
    mailboxes.askAgain();
    expect(machine.listens, 2);
  });

  // Harm: the same, with the stream's end an error that is otherwise swallowed.
  test('a stream ended by an error is listened to again', () async {
    mailboxes.watch(machine);
    await pumpEventQueue();
    machine.stream.addError(StateError('a record could not be read'));
    await machine.stream.close();
    await pumpEventQueue();
    machine.listed = const [_held];
    mailboxes.askAgain();
    await pumpEventQueue();
    expect(machine.listens, 2);
    expect(mailboxes.waiting, hasLength(1));
  });
}
