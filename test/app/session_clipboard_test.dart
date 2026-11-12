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
/// running it, or clearing what the person copied. Only a write of the very text the person just dragged across in
/// that terminal goes through without a word, once; any other is held for the person to allow.
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

  /// Shows [shown] on the screen's first line, and has the person drag across it from its first to its last cell.
  Future<void> dragOver(Session session, _Channel channel, String shown) async {
    await prints(channel, '\x1b[2J\x1b[H$shown');
    session.dragged(const CellOffset(0, 0), CellOffset(shown.length - 1, 0));
  }

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

  // Harm: a task's text pasted by the person, who copied something else, into a shell where a line break runs it.
  test('a write of what the person dragged across goes through, once', () async {
    final (session, channel) = open();
    await dragOver(session, channel, 'copy me');

    await prints(channel, write('copy me') + write('copy me'));

    expect(copied, <String>['copy me']);
    expect(session.held?.text, 'copy me', reason: 'one drag, one write');
  });

  test('after a drag, a write of other text is held, and the dragged text still goes through', () async {
    final (session, channel) = open();
    await dragOver(session, channel, 'copy me');

    await prints(channel, write('rm -rf ~\n'));
    expect(copied, isEmpty, reason: 'a task beating the copy to the clipboard is asked about');
    expect(session.held?.text, 'rm -rf ~\n');

    await prints(channel, write('copy me'));
    expect(copied, <String>['copy me']);
  });

  test('the dragged text with a line break added is held', () async {
    final (session, channel) = open();
    await dragOver(session, channel, 'rm -rf ~');

    await prints(channel, write('rm -rf ~\n'));

    expect(copied, isEmpty, reason: 'the added line break would run it when pasted');
    expect(session.held?.text, 'rm -rf ~\n');
  });

  test('a drag over lines matches their copy with or without the spaces at their ends', () async {
    final (session, channel) = open();
    await prints(channel, '\x1b[2J\x1b[Hfirst   \r\nsecond');
    session.dragged(const CellOffset(5, 1), const CellOffset(0, 0));
    await prints(channel, write('first   \nsecond'));
    expect(copied, <String>['first   \nsecond'], reason: 'drawn backwards, end cell counted, spaces kept');

    session.dragged(const CellOffset(0, 0), const CellOffset(5, 1));
    await prints(channel, write('first\nsecon'));
    expect(copied, <String>['first   \nsecond', 'first\nsecon'], reason: 'end cell left out, spaces dropped');
  });

  // Harm: a dragged command copied with a carriage return or another control after it, which runs it when pasted.
  test('a control after the dragged text is held, only plain spaces at a line end are dropped', () async {
    final (session, channel) = open();
    for (final text in <String>['command\r', 'command\t', 'command \r', 'command\x0b', 'command\x0c', 'command\x85']) {
      await dragOver(session, channel, 'command');
      await prints(channel, write(text));
      expect(copied, isEmpty, reason: '${jsonEncode(text)} is not what was dragged');
      expect(session.held?.text, text);
    }
    await prints(channel, '\x1b[2J\x1b[Hfirst\r\nsecond');
    session.dragged(const CellOffset(0, 0), const CellOffset(5, 1));
    await prints(channel, write('first\r\nsecond'));
    expect(copied, isEmpty, reason: 'a carriage return between the lines was not dragged');
  });

  // Harm: a gap the cursor skipped shows as a space, and a copy without it is another command.
  test('a gap the cursor skipped counts as the space it shows', () async {
    final (session, channel) = open();
    await prints(channel, '\x1b[2J\x1b[Hr\x1b[Cm -rf');
    session.dragged(const CellOffset(0, 0), const CellOffset(6, 0));
    await prints(channel, write('rm -rf'));
    expect(copied, isEmpty, reason: 'the screen showed "r m -rf"');
    expect(session.held?.text, 'rm -rf');

    session.dragged(const CellOffset(0, 0), const CellOffset(6, 0));
    await prints(channel, write('r m -rf'));
    expect(copied, <String>['r m -rf']);
  });

  test('a wide character whose first cell the drag ends on counts', () async {
    final (session, channel) = open();
    await prints(channel, '\x1b[2J\x1b[Hab漢字');
    session.dragged(const CellOffset(0, 0), const CellOffset(2, 0));
    await prints(channel, write('ab漢'));
    expect(copied, <String>['ab漢']);
  });

  // Harm: a drag the task heard was the task's to turn into any copy, whatever the screen showed.
  test('while the task hears the mouse a drag lets nothing through', () async {
    final (session, channel) = open();
    await prints(channel, '\x1b[?1002h');
    await dragOver(session, channel, 'copy me');
    await prints(channel, write('copy me'));
    expect(copied, isEmpty);
    expect(session.held?.text, 'copy me');
  });

  // Harm: text the person typed through an input method, which no key reports, copied as the drag's.
  test('text the terminal sends after the drag ends what it lets through', () async {
    final (session, channel) = open();
    await dragOver(session, channel, 'copy me');
    session.terminal.textInput('漢');
    await prints(channel, write('copy me'));
    expect(copied, isEmpty);
    expect(session.held?.text, 'copy me');
  });

  test('after the session is over a drag lets nothing through, nor is anything held', () async {
    final (session, channel) = open();
    await dragOver(session, channel, 'copy me');
    channel.ends();
    await pumpEventQueue();
    await prints(channel, write('copy me'));
    expect(copied, isEmpty);
    expect(session.held, isNull);
  });

  test('typing lets no write through', () async {
    final (session, channel) = open();
    await prints(channel, 'typed');
    session.ownKey(keyA);
    await prints(channel, write('typed'));
    expect(copied, isEmpty);
    expect(session.held?.text, 'typed');
  });

  test('a press of the pointer that is no drag lets no write through', () async {
    final (session, channel) = open();
    await prints(channel, 'clicked');
    session.pressed();
    await prints(channel, write('clicked'));
    expect(copied, isEmpty);
  });

  for (final (what, end) in <(String, void Function(Session))>[
    ('a key', (session) => session.ownKey(keyA)),
    (
      'a key held down',
      (session) => session.ownKey(
        const KeyRepeatEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: LogicalKeyboardKey.keyA,
          character: 'a',
          timeStamp: Duration.zero,
        ),
      ),
    ),
    (
      'a paste shortcut',
      (session) => session.ownKey(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.insert,
          logicalKey: LogicalKeyboardKey.insert,
          timeStamp: Duration.zero,
        ),
      ),
    ),
    ('a new press of the pointer', (session) => session.pressed()),
    ('the terminal losing the keyboard', (session) => session.lostFocus()),
  ]) {
    test('$what after the drag ends what it lets through', () async {
      final (session, channel) = open();
      await dragOver(session, channel, 'copy me');
      end(session);

      await prints(channel, write('copy me'));

      expect(copied, isEmpty);
      expect(session.held?.text, 'copy me');
    });
  }

  test('two seconds after the drag its write still goes through, a moment later it is held', () async {
    final (session, channel) = open();
    await dragOver(session, channel, 'just inside');
    now += const Duration(seconds: 2);
    await prints(channel, write('just inside'));
    expect(copied, <String>['just inside']);

    await dragOver(session, channel, 'just past');
    now += const Duration(seconds: 2, milliseconds: 1);
    await prints(channel, write('just past'));
    expect(copied, <String>['just inside']);
    expect(session.held?.text, 'just past');
  });

  test('a silent write clears one that was held', () async {
    final (session, channel) = open();
    await prints(channel, write('held'));
    await dragOver(session, channel, 'dragged');
    await prints(channel, write('dragged'));
    expect(copied, <String>['dragged']);
    expect(session.held, isNull);
  });

  test('an empty write leaves the clipboard alone, and is not held', () async {
    final (session, channel) = open();
    await dragOver(session, channel, 'copy me');
    await prints(channel, '\x1b]52;c;\x07');
    expect(copied, isEmpty);
    expect(session.held, isNull);
  });

  test('a read of the clipboard is neither answered nor held', () async {
    final (session, channel) = open();
    await dragOver(session, channel, 'copy me');
    await prints(channel, '\x1b]52;c;?\x07');
    expect(copied, isEmpty);
    expect(session.held, isNull);
    expect(channel.sent.where((each) => each.contains(']52')), isEmpty);
  });

  test('only a write naming the clipboard is taken', () async {
    final (session, channel) = open();
    for (final selection in <String>['p', 's', '0', 'q7']) {
      await dragOver(session, channel, 'to $selection');
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
    await dragOver(session, channel, 'dragged');
    await prints(channel, write('dragged', selection: ''));
    expect(copied, <String>['dragged']);
  });

  test('unpadded base64 is read as padded', () async {
    final (session, channel) = open();
    await dragOver(session, channel, 'hi');
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

  test('a write split across chunks is judged once it is complete', () async {
    final (session, channel) = open();
    final whole = write('split');
    await dragOver(session, channel, 'split');
    await prints(channel, whole.substring(0, 10));
    now += const Duration(seconds: 3);
    await prints(channel, whole.substring(10));
    expect(copied, isEmpty, reason: 'it ended long after the drag');
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
