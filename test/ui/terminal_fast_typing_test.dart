import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

void main() {
  // Harm: a person typing fast sends the agent `RReRep...`: a key pressed before the engine took a reset was added to
  // the old text, and the whole of it went out again. Composed keys, such as a dead key's backtick, must still arrive.
  testWidgets('keys pressed faster than the engine answers each go out once', (tester) async {
    final sent = StringBuffer();
    final terminal = Terminal()..onOutput = sent.write;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TerminalView(terminal, focusNode: focus, autofocus: true)),
      ),
    );
    await tester.pumpAndSettle();
    // The engine's text as it would stand if no reset ever reached it before the next key.
    for (final text in ['R', 'Re', 'Rep', 'Repl']) {
      tester.testTextInput.updateEditingValue(TextEditingValue(text: text));
      await tester.pump();
    }
    expect(sent.toString(), 'Repl');
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(text: 'Repl`', composing: TextRange(start: 4, end: 5)),
    );
    await tester.pump();
    expect(sent.toString(), 'Repl', reason: 'nothing goes out while a key is being composed');
    tester.testTextInput.updateEditingValue(const TextEditingValue(text: 'Repl`'));
    await tester.pump();
    expect(sent.toString(), 'Repl`');
  });
}
