import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:porelo_frontend/client.dart';

import '../app/fleet_backend.dart';
import '../app/vault_devices.dart' show clockTime;
import 'ansi.dart';
import 'terminal_look.dart';
import 'tokens.dart';

/// The newest lines a task's agent wrote, small, on its tile (walk 9: what an
/// unattended agent does should be seen without opening anything).
///
/// **Cheap on purpose**, since every tile on *Work* has one: it reads only the end of the log, as
/// the agent formats it, keeps [shown] lines, and is redrawn at most every [drawnEvery], however
/// fast lines arrive. It reads nothing while its tile is folded, since it is not built then.
class TileConsole extends StatefulWidget {
  /// Constructor taking whose log, from where, and what enlarging does.
  const TileConsole({
    required this.backend,
    required this.task,
    required this.onEnlarge,
    this.inATerminal = false,
    this.startedAt,
    super.key,
  });

  /// When the task was started, named over its lines, or null when its listing does not say: after
  /// a stop and a start, what the screen still shows from before is not its state now.
  final DateTime? startedAt;

  /// Whether its agent works in a terminal session, by hand, rather than unattended: such work writes
  /// no log of its own, so the tile shows the session's screen, asked of the machine every
  /// [drawnEvery] without attaching, or says where to look where the machine cannot show it.
  final bool inATerminal;

  /// The machine the task runs on.
  final FleetBackend backend;

  /// The task.
  final String task;

  /// Shows the same lines on the whole right side, following.
  final VoidCallback onEnlarge;

  /// How many lines it shows.
  static const int shown = 5;

  /// How many of the log's last lines it asks for: enough that a few hidden by the agent's
  /// formatter still leave [shown].
  static const int asked = 20;

  /// How often it is redrawn at most.
  static const Duration drawnEvery = Duration(seconds: 3);

  /// How much of one line it shows.
  static const int longestShown = 200;

  /// The log it reads.
  static const String log = 'task.log';

  @override
  State<TileConsole> createState() => _TileConsoleState();
}

class _TileConsoleState extends State<TileConsole> {
  final List<String> _lines = <String>[];
  StreamSubscription<List<String>>? _reading;
  Timer? _drawing;
  bool _drawnOnce = false;
  bool _unreadable = false;

  /// For work in a terminal: whether the machine showed its screen, and whether there is a session.
  bool _screenShown = false;
  bool _sessionLive = true;
  Timer? _looking;
  bool _askingForTheScreen = false;

  @override
  void initState() {
    super.initState();
    if (widget.inATerminal) {
      unawaited(_lookAtTheScreen());
      _looking = Timer.periodic(TileConsole.drawnEvery, (_) => unawaited(_lookAtTheScreen()));
      return;
    }
    _reading = widget.backend
        .tailLog(widget.task, TileConsole.log, last: TileConsole.asked, formatted: true)
        .listen(
          _arrived,
          onError: (Object _) {
            // A task without that log, or a machine that cannot tail it: the tile says nothing rather
            // than an error, since the log is a view onto the work and not the work.
            if (mounted) setState(() => _unreadable = true);
          },
          cancelOnError: true,
        );
  }

  void _arrived(List<String> lines) {
    _lines.addAll(lines.where((line) => line.trim().isNotEmpty));
    if (_lines.length > TileConsole.shown) _lines.removeRange(0, _lines.length - TileConsole.shown);
    if (!_drawnOnce) {
      _drawnOnce = true;
      if (mounted) setState(() {});
      return;
    }
    _drawing ??= Timer(TileConsole.drawnEvery, () {
      _drawing = null;
      if (mounted) setState(() {});
    });
  }

  /// Asks the machine what the session shows now: a snapshot, never an attach. **One at a time**: a
  /// machine slower than [TileConsole.drawnEvery] is not asked again until it has answered, since
  /// every look waits on the same connection as the person's own actions.
  Future<void> _lookAtTheScreen() async {
    if (_askingForTheScreen) return;
    _askingForTheScreen = true;
    try {
      final screen = await widget.backend.screen(widget.task, last: TileConsole.shown, escapes: true);
      if (!mounted) return;
      final lines = screen.lines.length > TileConsole.shown
          ? screen.lines.sublist(screen.lines.length - TileConsole.shown)
          : screen.lines;
      // Redrawn only when the screen changed: a redraw every few seconds of the same lines made the
      // whole page flicker (walk 10).
      if (_screenShown && _sessionLive == screen.live && listEquals(lines, _lines)) return;
      setState(() {
        _screenShown = true;
        _sessionLive = screen.live;
        _lines
          ..clear()
          ..addAll(lines);
      });
    } on FeatureNotSupported {
      // A Porelo without Screen: the tile keeps saying where to look. It goes on asking, since an
      // updated Porelo on the same machine has it, and one unanswered call every few seconds is cheap.
    } on Object {
      // Not answering now: what was shown stays, and the next look asks again.
    } finally {
      _askingForTheScreen = false;
    }
  }

  @override
  void dispose() {
    _reading?.cancel();
    _drawing?.cancel();
    _looking?.cancel();
    super.dispose();
  }

  // Its own layer: what it draws, every few seconds, never makes the rest of the window repaint.
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: _headed(context, _drawn(context)));

  Widget _headed(BuildContext context, Widget drawn) {
    final started = widget.startedAt;
    if (started == null || _unreadable) return drawn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: Space.small),
          child: Text(
            'started ${clockTime(started.toIso8601String())}',
            key: ValueKey<String>('tile-console-started ${widget.task}'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        drawn,
      ],
    );
  }

  Widget _drawn(BuildContext context) {
    if (_unreadable) return const SizedBox.shrink();
    if (widget.inATerminal && (!_screenShown || !_sessionLive)) {
      return Container(
        key: ValueKey<String>('tile-console ${widget.task}'),
        width: double.infinity,
        margin: const EdgeInsets.only(top: Space.small),
        padding: const EdgeInsets.all(Space.small),
        decoration: BoxDecoration(color: TerminalLook.background, borderRadius: BorderRadius.circular(Radii.small)),
        child: Text(
          _screenShown ? 'Its terminal session has ended.' : 'Its agent works in its terminal - open it to see.',
          style: TerminalLook.text(size: Sizes.terminalTextSmall),
        ),
      );
    }
    return Container(
      key: ValueKey<String>('tile-console ${widget.task}'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: Space.small),
      padding: const EdgeInsets.fromLTRB(Space.small, Space.tight, Space.tight, Space.tight),
      // A terminal, small: its background, its font and its colours, in any theme.
      decoration: BoxDecoration(color: TerminalLook.background, borderRadius: BorderRadius.circular(Radii.small)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Always as tall as its lines can be, so a screen with fewer lines never moves the page.
          Expanded(
            child: SizedBox(
              height: TileConsole.shown * Sizes.terminalTextSmall * Sizes.terminalLineHeight,
              child: ClipRect(
                child: _lines.isEmpty
                    ? Text('Nothing written yet.', style: TerminalLook.text(size: Sizes.terminalTextSmall))
                    // Lines may be taller than reckoned (box drawing, emoji): they run past the box
                    // and are cut there, the newest kept at the foot, never "overflowed".
                    : OverflowBox(
                        alignment: Alignment.bottomLeft,
                        maxHeight: double.infinity,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            for (final line in _lines)
                              Text.rich(
                                TextSpan(
                                  style: TerminalLook.text(size: Sizes.terminalTextSmall),
                                  children: ansiSpans(
                                    line.length <= TileConsole.longestShown
                                        ? line
                                        : '${line.substring(0, TileConsole.longestShown)} …',
                                    TerminalLook.colours,
                                  ),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          IconButton(
            key: ValueKey<String>('tile-console-enlarge ${widget.task}'),
            icon: const Icon(Icons.open_in_full, size: Sizes.rowIcon, color: TerminalLook.foreground),
            tooltip: 'Show what its agent writes on the whole right side',
            visualDensity: VisualDensity.compact,
            onPressed: widget.onEnlarge,
          ),
        ],
      ),
    );
  }
}
