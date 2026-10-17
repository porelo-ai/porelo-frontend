import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:xterm/xterm.dart';

import '../features/support/world.dart';

/// A modified Enter reaches a program that asked for modified keys as itself, and stays a plain
/// Enter everywhere else.
void main() {
  const vm = Machine(name: 'vm', socketPath: '/tmp/vm.sock', host: 'agent@vm', remoteSocket: '/run/s.sock');
  late FakeTerminal far;
  late Session session;

  setUp(() {
    session = Session(
      task: 'porelo-work',
      machine: vm,
      open: (executable, arguments, {columns = 80, rows = 24}) =>
          far = FakeTerminal(<String>[executable, ...arguments]),
    );
  });

  Future<void> said(String output) async {
    far.prints(output);
    await pumpEventQueue();
  }

  String typed(TerminalKey key, {bool shift = false, bool ctrl = false, bool alt = false}) {
    far.typed.clear();
    session.terminal.keyInput(key, shift: shift, ctrl: ctrl, alt: alt);
    return far.typed.join();
  }

  test('before the far end asks, Shift+Enter is a plain Enter', () async {
    await said('prompt\$ ');
    expect(typed(TerminalKey.enter, shift: true), '\r');
  });

  test('once it asks, Shift, Ctrl and Alt with Enter are sent as themselves, and Enter as Enter', () async {
    await said('\x1b[>4;2m');
    expect(typed(TerminalKey.enter, shift: true), '\x1b[27;2;13~');
    expect(typed(TerminalKey.enter, ctrl: true), '\x1b[27;5;13~');
    expect(typed(TerminalKey.enter, alt: true), '\x1b[27;3;13~');
    expect(typed(TerminalKey.enter, shift: true, ctrl: true), '\x1b[27;6;13~');
    expect(typed(TerminalKey.enter), '\r');
  });

  test('mode one is asking too', () async {
    await said('\x1b[>4;1m');
    expect(typed(TerminalKey.enter, shift: true), '\x1b[27;2;13~');
  });

  test('taking it back, either way, makes Shift+Enter a plain Enter again', () async {
    await said('\x1b[>4;2m');
    await said('\x1b[>4m');
    expect(typed(TerminalKey.enter, shift: true), '\r');
    await said('\x1b[>4;2m');
    await said('\x1b[>4;0m');
    expect(typed(TerminalKey.enter, shift: true), '\r');
  });

  test('a request split across two reads is still heard', () async {
    await said('text \x1b[>');
    await said('4;2m more');
    expect(typed(TerminalKey.enter, shift: true), '\x1b[27;2;13~');
  });

  test('the request is not drawn, so what follows is not bold and underlined', () async {
    await said('\x1b[>4;2mX');
    final plain = Terminal()..write('X');
    expect(session.terminal.buffer.lines[0].getAttributes(0), plain.buffer.lines[0].getAttributes(0));
    expect(session.terminal.buffer.lines[0].toString().trim(), 'X');
  });

  test('an escape that only begins like a request is drawn as it came', () async {
    await said('\x1b[>');
    await said('0c');
    await said('\x1b[1mB');
    // A secondary device attributes reply is not a request, and must not be swallowed or held.
    expect(typed(TerminalKey.enter, shift: true), '\r');
    final bold = Terminal()..write('\x1b[1mB');
    expect(session.terminal.buffer.lines[0].getAttributes(0), bold.buffer.lines[0].getAttributes(0));
  });
}
