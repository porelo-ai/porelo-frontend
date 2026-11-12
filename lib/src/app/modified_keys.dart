import 'package:xterm/xterm.dart';

/// Sends a modified Enter as itself once the far end asks for modified keys, and a plain Enter
/// until then.
///
/// **Asked for, never assumed.** An agent reads Shift+Enter as a new line in its prompt, and asks
/// for modified keys to get it; a shell asks for nothing, and tmux in a task swallows a modified
/// Enter sent to one — so a session that always sent the long form would make Shift+Enter do
/// nothing where it used to be Enter. The request is xterm's `ESC [ > 4 ; n m`, which tmux passes to
/// its client when its terminal has the `extkeys` feature.
///
/// **The request is taken out of what is drawn.** The terminal here does not know it and reads it
/// as `ESC [ 4 ; n m` — underlined and bold from then on.
class ModifiedKeys implements TerminalInputHandler {
  /// The level the far end asked for: 0 for none, 1 or 2 for xterm's two modes.
  int level = 0;

  /// The end of the last output, held while it could still become a request.
  String _held = '';

  static final _request = RegExp(r'\x1b\[>4(?:;(\d+))?m');
  static final _partial = RegExp(r'\x1b(?:\[(?:>(?:4(?:;\d*)?)?)?)?$');

  /// Reads [output] for requests, and answers it without them, holding back an ending that may
  /// be the start of one until the next read says.
  String take(String output) {
    var text = _held + output;
    _held = '';
    final partial = _partial.firstMatch(text);
    if (partial != null) {
      _held = partial.group(0)!;
      text = text.substring(0, partial.start);
    }
    return text.replaceAllMapped(_request, (match) {
      level = int.tryParse(match.group(1) ?? '') ?? 0;
      return '';
    });
  }

  @override
  String? call(TerminalKeyboardEvent event) {
    if (level == 0 || event.key != TerminalKey.enter) return null;
    final modifiers = 1 + (event.shift ? 1 : 0) + (event.alt ? 2 : 0) + (event.ctrl ? 4 : 0);
    if (modifiers == 1) return null;
    return '\x1b[27;$modifiers;13~';
  }
}

/// Sends the cursor and page keys with a modifier as xterm writes them, the one form tmux and the programs in it read
/// whatever else holds the key: `ESC [ 1 ; m A` for an arrow, Home and End, `ESC [ 5 ; m ~` for the page keys, where m
/// is 1 plus 1 for Shift, 2 for Alt and 4 for Ctrl.
///
/// The terminal's own table sends Alt with an arrow as Ctrl with it, a habit of other terminals; a plain xterm, which
/// Porelo sets a task's tmux up for, does not, so an agent read Alt+Up as Ctrl+Up. A key with no modifier is left to
/// the table, which knows the far end's cursor mode.
class ModifiedCursorKeys implements TerminalInputHandler {
  static const _final = <TerminalKey, String>{
    TerminalKey.arrowUp: 'A',
    TerminalKey.arrowDown: 'B',
    TerminalKey.arrowRight: 'C',
    TerminalKey.arrowLeft: 'D',
    TerminalKey.end: 'F',
    TerminalKey.home: 'H',
  };

  static const _tilde = <TerminalKey, int>{TerminalKey.pageUp: 5, TerminalKey.pageDown: 6};

  @override
  String? call(TerminalKeyboardEvent event) {
    final modifiers = 1 + (event.shift ? 1 : 0) + (event.alt ? 2 : 0) + (event.ctrl ? 4 : 0);
    if (modifiers == 1) return null;
    if (_final[event.key] case final letter?) return '\x1b[1;$modifiers$letter';
    if (_tilde[event.key] case final number?) return '\x1b[$number;$modifiers~';
    return null;
  }
}
