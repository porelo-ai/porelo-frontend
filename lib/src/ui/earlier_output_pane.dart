import 'package:flutter/material.dart';

import '../app/earlier_output.dart';
import 'terminal_look.dart';
import 'tokens.dart';

/// A terminal session's earlier output, read only, above the live terminal, newest line at the bottom beside it.
///
/// **Never the terminal's own buffer**: these lines are a list of their own, so nothing the person is reading moves
/// when output arrives or older lines come in. **What ends the list is said**: its top says nothing older is kept only where
/// the daemon said so; a recording that is not kept, a refusal and a full list are each
/// said in their own words.
class EarlierOutputPane extends StatefulWidget {
  /// Constructor taking what is shown and what closes it.
  const EarlierOutputPane({required this.earlier, required this.onClose, this.onSelected, super.key});

  /// The earlier output of the session.
  final EarlierOutput earlier;

  /// Closes the pane.
  final VoidCallback onClose;

  /// Told the text selected in the pane, or null where nothing is: the pane cannot take the keyboard, so the window
  /// copies it for the key.
  final ValueChanged<String?>? onSelected;

  @override
  State<EarlierOutputPane> createState() => _EarlierOutputPaneState();
}

class _EarlierOutputPaneState extends State<EarlierOutputPane> {
  /// Selecting here never takes the keyboard: the terminal keeps the frame's focus node.
  final FocusNode _selectionFocus = FocusNode(canRequestFocus: false, skipTraversal: true);

  @override
  void dispose() {
    _selectionFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _askForMore();
  }

  @override
  void didUpdateWidget(EarlierOutputPane old) {
    super.didUpdateWidget(old);
    if (old.earlier != widget.earlier) _askForMore();
  }

  void _askForMore() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) widget.earlier.more();
  });

  @override
  Widget build(BuildContext context) {
    final console = TerminalLook.consoleOf(context);
    final text = TerminalLook.text(size: Sizes.sessionText);
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: console.muted);
    return ColoredBox(
      color: TerminalLook.screen.background,
      child: ListenableBuilder(
        listenable: widget.earlier,
        builder: (context, _) {
          final lines = widget.earlier.lines;
          final divider = widget.earlier.mayOverlap && lines.isNotEmpty;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.normal),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Earlier output, read only: ${lines.length} ${lines.length == 1 ? 'line' : 'lines'}',
                        key: const Key('earlier-title'),
                        style: small?.copyWith(color: console.strong, fontWeight: FontWeight.w600),
                      ),
                    ),
                    ExcludeFocus(
                      child: TextButton(
                        key: const Key('earlier-close'),
                        onPressed: widget.onClose,
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SelectionArea(
                  focusNode: _selectionFocus,
                  onSelectionChanged: (content) => widget.onSelected?.call(content?.plainText),
                  // The newest line is index 0 at the bottom: older lines come in at the top and move nothing.
                  child: ListView.builder(
                    key: const Key('earlier-list'),
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: Sizes.terminalSide),
                    itemCount: lines.length + 1 + (divider ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (divider && index == 0) return _divider(small);
                      final at = divider ? index - 1 : index;
                      if (at == lines.length) return _top(context, small);
                      return Text(shownLine(lines[lines.length - 1 - at]), style: text);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Between the newest earlier line and the terminal, where no line matched what the terminal shows.
  Widget _divider(TextStyle? style) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.small),
    child: Text(
      widget.earlier.matched == 0
          ? 'The lines above this one and the terminal’s may overlap: no line here matched what the terminal shows.'
          : 'The lines above this one and the terminal’s may overlap: only ${widget.earlier.matched} of the terminal’s '
                'lines matched them.',
      key: const Key('earlier-overlap'),
      style: style,
    ),
  );

  /// What stands above the oldest line held: a request out, how it ended, or an ask for more.
  Widget _top(BuildContext context, TextStyle? style) {
    final earlier = widget.earlier;
    if (earlier.end == EarlierEnd.more) {
      // Reaching this far up is the person's ask for the page beyond it.
      _askForMore();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.small),
        child: Text('Loading earlier output…', key: const Key('earlier-status'), style: style),
      );
    }
    final (words, retry) = switch (earlier.end) {
      EarlierEnd.more => ('', false),
      EarlierEnd.start => ('Nothing older is kept.', false),
      EarlierEnd.notKept => ('This session’s earlier output is not kept.', false),
      EarlierEnd.failed => ('Earlier output could not be read. ${earlier.problem ?? ''}', true),
      EarlierEnd.full => (
        'Showing the latest ${EarlierOutput.mostLines} earlier lines; older ones are not loaded, and this is not the '
            'session’s start.',
        false,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.small),
      child: Wrap(
        spacing: Space.normal,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(words, key: const Key('earlier-status'), style: style),
          if (retry)
            ExcludeFocus(
              child: TextButton(
                key: const Key('earlier-retry'),
                onPressed: earlier.retry,
                child: const Text('Try again'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Control characters a recording may still hold, and those that turn the order of text around.
final _notDrawn = RegExp('[\\x00-\\x08\\x0B-\\x1F\\x7F-\\x9F\\u061C\\u200E\\u200F\\u202A-\\u202E\\u2066-\\u2069]');

/// [line] as the pane draws it: without control characters or direction overrides, which would draw as boxes or make
/// a line read as something it is not. A line is cut where it is stored ([cutLine]).
String shownLine(String line) => line.replaceAll(_notDrawn, '');
