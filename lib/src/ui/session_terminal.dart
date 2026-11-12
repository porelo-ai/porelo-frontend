import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../app/session.dart';
import 'terminal_copy.dart';
import 'tokens.dart';

/// A session's terminal on screen, telling the session when the person acts in it.
///
/// **Only what the person does here counts**: a key's first press and a pointer pressed or released, never hover,
/// move or scroll, and never what the terminal sends by itself. Every terminal of a [Session] is drawn with this, so a
/// write to the clipboard right after the person's own action goes through, and no other ([Session.held]).
class SessionTerminal extends StatelessWidget {
  /// Constructor taking the session and how its terminal is drawn.
  const SessionTerminal({
    required this.session,
    required this.viewKey,
    required this.theme,
    required this.controller,
    required this.textStyle,
    required this.padding,
    this.focusNode,
    this.onKey,
    this.scrollController,
    this.alwaysShowCursor = false,
    this.hardwareKeyboardOnly = false,
    super.key,
  });

  /// The session whose terminal this is.
  final Session session;

  /// The terminal's own key, which tests find it by.
  final Key viewKey;

  /// Its colours.
  final TerminalTheme theme;

  /// Its selection.
  final TerminalController controller;

  /// Its font.
  final TerminalStyle textStyle;

  /// Room around the screen.
  final EdgeInsets padding;

  /// The keyboard it is handed, or null for its own.
  final FocusNode? focusNode;

  /// Sees a key before the far end does; what it handles never gets there.
  final FocusOnKeyEventCallback? onKey;

  /// Where the screen stands in its scrollback, or null for its own.
  final ScrollController? scrollController;

  /// Whether the cursor shows when the terminal does not hold the keyboard.
  final bool alwaysShowCursor;

  /// Whether every key, letters included, is read from the keyboard's own events.
  final bool hardwareKeyboardOnly;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => session.ownAction(),
    onPointerUp: (_) => session.ownAction(),
    child: TerminalView(
      session.terminal,
      key: viewKey,
      scrollController: scrollController,
      theme: theme,
      controller: controller,
      shortcuts: terminalShortcuts,
      focusNode: focusNode,
      // Seen here first, before any shortcut: a typed letter goes on to the far end as text, never back past here.
      onKeyEvent: (node, event) {
        session.ownKey(event);
        return onKey?.call(node, event) ?? KeyEventResult.ignored;
      },
      autofocus: true,
      alwaysShowCursor: alwaysShowCursor,
      readOnly: !session.live,
      padding: padding,
      hardwareKeyboardOnly: hardwareKeyboardOnly,
      textStyle: textStyle,
    ),
  );
}

/// What a session's task asked to put on this computer's clipboard by itself, asked about inside its own view: the
/// size, a preview that shows what it hides, and *Copy* or *Don't copy*.
///
/// **Never in a dialog**, which would cover another task's terminal. **The buttons take no keyboard**, so Enter typed
/// into the terminal never copies; and each bar is the one copy it shows, so a newer one replaces it whole.
class TerminalCopyAsk extends StatelessWidget {
  /// Constructor taking the session.
  const TerminalCopyAsk({super.key, required this.session});

  /// The session whose task asks.
  final Session session;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => switch (session.held) {
      final held? => _Ask(key: ObjectKey(held), session: session, held: held),
      null => const SizedBox.shrink(),
    },
  );
}

class _Ask extends StatelessWidget {
  const _Ask({super.key, required this.session, required this.held});

  final Session session;
  final HeldCopy held;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final copy = CopyPreview.of(held.text);
    return Container(
      key: const Key('terminal-copy-ask'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: Space.small),
      padding: const EdgeInsets.all(Space.normal),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant, width: Sizes.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${session.task} wants to put ${copy.size} on this computer’s clipboard. Check it before you paste it '
            'anywhere: a line break runs what is before it in a shell.',
            key: const Key('terminal-copy-size'),
          ),
          const SizedBox(height: Space.small),
          SelectableText(
            copy.preview,
            key: const Key('terminal-copy-preview'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: Space.small),
          ExcludeFocus(
            child: Wrap(
              spacing: Space.small,
              runSpacing: Space.tight,
              children: <Widget>[
                FilledButton(
                  key: const Key('terminal-copy-allow'),
                  onPressed: () => session.copyHeld(held),
                  child: const Text('Copy'),
                ),
                OutlinedButton(
                  key: const Key('terminal-copy-refuse'),
                  onPressed: () => session.dropHeld(held),
                  child: const Text('Don’t copy'),
                ),
                if (copy.shortened)
                  TextButton(
                    key: const Key('terminal-copy-whole'),
                    onPressed: () => _showWhole(context, copy),
                    child: const Text('Show all of it'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showWhole(BuildContext context, CopyPreview copy) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('What ${session.task} would copy: ${copy.size}'),
      content: SizedBox(
        width: Sizes.dialogWords * 2,
        child: SingleChildScrollView(
          child: SelectableText(
            CopyPreview.shown(held.text),
            key: const Key('terminal-copy-whole-text'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
      actions: <Widget>[TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    ),
  );
}

/// The text a task would copy, as a person can judge it: every character that would not show, shows.
class CopyPreview {
  CopyPreview._(this.size, this.preview, this.shortened);

  /// Its preview for [text], shortened in the middle where long.
  factory CopyPreview.of(String text) {
    final characters = text.runes.length;
    final breaks = '\n'.allMatches(text).length;
    final endsInABreak = text.endsWith('\n');
    final lineCount = breaks + (endsInABreak ? 0 : 1);
    final size =
        '$characters ${characters == 1 ? 'character' : 'characters'} in $lineCount '
        '${lineCount == 1 ? 'line' : 'lines'}, ${endsInABreak ? 'ending in a line break' : 'with no line break at the end'}';
    final lines = (endsInABreak ? text.substring(0, text.length - 1) : text).split('\n');
    final shownLines = <String>[
      for (final (i, line) in lines.indexed) _line(line, i < lines.length - 1 || endsInABreak),
    ];
    final whole = shownLines.join('\n');
    if (shownLines.length <= _mostLines && whole.length <= _mostShown) return CopyPreview._(size, whole, false);

    if (shownLines.length == 1) return CopyPreview._(size, _clippedMiddle(whole), true);
    final head = shownLines.take(_headLines < shownLines.length - 1 ? _headLines : shownLines.length - 1);
    final leftOut = lines.sublist(head.length, lines.length - 1);
    final leftOutCharacters = leftOut.fold<int>(0, (sum, line) => sum + line.runes.length + 1);
    final preview = <String>[
      ...head.map(_clippedEnd),
      if (leftOut.isNotEmpty)
        '… $leftOutCharacters characters in ${leftOut.length} ${leftOut.length == 1 ? 'line' : 'lines'} left out …',
      _clippedStart(shownLines.last),
    ].join('\n');
    return CopyPreview._(size, preview, true);
  }

  /// How much it is, in characters and lines, and whether it ends in a line break.
  final String size;

  /// What it would write, line breaks and hidden characters shown.
  final String preview;

  /// Whether [preview] leaves some of it out.
  final bool shortened;

  /// All of [text], escaped the same way as the preview.
  static String shown(String text) {
    final endsInABreak = text.endsWith('\n');
    final lines = (endsInABreak ? text.substring(0, text.length - 1) : text).split('\n');
    return <String>[for (final (i, line) in lines.indexed) _line(line, i < lines.length - 1 || endsInABreak)]
        .join('\n');
  }

  static const int _mostLines = 12;
  static const int _mostShown = 1200;
  static const int _headLines = 6;
  static const int _mostPerLine = 200;

  static String _clippedEnd(String line) {
    final runes = line.runes.toList();
    if (runes.length <= _mostPerLine) return line;
    return '${String.fromCharCodes(runes.take(_mostPerLine))} … ${runes.length - _mostPerLine} more characters';
  }

  static String _clippedStart(String line) {
    final runes = line.runes.toList();
    if (runes.length <= _mostPerLine) return line;
    return '${runes.length - _mostPerLine} characters before … '
        '${String.fromCharCodes(runes.skip(runes.length - _mostPerLine))}';
  }

  static String _clippedMiddle(String line) {
    final runes = line.runes.toList();
    final half = _mostPerLine ~/ 2;
    return '${String.fromCharCodes(runes.take(half))} … ${runes.length - 2 * half} characters left out … '
        '${String.fromCharCodes(runes.skip(runes.length - half))}';
  }

  static String _line(String line, bool broken) {
    final out = StringBuffer();
    for (final rune in line.runes) {
      out.write(_visible(rune));
    }
    if (broken) out.write('⏎');
    return out.toString();
  }

  static String _visible(int rune) {
    if (rune == 0x09) return '⇥';
    if (rune < 0x20) return String.fromCharCode(0x2400 + rune);
    if (rune == 0x7F) return '␡';
    if (_hidden(rune)) return '⟨U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')}⟩';
    return String.fromCharCode(rune);
  }

  /// A character that shows as nothing, as a space, or that turns the text around it.
  static bool _hidden(int rune) =>
      (rune >= 0x80 && rune <= 0x9F) || // C1 controls
      rune == 0xA0 || // no-break space
      rune == 0xAD || // soft hyphen
      rune == 0x034F || // combining grapheme joiner
      rune == 0x061C || // Arabic letter mark
      rune == 0x115F ||
      rune == 0x1160 ||
      rune == 0x1680 ||
      rune == 0x180E ||
      (rune >= 0x2000 && rune <= 0x200F) || // spaces of width, zero-width, direction marks
      (rune >= 0x2028 && rune <= 0x202F) || // line and paragraph separators, embeddings, narrow no-break space
      (rune >= 0x205F && rune <= 0x206F) || // word joiner, invisible operators, isolates
      rune == 0x3000 ||
      rune == 0x3164 ||
      (rune >= 0xFE00 && rune <= 0xFE0F) || // variation selectors
      rune == 0xFEFF ||
      rune == 0xFFA0 ||
      (rune >= 0xFFF9 && rune <= 0xFFFB) ||
      (rune >= 0xE0000 && rune <= 0xE007F) || // tag characters
      (rune >= 0xE0100 && rune <= 0xE01EF); // variation selectors supplement
}
