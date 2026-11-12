import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../app/session.dart';
import 'terminal_copy.dart';
import 'tokens.dart';

/// A session's terminal on screen, telling the session when the person acts in it.
///
/// **Only a drag the person made here lets a write to the clipboard through**: one pointer pressed with the main
/// button, moved to another cell and let go, whose text the session reads off this screen ([Session.dragged]). A key,
/// a new press or the keyboard leaving ends it; every other write is held ([Session.held]). Every terminal of a
/// [Session] is drawn with this.
class SessionTerminal extends StatefulWidget {
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
  State<SessionTerminal> createState() => _SessionTerminalState();
}

class _SessionTerminalState extends State<SessionTerminal> {
  /// The pointer that may be dragging, pressed with the main button while no other was down; null otherwise.
  int? _dragging;

  /// The cell it was pressed on.
  CellOffset? _from;

  /// How many pointers are down here.
  int _down = 0;

  Session get _session => widget.session;

  /// The cell of the terminal's buffer under [position] on the screen, or null while it is not laid out.
  CellOffset? _cellAt(Offset position) {
    TerminalViewState? view;
    void visit(Element element) {
      if (element is StatefulElement && element.state is TerminalViewState) {
        view = element.state as TerminalViewState;
      } else {
        element.visitChildElements(visit);
      }
    }

    context.visitChildElements(visit);
    final render = view?.renderTerminal;
    if (render == null || !render.hasSize) return null;
    return render.getCellOffset(render.globalToLocal(position));
  }

  void _pressed(PointerDownEvent event) {
    _session.pressed();
    _down++;
    final alone = _down == 1 && event.buttons == kPrimaryButton;
    _dragging = alone ? event.pointer : null;
    _from = alone ? _cellAt(event.position) : null;
  }

  void _letGo(PointerUpEvent event) {
    _down = _down > 0 ? _down - 1 : 0;
    final from = _from;
    final dragged = event.pointer == _dragging;
    _dragging = null;
    _from = null;
    if (!dragged || from == null) return;
    final to = _cellAt(event.position);
    if (to != null && to != from) _session.dragged(from, to);
  }

  void _cancelled(PointerCancelEvent event) {
    _down = _down > 0 ? _down - 1 : 0;
    _dragging = null;
    _from = null;
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _pressed,
    onPointerUp: _letGo,
    onPointerCancel: _cancelled,
    // Holds no keyboard of its own: it hears the terminal's leaving.
    child: Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (!focused) _session.lostFocus();
      },
      child: TerminalView(
        _session.terminal,
        key: widget.viewKey,
        scrollController: widget.scrollController,
        theme: widget.theme,
        controller: widget.controller,
        shortcuts: terminalShortcuts,
        focusNode: widget.focusNode,
        // Seen here first, before any shortcut: a typed letter goes on to the far end as text, never back past here.
        onKeyEvent: (node, event) {
          _session.ownKey(event);
          return widget.onKey?.call(node, event) ?? KeyEventResult.ignored;
        },
        autofocus: true,
        alwaysShowCursor: widget.alwaysShowCursor,
        readOnly: !_session.live,
        padding: widget.padding,
        hardwareKeyboardOnly: widget.hardwareKeyboardOnly,
        textStyle: widget.textStyle,
      ),
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
        width: Sizes.heldCopyWhole,
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
///
/// **Clipped before it is escaped**, so what is said left out counts what would land on the clipboard, and no marker
/// is ever cut in two.
class CopyPreview {
  CopyPreview._(this.size, this.preview, this.shortened);

  /// Its preview for [text], shortened in the middle where long.
  factory CopyPreview.of(String text) {
    final lines = _lines(text);
    final characters = text.runes.length;
    final endsInABreak = lines.last.end.isNotEmpty;
    final size =
        '$characters ${characters == 1 ? 'character' : 'characters'} in ${lines.length} '
        '${lines.length == 1 ? 'line' : 'lines'}, '
        '${endsInABreak ? 'ending in a line break' : 'with no line break at the end'}';
    if (lines.length <= _mostLines && characters <= _mostShown) return CopyPreview._(size, _shownAll(lines), false);
    if (lines.length == 1) return CopyPreview._(size, _clippedMiddle(lines.single), true);

    final head = lines.take(_headLines < lines.length - 1 ? _headLines : lines.length - 1).toList();
    final leftOut = lines.sublist(head.length, lines.length - 1);
    final leftOutCharacters = leftOut.fold<int>(0, (sum, line) => sum + line.characters);
    final preview = <String>[
      ...head.map(_clippedEnd),
      if (leftOut.isNotEmpty)
        '… $leftOutCharacters characters in ${leftOut.length} ${leftOut.length == 1 ? 'line' : 'lines'} left out …',
      _clippedStart(lines.last),
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
  static String shown(String text) => _shownAll(_lines(text));

  static const int _mostLines = 12;
  static const int _mostShown = 1200;
  static const int _headLines = 6;
  static const int _mostPerLine = 200;

  /// The text's lines, each with the break that ends it: LF, CR and CRLF alike, since a shell runs on each.
  static List<_Line> _lines(String text) {
    final lines = <_Line>[];
    var from = 0;
    for (final match in _break.allMatches(text)) {
      lines.add(_Line(text.substring(from, match.start).runes.toList(), match[0]!));
      from = match.end;
    }
    if (from < text.length || lines.isEmpty) lines.add(_Line(text.substring(from).runes.toList(), ''));
    return lines;
  }

  static final _break = RegExp('\r\n|\r|\n');

  static String _shownAll(List<_Line> lines) => lines.map((line) => _escaped(line.runes) + line.mark).join('\n');

  static String _clippedEnd(_Line line) => line.runes.length <= _mostPerLine
      ? _escaped(line.runes) + line.mark
      : '${_escaped(line.runes.take(_mostPerLine))} … ${line.runes.length - _mostPerLine} more characters${line.mark}';

  static String _clippedStart(_Line line) => line.runes.length <= _mostPerLine
      ? _escaped(line.runes) + line.mark
      : '${line.runes.length - _mostPerLine} characters before … '
            '${_escaped(line.runes.skip(line.runes.length - _mostPerLine))}${line.mark}';

  static String _clippedMiddle(_Line line) {
    const half = _mostPerLine ~/ 2;
    final runes = line.runes;
    if (runes.length <= _mostPerLine) return _escaped(runes) + line.mark;
    return '${_escaped(runes.take(half))} … ${runes.length - 2 * half} characters left out … '
        '${_escaped(runes.skip(runes.length - half))}${line.mark}';
  }

  static String _escaped(Iterable<int> runes) =>
      String.fromCharCodes(runes).replaceAllMapped(_hidden, (match) => _visible(match[0]!.runes.single));

  static String _visible(int rune) {
    if (rune == 0x09) return '⇥';
    if (rune < 0x20) return String.fromCharCode(0x2400 + rune);
    if (rune == 0x7F) return '␡';
    return '⟨U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')}⟩';
  }

  /// A character that shows as nothing or as a space, turns the text around it, or changes the one before it:
  /// controls, format characters, every default-ignorable code point, combining marks, and spaces but the plain one.
  static final _hidden = RegExp(
    r'[\p{Cc}\p{Cf}\p{M}\p{Default_Ignorable_Code_Point}\p{Zl}\p{Zp}'
    r'   -   　ᅟᅠㅤﾠ￹-￻]',
    unicode: true,
  );
}

/// One line of a copy, and the break that ends it, or none.
class _Line {
  _Line(this.runes, this.end);

  final List<int> runes;
  final String end;

  /// Its characters as copied, its break included.
  int get characters => runes.length + end.length;

  /// Its break, as shown: ⏎ for LF, ␍ for CR.
  String get mark => switch (end) {
    '\n' => '⏎',
    '\r' => '␍',
    '\r\n' => '␍⏎',
    _ => '',
  };
}
