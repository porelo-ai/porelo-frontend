import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../app/desk.dart';
import '../app/session.dart';
import 'panes.dart';
import 'package:guided_walk/guided_walk.dart';
import 'tokens.dart';
import 'terminal_copy.dart';
import 'terminal_links.dart';
import 'terminal_look.dart';

/// A shell inside running work, drawn in the window.
///
/// **The window is not the session.** What is at the far end is a multiplexer inside the
/// container, so closing this leaves it running and opening it again finds it as it was. Two of
/// the sentences on this screen exist only to say that, because an interface that people think
/// ends their work when they leave it is one they do not leave.
class SessionView extends StatefulWidget {
  /// Constructor taking the session and the way out.
  const SessionView({
    required this.session,
    required this.focusNode,
    required this.onLeave,
    super.key,
  });

  /// The session being typed into.
  final Session session;

  /// The frame's keyboard for what is open — **handed to the terminal itself**.
  ///
  /// Every other thing that opens over the frame is read rather than typed into, so the frame
  /// holding the keyboard costs them nothing. A terminal is the opposite: with the frame holding
  /// it, `Escape` closed this pane and never reached the far end, which would have made `vim`
  /// unusable inside a session and was found by asking where the key went rather than by
  /// assuming.
  final FocusNode focusNode;

  /// Ends this way in. The work at the far end carries on.
  ///
  /// **The only way out on this screen**: going to another place in the rail leaves the session
  /// open and out of sight, and coming back finds it.
  final VoidCallback onLeave;

  /// How long the end is shown before going back to the work by itself.
  static const backAfter = Duration(seconds: 2);

  @override
  State<SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends State<SessionView> {
  Timer? _back;

  /// What is selected, so a copy can be made of it as it shows.
  final _selection = TerminalController();

  Session get session => widget.session;

  @override
  void initState() {
    super.initState();
    session.addListener(_changed);
  }

  @override
  void dispose() {
    session.removeListener(_changed);
    _back?.cancel();
    _selection.dispose();
    super.dispose();
  }

  /// A session that ended cleanly goes back to the work by itself, after saying so.
  /// A button to press at a way in that is already gone is one step too many. One that
  /// ended with a problem stays, so the problem can be read.
  void _changed() {
    if (_back == null && session.state == SessionState.over && session.problem == null) {
      _back = Timer(SessionView.backAfter, () {
        if (mounted) widget.onLeave();
      });
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: session,
        builder: (context, _) {
          final over = session.state == SessionState.over;
          final scheme = Theme.of(context).colorScheme;

          return Column(
            children: <Widget>[
              PaneHeader(
                title: '${session.task} · ${session.machine.name}',
                trailing: TextButton.icon(
                  key: const Key('leave-session'),
                  onPressed: widget.onLeave,
                  icon: Icon(over ? Icons.arrow_back : Icons.logout, size: Sizes.rowIcon),
                  label: Text(over ? 'Back to the work' : 'Leave'),
                ),
              ),
              if (session.problem != null)
                Container(
                  width: double.infinity,
                  color: scheme.errorContainer,
                  padding: const EdgeInsets.all(Space.normal),
                  child: Text(session.problem!, key: const Key('session-problem')),
                )
              else if (session.state == SessionState.over)
                Container(
                  width: double.infinity,
                  color: scheme.surfaceContainerHighest,
                  padding: const EdgeInsets.all(Space.normal),
                  child: const Text(
                    'The session has ended. The work is where you left it; going back to it…',
                    key: Key('session-over'),
                  ),
                ),
              Expanded(
                child: ColoredBox(
                  color: scheme.surfaceContainerLowest,
                  // On Windows the wheel is reported to tmux by the session itself; see
                  // [Session.wheel]. Elsewhere the terminal answers it, as tmux asked it to.
                  child: Listener(
                    onPointerSignal: desk.isWindows
                        ? (event) {
                            if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
                              session.wheel(up: event.scrollDelta.dy < 0);
                            }
                          }
                        : null,
                    child: WalkSecret(child: CopiesAsShown(
                    terminal: session.terminal,
                    controller: _selection,
                    child: TerminalView(
                    session.terminal,
                    key: const Key('terminal'),
                    theme: TerminalLook.theme,
                    controller: _selection,
                    shortcuts: copyAsShownShortcuts,
                    focusNode: widget.focusNode,
                    autofocus: true,
                    padding: const EdgeInsets.all(Space.small),
                    // Read-only once it is over, so keys typed at a dead session do not look
                    // like they went somewhere.
                    readOnly: !session.live,
                    // On Windows every key, letters included, is read from the keyboard's own
                    // events: there the text-input path this widget uses elsewhere delivered
                    // Enter, Backspace and the page keys and no letter at all.
                    hardwareKeyboardOnly: desk.isWindows,
                    textStyle: const TerminalStyle(fontSize: 13),
                  )))),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.normal),
                child: TerminalLinks(session: session),
              ),
              // Said under the terminal rather than in a tooltip, because it is the one fact
              // that decides whether somebody dares to close the window at all. Only while it runs:
              // under a session that has ended it would say the opposite of the banner.
              if (!over)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: Space.normal, vertical: Space.tight),
                child: Text(
                  // Two facts, and the second is the one asked for by name: coming back has to
                  // say what it can show. A figure is the honest form of that — a screen saying
                  // *as much as we have* leaves somebody to guess whether the quiet hour is
                  // missing or simply was quiet.
                  'Closing this window leaves the session running; it ends when the work does. '
                  'Coming back shows the last ${Session.scrollback} lines and no more.',
                  key: const Key('leaving-is-safe'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      );
}

/// Which sessions are open, and which one this is.
