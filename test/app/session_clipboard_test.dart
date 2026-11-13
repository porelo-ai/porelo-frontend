import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/session.dart';

/// What a task's terminal puts on this computer's clipboard (OSC 52).
///
/// The harm: a task putting text on the clipboard that the person pastes into a shell later, a trailing newline
/// running it, or clearing what the person copied. Every write is held for the person to allow.
void main() {
  late CopyToClipboard before;
  late List<String> copied;
  setUp(() {
    before = copyToClipboard;
    copied = <String>[];
    copyToClipboard = (text) async => copied.add(text);
  });
  tearDown(() => copyToClipboard = before);

  (Session, _Channel) open() {
    final channel = _Channel();
    final session = Session(
      task: 'porelo-sluice-dry-sluice',
      machine: const Machine(name: 'laptop', socketPath: ''),
      open: (executable, arguments, {int columns = 80, int rows = 24}) => channel,
    );
    addTearDown(session.leave);
    return (session, channel);
  }

  Future<void> prints(_Channel channel, String words) async {
    channel.prints(words);
    await pumpEventQueue();
  }

  String write(String text, {String selection = 'c'}) => '\x1b]52;$selection;${base64.encode(utf8.encode(text))}\x07';

  test('a write is held, not copied, and the view is told', () async {
    final (session, channel) = open();
    var told = 0;
    session.addListener(() => told++);

    await prints(channel, write('rm -rf ~\n'));

    expect(copied, isEmpty, reason: 'nothing the task sent by itself reaches the clipboard');
    expect(session.held?.text, 'rm -rf ~\n');
    expect(told, greaterThan(0), reason: 'the view must hear there is something to ask');
  });

  test('after the session is over a write is neither copied nor held', () async {
    final (session, channel) = open();
    channel.ends();
    await pumpEventQueue();
    await prints(channel, write('copy me'));
    expect(copied, isEmpty);
    expect(session.held, isNull);
  });

  test('an empty write leaves the clipboard alone, and is not held', () async {
    final (session, channel) = open();
    await prints(channel, '\x1b]52;c;\x07');
    expect(copied, isEmpty);
    expect(session.held, isNull);
  });

  test('a read of the clipboard is neither answered nor held', () async {
    final (session, channel) = open();
    await prints(channel, '\x1b]52;c;?\x07');
    expect(copied, isEmpty);
    expect(session.held, isNull);
    expect(channel.sent.where((each) => each.contains(']52')), isEmpty);
  });

  test('only a write naming the clipboard is taken', () async {
    final (session, channel) = open();
    for (final selection in <String>['p', 's', '0', 'q7']) {
      await prints(channel, write('to $selection', selection: selection));
    }
    expect(copied, isEmpty);
    expect(session.held, isNull);
  });

  test('an empty selection is the clipboard, behind the same gate', () async {
    final (session, channel) = open();
    await prints(channel, write('by itself', selection: ''));
    expect(copied, isEmpty);
    expect(session.held?.text, 'by itself');
  });

  test('unpadded base64 is read as padded', () async {
    final (session, channel) = open();
    await prints(channel, '\x1b]52;c;aGk\x07');
    expect(copied, isEmpty);
    expect(session.held?.text, 'hi');
  });

  test('a held write is dropped when the session is left', () async {
    final (session, channel) = open();
    await prints(channel, write('held'));
    final held = session.held!;
    await session.leave();
    expect(session.held, isNull);
    session.copyHeld(held);
    expect(copied, isEmpty);
  });

  test('a held write is dropped when the session is over', () async {
    final (session, channel) = open();
    await prints(channel, write('held'));
    final held = session.held!;
    channel.ends();
    await pumpEventQueue();
    expect(session.state, SessionState.over);
    expect(session.held, isNull);
    session.copyHeld(held);
    expect(copied, isEmpty);
  });

  test('a held write is copied when allowed, and only the one still held', () async {
    final (session, channel) = open();
    await prints(channel, write('old'));
    final old = session.held!;
    await prints(channel, write('new'));
    session.copyHeld(old);
    expect(copied, isEmpty, reason: 'the one shown was replaced');
    session.copyHeld(session.held!);
    expect(copied, <String>['new']);
    expect(session.held, isNull);
  });

  test('a write split across chunks is held once it is complete', () async {
    final (session, channel) = open();
    final whole = write('split');
    await prints(channel, whole.substring(0, 10));
    expect(session.held, isNull);
    await prints(channel, whole.substring(10));
    expect(copied, isEmpty);
    expect(session.held?.text, 'split');
  });
}

class _Channel implements SessionChannel {
  final List<String> sent = <String>[];
  final StreamController<List<int>> _output = StreamController<List<int>>.broadcast();
  final Completer<int> _ended = Completer<int>();

  void prints(String words) => _output.add(utf8.encode(words));

  void ends() {
    if (!_ended.isCompleted) _ended.complete(0);
  }

  @override
  Stream<List<int>> get output => _output.stream;

  @override
  void send(String input) => sent.add(input);

  @override
  void resize({required int columns, required int rows}) {}

  @override
  Future<int> get ended => _ended.future;

  @override
  Future<void> close() async {
    if (!_ended.isCompleted) _ended.complete(0);
  }
}
