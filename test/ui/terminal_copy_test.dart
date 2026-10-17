import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/terminal_copy.dart';
import 'package:xterm/xterm.dart';

/// Holds what is copied out of a terminal to what a person sees there.
void main() {
  BufferRange all(Terminal terminal) =>
      BufferRangeLine(CellOffset(0, 0), CellOffset(terminal.viewWidth - 1, terminal.buffer.height - 1));

  test('a gap the program jumped over is copied as the spaces it shows', () {
    // Claude Code moves the cursor instead of writing spaces.
    final terminal = Terminal()..write('I\x1b[1Cchecked\x1b[1Cthe\x1b[3Cfile');

    expect(terminal.buffer.getText(all(terminal)).trim(), 'Icheckedthefile');
    expect(copiedText(terminal, all(terminal)).trim(), 'I checked the   file');
  });

  test('a line ends where its last written cell does, and a wide character is one character', () {
    final terminal = Terminal()..write('漢字\x1b[2Cx\r\nnext');

    expect(copiedText(terminal, all(terminal)).trimRight(), '漢字  x\nnext');
  });

  testWidgets('Ctrl+Shift+C in a terminal copies the selection as it shows', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final terminal = Terminal()..write('I\x1b[1Cchecked');
    final selection = TerminalController();
    addTearDown(selection.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CopiesAsShown(
          terminal: terminal,
          controller: selection,
          child: TerminalView(terminal, controller: selection, shortcuts: copyAsShownShortcuts, autofocus: true),
        ),
      ),
    );
    selection.setSelection(terminal.buffer.createAnchor(0, 0), terminal.buffer.createAnchor(9, 0));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(copied, 'I checked');
  });
}
