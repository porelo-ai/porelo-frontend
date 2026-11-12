import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:xterm/xterm.dart';

/// What a task's terminal puts on this computer's clipboard (OSC 52).
///
/// The harm: a task putting text on the clipboard that the person pastes into a shell later, a trailing newline
/// running it, or clearing what the person copied. Only right after the person's own action in that terminal does a
/// write go through without a word, once; any other is held for the person to allow.
void main() {
  late CopyToClipboard before;
  late List<String> copied;
  late Duration now;
  setUp(() {
    before = copyToClipboard;
    copied = <String>[];
    copyToClipboard = (text) async => copied.add(text);
    now = const Duration(minutes: 1);
  });
  tearDown(() => copyToClipboard = before);

  (Session, _Channel) open() {
    final channel = _Channel();
    final session = Session(
      task: 'porelo-sluice-dry-sluice',
      machine: const Machine(name: 'laptop', socketPath: ''),
      open: (executable, arguments, {int columns = 80, int rows = 24}) => channel,
      clock: () => now,
    );
    addTearDown(session.leave);
    return (session, channel);
  }

  Future<void> prints(_Channel channel, String words) async {
    channel.prints(words);
    await pumpEventQueue();
  }

  String write(String text, {String selection = 'c'}) => '\x1b]52;$selection;${base64.encode(utf8.encode(text))}\x07';

  const keyA = KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.keyA,
    logicalKey: LogicalKeyboardKey.keyA,
    character: 'a',
    timeStamp: Duration.zero,
  );

  test('a write with no action of the person is held, not copied, and the view is told', () async {
    final (session, channel) = open();
    var told = 0;
    session.addListener(() => told++);

    await prints(channel, write('rm -rf ~\n'));

    expect(copied, isEmpty, reason: 'nothing the task sent by itself reaches the clipboard');
    expect(session.held?.text, 'rm -rf ~\n');
    expect(told, greaterThan(0), reason: 'the view must hear there is something to ask');
  });

  test('what the terminal answers by itself does not count as the person acting', () async {
    final (session, channel) = open();

    // The cursor position and the device attributes, both answered through the terminal's output.
    await prints(channel, '\x1b[6n\x1b[c');
    expect(channel.sent, isNotEmpty, reason: 'the terminal did answer');
    await prints(channel, write('after the answers'));
    expect(copied, isEmpty);
    expect(session.held?.text, 'after the answers');

    // A mouse report the task asked for, and text sent without a key.
    await prints(channel, '\x1b[?1000h');
    session.terminal.mouseInput(TerminalMouseButton.left, TerminalMouseButtonState.down, const CellOffset(1, 1));
    session.terminal.textInput('x');
    await prints(channel, write('after the reports'));
    expect(copied, isEmpty);
    expect(session.held?.text, 'after the reports');
  });

  test('one key lets one write through and holds the second', () async {
    final (session, channel) = open();
    session.ownKey(keyA);

    await prints(channel, write('first') + write('second'));

    expect(copied, <String>['first']);
    expect(session.held?.text, 'second');
  });

  test('a pointer or a paste of the person lets one write through', () async {
    final (session, channel) = open();
    session.ownAction();
    await prints(channel, write('after a click'));
    expect(copied, <String>['after a click']);
  });

  test('a silent write clears one that was held', () async {
    final (session, channel) = open();
    await prints(channel, write('held'));
    session.ownKey(keyA);
    await prints(channel, write('typed for'));
    expect(copied, <String>['typed for']);
    expect(session.held, isNull);
  });

  test('an empty write leaves the clipboard alone, and is not held', () async {
    final (session, channel) = open();
    session.ownKey(keyA);
    await prints(channel, '\x1b]52;c;\x07');
    expect(copied, isEmpty);
    expect(session.held, isNull);
  });

  test('a read of the clipboard is neither answered nor held', () async {
    final (session, channel) = open();
    session.ownKey(keyA);
    await prints(channel, '\x1b]52;c;?\x07');
    expect(copied, isEmpty);
    expect(session.held, isNull);
    expect(channel.sent.where((each) => each.contains(']52')), isEmpty);
  });

  test('only a write naming the clipboard is taken', () async {
    final (session, channel) = open();
    for (final selection in <String>['p', 's', '0', '']) {
      session.ownKey(keyA);
      await prints(channel, write('to $selection', selection: selection));
    }
    expect(copied, isEmpty);
    expect(session.held, isNull);
  });

  test('unpadded base64 is read as padded', () async {
    final (session, channel) = open();
    session.ownKey(keyA);
    await prints(channel, '\x1b]52;c;aGk\x07');
    expect(copied, <String>['hi']);
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

  test('a held key repeats, but counts only once', () async {
    final (session, channel) = open();
    session.ownKey(keyA);
    now += const Duration(seconds: 3);
    session.ownKey(
      const KeyRepeatEvent(
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        character: 'a',
        timeStamp: Duration.zero,
      ),
    );
    await prints(channel, write('while held'));
    expect(copied, isEmpty);
    expect(session.held?.text, 'while held');
  });

  test('a key the framework made up does not count', () async {
    final (session, channel) = open();
    session.ownKey(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        timeStamp: Duration.zero,
        synthesized: true,
      ),
    );
    await prints(channel, write('made up'));
    expect(copied, isEmpty);
  });

  test('two seconds after the action a write still goes through, a moment later it is held', () async {
    final (session, channel) = open();
    session.ownKey(keyA);
    now += const Duration(seconds: 2);
    await prints(channel, write('just inside'));
    expect(copied, <String>['just inside']);

    session.ownKey(keyA);
    now += const Duration(seconds: 2, milliseconds: 1);
    await prints(channel, write('just past'));
    expect(copied, <String>['just inside']);
    expect(session.held?.text, 'just past');
  });

  test('a write split across chunks is judged once it is complete', () async {
    final (session, channel) = open();
    final whole = write('split');
    session.ownKey(keyA);
    await prints(channel, whole.substring(0, 10));
    now += const Duration(seconds: 3);
    await prints(channel, whole.substring(10));
    expect(copied, isEmpty, reason: 'it ended long after the key');
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
