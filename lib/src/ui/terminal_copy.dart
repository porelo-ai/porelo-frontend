import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/xterm.dart';

import 'tokens.dart';

/// The text of [range] as a person sees it on the screen: a cell nothing was written into reads as
/// the space it shows, up to the last cell written on its line.
///
/// xterm's own copy leaves such cells out, so what a program that moves the cursor rather than
/// writing a space - Claude Code does - showed as words came out as one.
String copiedText(Terminal terminal, BufferRange range) {
  final from = range.normalized;
  final out = StringBuffer();
  for (final segment in from.toSegments()) {
    if (segment.line < 0 || segment.line >= terminal.buffer.height) continue;
    final line = terminal.buffer.lines[segment.line];
    if (!(segment.line == from.begin.y || segment.line == 0 || line.isWrapped)) out.write('\n');
    final end = segment.end == null || segment.end! > line.length ? line.length : segment.end!;
    final text = StringBuffer();
    var written = 0;
    var i = segment.start ?? 0;
    while (i < end) {
      final codePoint = line.getCodePoint(i);
      final width = line.getWidth(i);
      if (codePoint == 0) {
        text.write(' ');
        i++;
        continue;
      }
      text.writeCharCode(codePoint);
      written = text.length;
      // The cell after a wide character belongs to it.
      i += width < 1 ? 1 : width;
    }
    out.write(text.toString().substring(0, written));
  }
  return out.toString();
}

/// Copying out of a terminal as it shows: its copy keys send this, and [CopiesAsShown] answers.
class CopyAsShownIntent extends Intent {
  /// The intent, which carries nothing.
  const CopyAsShownIntent();
}

/// The terminal's own keys, copying as shown and accepting desktop terminal paste keys.
Map<ShortcutActivator, Intent> get terminalShortcuts => <ShortcutActivator, Intent>{
  for (final entry in defaultTerminalShortcuts.entries)
    entry.key: entry.value is CopySelectionTextIntent ? const CopyAsShownIntent() : entry.value,
  if (defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.windows) ...{
    const SingleActivator(LogicalKeyboardKey.keyV, control: true, shift: true): const PasteTextIntent(
      SelectionChangedCause.keyboard,
    ),
    const SingleActivator(LogicalKeyboardKey.insert, shift: true): const PasteTextIntent(
      SelectionChangedCause.keyboard,
    ),
  },
};

/// Names the paste shortcut beside a terminal.
class TerminalPasteHint extends StatelessWidget {
  /// Creates the shared terminal hint.
  const TerminalPasteHint({super.key, this.shiftSelects = false});

  /// Whether a Shift+drag selects in this terminal whatever its program asked of the mouse.
  final bool shiftSelects;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.small, vertical: Space.tight),
    child: Text(
      '${shiftSelects ? 'Select with Shift+drag · ' : ''}'
      '${defaultTargetPlatform == TargetPlatform.macOS ? 'Paste with ⌘V' : 'Paste with Ctrl+Shift+V'}',
    ),
  );
}

/// Answers [CopyAsShownIntent] for the terminal under it, with what [controller] has selected.
class CopiesAsShown extends StatelessWidget {
  /// Constructor taking the terminal, its selection, and what is drawn.
  const CopiesAsShown({super.key, required this.terminal, required this.controller, required this.child});

  /// The terminal whose text is copied.
  final Terminal terminal;

  /// Its selection.
  final TerminalController controller;

  /// What is drawn, the terminal among it.
  final Widget child;

  @override
  Widget build(BuildContext context) => Actions(
    actions: <Type, Action<Intent>>{
      CopyAsShownIntent: CallbackAction<CopyAsShownIntent>(
        onInvoke: (_) {
          final selection = controller.selection;
          if (selection != null) Clipboard.setData(ClipboardData(text: copiedText(terminal, selection)));
          return null;
        },
      ),
    },
    child: child,
  );
}
