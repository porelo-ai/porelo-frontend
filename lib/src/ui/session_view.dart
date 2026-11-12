import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../app/desk.dart';
import '../app/session.dart';
import '../app/vault_devices.dart' show clockTime;

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
///
/// **It has one place**, a tab of *Running*, which says whose it is and how to go elsewhere; going
/// elsewhere is leaving it.
class SessionView extends StatefulWidget {
  /// Constructor taking the session, and what opens another where this way in failed.
  const SessionView({required this.session, required this.focusNode, this.nextStep, this.onKey, super.key});

  /// Sees a key before the far end does; what it handles never gets there.
  final FocusOnKeyEventCallback? onKey;

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

  /// What can be done where this way in failed, said under its problem.
  final Widget? nextStep;

  @override
  State<SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends State<SessionView> {
  /// What is selected, so a copy can be made of it as it shows. A plain drag is the program's whole
  /// where it asked for a drag's motion, so tmux selects past the screen's edge.
  final _selection = TerminalController(pointerInputs: const PointerInputs({PointerInput.tap, PointerInput.drag}));

  /// Where the screen stands in what the session wrote: the wheel goes back into it, and new output leaves the view
  /// where the person reads until they come back to the end.
  final _scroll = ScrollController();

  /// Whether the person has scrolled back from the latest line, and *Jump to latest* shows.
  bool _back = false;

  Session get session => widget.session;

  /// Whether the terminal held the keyboard when last told: a report goes out only on a change.
  late bool _focused;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_moved);
    _focused = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_focusChanged);
  }

  /// The far end hears when the terminal gains and loses the keyboard, where it asked to.
  void _focusChanged() {
    final now = widget.focusNode.hasFocus;
    if (now == _focused) return;
    _focused = now;
    session.focused(gained: now);
  }

  /// Only a move changes it: lines written below move nothing, so they neither pull the view down nor turn it back.
  /// The end is the terminal's own: it follows only exactly there, so anywhere short of it the button shows.
  void _moved() {
    final at = _scroll.position;
    final back = at.pixels < at.maxScrollExtent;
    if (back != _back) setState(() => _back = back);
  }

  /// Goes to the latest line, and gives the keyboard back to the terminal the button took it from.
  void _toTheLatest() {
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    widget.focusNode.requestFocus();
  }

  /// Another session shown in this one's place starts with nothing selected; another focus node is listened to.
  @override
  void didUpdateWidget(SessionView old) {
    super.didUpdateWidget(old);
    if (old.session != widget.session) _selection.clearSelection();
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_focusChanged);
      widget.focusNode.addListener(_focusChanged);
      _focused = widget.focusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_focusChanged);
    _selection.dispose();
    _scroll
      ..removeListener(_moved)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: session,
    builder: (context, _) {
      final over = session.state == SessionState.over;
      final scheme = Theme.of(context).colorScheme;

      return Column(
        children: <Widget>[
          if (session.problem != null)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                border: Border.all(color: scheme.outlineVariant, width: Sizes.divider),
              ),
              padding: const EdgeInsets.all(Space.normal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(session.problem!, key: const Key('session-problem')),
                  ?widget.nextStep,
                ],
              ),
            ),
          // Above the screen, since what tmux draws starts on a screen of its own: after a stop and a
          // start, what the agent redraws from before can otherwise be read as its answer now.
          if (session.startedAt case final started?)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.tight),
              child: Text(
                '${session.task}, started ${clockTime(started.toIso8601String())}: anything its screen shows from before then '
                'is from an earlier start.',
                key: const Key('session-started'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: ColoredBox(
              color: TerminalLook.screen.background,
              // On Windows the wheel is reported to tmux by the session itself; see
              // [Session.wheel]. Elsewhere the terminal answers it, as tmux asked it to.
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Listener(
                      // Shift+drag selects here whatever the program asked for, as in other terminals: the
                      // whole gesture, press and release included, then never reaches the program.
                      onPointerDown: (_) => _selection.setSuspendPointerInput(HardwareKeyboard.instance.isShiftPressed),
                      onPointerSignal: desk.isWindows
                          ? (event) {
                              // Where the program did ask for the mouse, the terminal reports the wheel itself.
                              if (event is PointerScrollEvent &&
                                  event.scrollDelta.dy != 0 &&
                                  !session.terminal.mouseMode.reportScroll) {
                                session.wheel(up: event.scrollDelta.dy < 0);
                              }
                            }
                          : null,
                      child: WalkSecret(
                        child: CopiesAsShown(
                          terminal: session.terminal,
                          controller: _selection,
                          child: TerminalView(
                            session.terminal,
                            key: const Key('terminal'),
                            scrollController: _scroll,
                            theme: TerminalLook.themeOf(context),
                            controller: _selection,
                            shortcuts: terminalShortcuts,
                            focusNode: widget.focusNode,
                            onKeyEvent: widget.onKey,
                            autofocus: true,
                            padding: const EdgeInsets.symmetric(horizontal: Sizes.terminalSide, vertical: Space.normal),
                            // Read-only once it is over, so keys typed at a dead session do not look
                            // like they went somewhere.
                            readOnly: !session.live,
                            // On Windows every key, letters included, is read from the keyboard's own
                            // events: there the text-input path this widget uses elsewhere delivered
                            // Enter, Backspace and the page keys and no letter at all.
                            hardwareKeyboardOnly: desk.isWindows,
                            textStyle: const TerminalStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_back)
                    Positioned(
                      right: Space.wide,
                      bottom: Space.wide,
                      child: FilledButton.tonalIcon(
                        key: const Key('terminal-jump-to-latest'),
                        onPressed: _toTheLatest,
                        icon: const Icon(Icons.arrow_downward),
                        label: const Text('Jump to latest'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const TerminalPasteHint(shiftSelects: true),
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
              padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.tight),
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
