import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:porelo_frontend/client.dart';

import '../app/attention.dart';
import '../app/fleet_model.dart';
import '../app/logs.dart';
import '../app/machines.dart';
import '../app/session.dart';
import 'attention_view.dart';
import 'how_long.dart';
import 'log_view.dart';
import 'small_switch.dart';
import 'session_view.dart';
import 'terminal_look.dart';
import 'tokens.dart';
import 'window_size.dart';
import 'work_page.dart';

/// *Running*: one tab per running agent, and the console of the one chosen.
///
/// **The one place terminals are.** Choosing a tab opens its session and leaves the last: one is open
/// at a time, the agents run on, and coming back shows the same tab. The window's session follows
/// the tab here; that leaving the page leaves it is the window's to see, since this view is gone by then.
class RunningView extends StatefulWidget {
  /// Constructor taking what it reads and where it leads.
  const RunningView({
    required this.machines,
    required this.attention,
    required this.view,
    required this.sessions,
    required this.logs,
    required this.focusNode,
    required this.onAnswer,
    required this.onReadLog,
    this.onImageSettings,
    this.onlyMachine,
    super.key,
  });

  /// Every machine watched.
  final Machines machines;

  /// The machine of a Tasks leaf; absent on the global Running page.
  final Machine? onlyMachine;

  /// Where the work comes from.
  final Attention attention;

  /// Which tab is chosen, kept by the window.
  final WorkView view;

  /// The one session that is open.
  final Sessions sessions;

  /// The logs being read.
  final Logs logs;

  /// The frame's keyboard for what is open, handed to the terminal.
  final FocusNode focusNode;

  /// Goes to where a person answers.
  final VoidCallback onAnswer;

  /// Opens a log of work that has no terminal to open.
  final void Function(Tile tile) onReadLog;

  /// Shows what a task's image was built with.
  final void Function(Tile tile)? onImageSettings;

  @override
  State<RunningView> createState() => _RunningViewState();
}

class _RunningViewState extends State<RunningView> {
  final Map<String, GlobalKey> _tabKeys = <String, GlobalKey>{};
  final ScrollController _tabsScroll = ScrollController();
  Session? _watched;
  String? _shownTab;
  Timer? _questionTicker;

  /// The tab on screen: the one chosen, or the first where none is, or the chosen one has gone.
  String? _chosen;

  WorkView get _view => widget.view;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_key);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_key);
    _watched?.removeListener(_sessionChanged);
    _questionTicker?.cancel();
    _tabsScroll.dispose();
    super.dispose();
  }

  void _keepQuestionTime(Tile? tile) {
    final ends = tile?.questions.firstOrNull?.expiresAt;
    final counting = tile?.demand == Demand.question && ends != null && ends.isAfter(widget.attention.now);
    if (counting && _questionTicker == null) {
      // A quiet daemon must not leave the note overstating the time available to answer.
      _questionTicker = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted) setState(() {});
      });
    } else if (!counting) {
      _questionTicker?.cancel();
      _questionTicker = null;
    }
  }

  /// Every running agent, in an order that does not move while somebody works: a tab that jumps
  /// when its agent changes state is a tab pressed by mistake.
  List<Tile> _tabs() =>
      <Tile>[
        for (final machine in widget.attention.machinesOnce)
          if (widget.onlyMachine == null || machine == widget.onlyMachine)
            ...widget.attention.tilesOn(machine).where((tile) => tile.task?.running ?? false),
      ]..sort((a, b) {
        final byMachine = a.machine.name.compareTo(b.machine.name);
        return byMachine != 0 ? byMachine : a.task!.name.compareTo(b.task!.name);
      });

  static String _idOf(Tile tile) => WorkView.placeOf(tile.machine.name, tile.task!.name);

  /// A key anywhere but in a terminal, which sees its keys first and hands these to [_nextAgent] itself.
  bool _key(KeyEvent event) => !widget.focusNode.hasFocus && _nextAgent(event);

  /// Ctrl+PgUp and Ctrl+PgDn go to the next agent, before a terminal can take them.
  bool _nextAgent(KeyEvent event) {
    final keys = HardwareKeyboard.instance;
    if (event is KeyUpEvent || !keys.isControlPressed) return false;
    // Ctrl alone: with another modifier it is a key of the far end's.
    if (keys.isShiftPressed || keys.isAltPressed || keys.isMetaPressed) return false;
    final step = switch (event.logicalKey) {
      LogicalKeyboardKey.pageUp => -1,
      LogicalKeyboardKey.pageDown => 1,
      _ => 0,
    };
    if (step == 0 || !mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final tabs = _tabs();
    if (tabs.isEmpty) return false;
    final at = tabs.indexWhere((tile) => _idOf(tile) == _chosen);
    _view.moveToTab(_idOf(tabs[((at < 0 ? 0 : at) + step) % tabs.length]));
    return true;
  }

  bool _inATerminal(Tile tile) => tile.task!.mode != Mode.unattended || _view.isByHand(_idOf(tile));

  bool _isSessionOf(Session? session, Tile tile) =>
      session != null &&
      session.task == tile.task!.name &&
      session.machine == tile.machine &&
      session.startedAt == tile.task!.startedAt;

  /// Brings the session in line with the tab chosen, after the frame, since opening one tells everybody.
  void _settle(Tile? tile) {
    if (tile == null || !_inATerminal(tile)) {
      if (widget.sessions.any) unawaited(widget.sessions.leave());
      return;
    }
    final task = tile.task!;
    // A session open and answering is the machine's own word that it has one, whatever a look just before it said.
    if (_isSessionOf(widget.sessions.current, tile) && widget.sessions.current!.state != SessionState.over) {
      _view.terminalSaid(tile.machine.name, task, live: true);
      return;
    }
    if (_keepsWhatWasSaid(tile)) return;
    if (_view.terminalEnded(tile.machine.name, task) ||
        Sessions.whyNot(task, tile.machine) != null ||
        tile.fleet.reachability != Reachability.connected) {
      if (widget.sessions.any) unawaited(widget.sessions.leave());
      return;
    }
    if (_isSessionOf(widget.sessions.current, tile)) return;
    unawaited(_open(tile));
  }

  /// Whether [tile]'s session ended with a problem: what the machine said is on its terminal, and a
  /// later look at the machine says nothing of why, so that look neither closes nor covers it.
  bool _keepsWhatWasSaid(Tile tile) {
    final session = widget.sessions.current;
    return _isSessionOf(session, tile) && session!.state == SessionState.over && session.problem != null;
  }

  /// The tab being looked at before opening its session; moving on leaves that look to nobody.
  String? _opening;

  /// The latest look: a tab chosen again looks again.
  Object? _look;

  /// Opens its session, once the machine has said there is one to come back to: attaching to a session
  /// that ended would start a new one without anybody having asked for it.
  Future<void> _open(Tile tile) async {
    final id = _idOf(tile);
    if (_opening == id && !_view.asksNewTerminal(id)) return;
    final look = Object();
    _look = look;
    _opening = id;
    final task = tile.task!;
    try {
      // A person who asked for a new one has it, whatever the machine says of the last; so has one
      // working by hand, in an agent that need not have a terminal yet.
      if (!_view.takeNewTerminal(id) && !_view.isByHand(id)) {
        try {
          final screen = await tile.fleet.backend.screen(task.name, last: 1);
          if (!identical(_look, look)) return;
          if (!screen.live) {
            _view.terminalSaid(tile.machine.name, task, live: false);
            return;
          }
        } on Object {
          // An older machine, or one that does not answer now: the way in says what it finds.
        }
      }
      if (mounted && _chosen == id && identical(_look, look)) _start(tile);
    } finally {
      if (identical(_look, look)) _opening = null;
    }
  }

  void _start(Tile tile) {
    final task = tile.task!;
    final before = widget.sessions.current;
    widget.sessions.openOn(task.name, tile.machine, startedAt: task.running ? task.startedAt : null);
    if (before != null && before != widget.sessions.current) {
      tile.fleet.say('Left the session in ${before.task}; the work there carries on.');
    }
  }

  /// A person's ask, and so opened without looking first.
  Future<void> _openNew(Tile tile) async {
    await widget.sessions.leave();
    _view.showNewTerminal(tile.machine.name, tile.task!);
  }

  void _watch(Session? session) {
    if (identical(_watched, session)) return;
    _watched?.removeListener(_sessionChanged);
    _watched = session;
    session?.addListener(_sessionChanged);
    _sessionChanged();
  }

  /// A session that ended by itself becomes the sentence and its next step. One that ended with a
  /// problem stays, so the problem can be read.
  void _sessionChanged() {
    final session = _watched;
    if (session == null || !mounted || session.state != SessionState.over || session.problem != null) return;
    final tile = _tabs().where((each) => _isSessionOf(session, each)).firstOrNull;
    scheduleMicrotask(() {
      if (!mounted || !identical(widget.sessions.current, session)) return;
      if (tile != null) _view.terminalSaid(tile.machine.name, tile.task!, live: false);
      // Work by hand in unattended work is over: its tab is its log again.
      if (tile != null && _view.isByHand(_idOf(tile))) _view.showTab(_idOf(tile));
      unawaited(widget.sessions.leave());
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge(<Listenable>[
      widget.attention,
      _view,
      widget.sessions,
      for (final machine in widget.machines.all) widget.machines.of(machine),
    ]),
    builder: (context, _) {
      final tabs = _tabs();
      final tile = tabs.where((each) => _idOf(each) == _view.tab).firstOrNull ?? tabs.firstOrNull;
      _chosen = tile == null ? null : _idOf(tile);
      _keepQuestionTime(tile);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Which tab this is, also where nobody chose: coming back shows the same one.
        if (tile != null) _view.keepTab(_idOf(tile));
        _watch(widget.sessions.current);
        _settle(tile);
        _revealTab(tile);
      });
      if (tile == null) {
        return Center(
          child: Text(
            'Nothing is running. Work that runs has a tab here.',
            key: const Key('running-none'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _tabStrip(context, tabs, tile),
          _bar(context, tile),
          ?_note(context, tile),
          Expanded(child: _console(context, tile)),
        ],
      );
    },
  );

  void _revealTab(Tile? tile) {
    if (tile == null || _shownTab == _idOf(tile)) return;
    _shownTab = _idOf(tile);
    final there = _tabKeys[_shownTab]?.currentContext;
    if (there != null) unawaited(Scrollable.ensureVisible(there, alignment: 0.5));
  }

  Widget _tabStrip(BuildContext context, List<Tile> tabs, Tile chosen) {
    // Two tabs of one short name say what tells them apart: the project, else the machine.
    final byName = <String, List<Tile>>{};
    for (final tile in tabs) {
      (byName[_Tab.shortName(tile.task!)] ??= <Tile>[]).add(tile);
    }
    String? apart(Tile tile) {
      final alike = byName[_Tab.shortName(tile.task!)]!;
      if (alike.length < 2) return null;
      final projects = alike.map((each) => WorkRow.projectOf(each.task!)).toSet();
      return projects.length > 1 ? WorkRow.projectOf(tile.task!) : 'on ${tile.machine.name}';
    }

    final colors = Theme.of(context).colorScheme;
    final console = TerminalLook.consoleOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant, width: Sizes.divider),
        ),
      ),
      child: Scrollbar(
        controller: _tabsScroll,
        child: SingleChildScrollView(
          key: const Key('running-tabs'),
          controller: _tabsScroll,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final tile in tabs)
                _Tab(
                  key: _tabKeys.putIfAbsent(_idOf(tile), GlobalKey.new),
                  id: _idOf(tile),
                  tile: tile,
                  apart: apart(tile),
                  chosen: identical(tile, chosen) || _idOf(tile) == _idOf(chosen),
                  background: console.background,
                  chosenText: console.strong,
                  onTap: () => _view.moveToTab(_idOf(tile)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, Tile tile) {
    final console = TerminalLook.consoleOf(context);
    final task = tile.task!;
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: console.muted);
    final name = task.shown;
    final terminal = _inATerminal(tile);
    return ColoredBox(
      color: console.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.small),
        child: _barLayout(
          context,
          <Widget>[
            Text(
              name,
              key: const Key('running-name'),
              style: small?.copyWith(color: console.strong, fontWeight: FontWeight.w600),
            ),
            Text(
              '${WorkRow.projectOf(task)} · ${WorkRow.agentOf(task)} · on ${tile.machine.name}',
              key: const Key('running-where'),
              style: small,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: console.edge, width: Sizes.divider),
                borderRadius: BorderRadius.circular(Radii.small),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.small),
                child: Text(WorkRow.wayOf(task), key: const Key('running-way'), style: small),
              ),
            ),
            if (widget.onImageSettings case final show?)
              TextButton(
                key: const Key('running-image-settings'),
                onPressed: () => show(tile),
                child: const Text('Image settings'),
              ),
          ],
          <Widget>[
            if (terminal) Text('Ctrl+PgUp / PgDn: next agent', style: small),
            if (terminal && task.mode == Mode.unattended)
              TextButton(
                key: const Key('running-follow-log'),
                onPressed: () => _view.showTab(_idOf(tile)),
                child: const Text('Follow its log'),
              ),
            if (!terminal) _followSwitch(context, tile, small),
          ],
        ),
      ),
    );
  }

  /// What the bar names, and at its far end what can be done here; one after the other on a narrow window.
  Widget _barLayout(BuildContext context, List<Widget> names, List<Widget> doing) {
    Widget wrap(List<Widget> children) => Wrap(
      spacing: Space.normal,
      runSpacing: Space.tight,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
    // The tree stays beside a tablet's page, so the bar needs its wrapping layout there too.
    if (!WindowSize.fromContext(context).showsTwoPanes) {
      return KeyedSubtree(key: const Key('running-bar'), child: wrap(<Widget>[...names, ...doing]));
    }
    return Row(
      key: const Key('running-bar'),
      children: <Widget>[
        Expanded(child: wrap(names)),
        const SizedBox(width: Space.normal),
        wrap(doing),
      ],
    );
  }

  Widget _followSwitch(BuildContext context, Tile tile, TextStyle? style) => ListenableBuilder(
    listenable: widget.logs,
    builder: (context, _) {
      final tail = widget.logs.find(tile.task!.name, taskLog, formatted: true);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('Follow', style: style),
          const SizedBox(width: Space.small),
          // Following is a switch and not a scroll position, so reading back cannot turn it off by accident.
          SmallSwitch(
            key: const Key('follow'),
            label: 'Follow',
            value: tail?.following ?? true,
            onChanged: tail == null ? null : (following) => widget.logs.follow(tail, following: following),
          ),
        ],
      );
    },
  );

  /// Work that waits on a person says so, and where: the answer is given there.
  Widget? _note(BuildContext context, Tile tile) {
    final words = switch (tile.demand) {
      Demand.question when tile.questions.isNotEmpty =>
        'Waits on you: asks to reach ${tile.questions.first.shown} · ${_timeLeft(tile.questions.first)}.',
      Demand.question => 'Waits on you: it asks for an answer.',
      Demand.gate when (tile.task?.waiting ?? 0) > 0 =>
        'Waits on you: ${tile.task!.waiting == 1 ? 'its commit waits' : 'its ${tile.task!.waiting} commits wait'} at the gate.',
      Demand.gate => 'Waits on you: its work waits at the gate.',
      Demand.ended => 'Waits on you: how it ended has not been seen.',
      _ => null,
    };
    if (words == null) return null;
    final console = TerminalLook.consoleOf(context);
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: console.noteText);
    return ColoredBox(
      key: const Key('running-note'),
      color: console.noteBackground,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.normal),
        child: Wrap(
          spacing: Space.normal,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(words, style: style),
            TextButton(
              key: const Key('running-answer'),
              onPressed: widget.onAnswer,
              child: Text('Answer in Needs you', style: style?.copyWith(decoration: TextDecoration.underline)),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLeft(Prompt question) {
    if (question.neverRunsOut) return 'this one does not run out';
    final ends = question.expiresAt;
    if (ends == null) return 'the machine does not say when it runs out';
    final now = widget.attention.now;
    final left = ends.isAfter(now) ? howLongUntil(ends, now: now) : null;
    return left == null ? 'out of time' : '$left left';
  }

  Widget _console(BuildContext context, Tile tile) {
    final task = tile.task!;
    if (!_inATerminal(tile)) {
      return _LogTab(key: ValueKey<String>('running-log ${_idOf(tile)}'), tile: tile, logs: widget.logs);
    }
    final whyNot = Sessions.whyNot(task, tile.machine);
    // A machine tells a terminal that ended from one never opened by neither: not live is all it says.
    if (_view.terminalEnded(tile.machine.name, task) && !_keepsWhatWasSaid(tile)) {
      return _Ended(
        saying: 'No terminal is open in it',
        step: whyNot == null
            ? OutlinedButton(
                key: const Key('running-new-terminal'),
                onPressed: () => unawaited(_openNew(tile)),
                child: const Text('Open a new terminal'),
              )
            : _readLog(tile),
      );
    }
    if (whyNot != null) return _Ended(saying: whyNot.words, step: _readLog(tile));
    final session = widget.sessions.current;
    if (!_isSessionOf(session, tile)) {
      return tile.fleet.reachability == Reachability.connected
          ? const SizedBox.shrink()
          : const _Ended(saying: 'Its machine is not answering', step: SizedBox.shrink());
    }
    return SessionView(
      session: session!,
      focusNode: widget.focusNode,
      onKey: (_, event) => _nextAgent(event) ? KeyEventResult.handled : KeyEventResult.ignored,
      nextStep: OutlinedButton(
        key: const Key('running-new-terminal'),
        onPressed: () => unawaited(_openNew(tile)),
        child: const Text('Open a new terminal'),
      ),
    );
  }

  Widget _readLog(Tile tile) => OutlinedButton(
    key: const Key('running-read-log'),
    onPressed: () => widget.onReadLog(tile),
    child: const Text('Read its log'),
  );
}

/// One tab: its state's dot and a short name, in the window's light or dark.
class _Tab extends StatelessWidget {
  const _Tab({
    required this.id,
    required this.tile,
    required this.chosen,
    required this.background,
    this.apart,
    required this.chosenText,
    required this.onTap,
    super.key,
  });

  final String id;
  final Tile tile;
  final bool chosen;
  final Color background;

  /// What tells it from another tab of the same short name, or null where none has it.
  final String? apart;
  final Color chosenText;
  final VoidCallback onTap;

  /// What a person calls it, short: its caption, else its short name, else, from a machine that does not say one,
  /// the container's name without what every piece of work's name starts with.
  static String shortName(Task task) => task.label.isNotEmpty || (task.short?.isNotEmpty ?? false)
      ? task.shown
      : (task.name.startsWith('porelo-') ? task.name.substring('porelo-'.length) : task.name);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final states = StateColours.of(colors);
    final (dot, filled) = switch (tile.demand) {
      Demand.question || Demand.ended || Demand.gate => (colors.error, true),
      Demand.working => (states.working, true),
      Demand.unseen => (states.working, false),
      Demand.quiet => (states.waiting, false),
      Demand.stopped => (states.stopped, false),
    };
    return Semantics(
      selected: chosen,
      button: true,
      child: Material(
        color: chosen ? background : Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('running-tab $id'),
          onTap: onTap,
          child: Container(
            height: Sizes.runningTab,
            padding: const EdgeInsets.symmetric(horizontal: Space.normal),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: chosen ? colors.primary : Colors.transparent, width: Sizes.selectedBorder),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  key: ValueKey<String>('running-dot ${tile.demand.name}'),
                  width: Sizes.runningDot,
                  height: Sizes.runningDot,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? dot : null,
                    border: filled ? null : Border.all(color: dot, width: Sizes.selectedBorder),
                  ),
                ),
                const SizedBox(width: Space.small),
                Text(
                  apart == null ? shortName(tile.task!) : '${shortName(tile.task!)} · $apart',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: chosen ? chosenText : colors.onSurfaceVariant,
                    fontWeight: chosen ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A sentence and its next step, on the window's own ground: no bar that holds only a sentence.
class _Ended extends StatelessWidget {
  const _Ended({required this.saying, required this.step});

  final String saying;
  final Widget step;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Space.loose),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            saying,
            key: const Key('running-ended'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Space.normal),
          step,
        ],
      ),
    ),
  );
}

/// What an agent without a terminal writes, read while its tab is chosen.
class _LogTab extends StatefulWidget {
  const _LogTab({required this.tile, required this.logs, super.key});

  final Tile tile;
  final Logs logs;

  @override
  State<_LogTab> createState() => _LogTabState();
}

class _LogTabState extends State<_LogTab> {
  LogTail? _tail;

  @override
  void initState() {
    super.initState();
    // After the frame: opening one tells everybody listening, which includes the bar above.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final task = widget.tile.task!.name;
      setState(() => _tail = widget.logs.open(widget.tile.fleet.backend, task, taskLog, formatted: true));
    });
  }

  @override
  void dispose() {
    final logs = widget.logs;
    final tail = _tail;
    // Not read for a tab nobody looks at; coming back reads its end again.
    if (tail != null) WidgetsBinding.instance.addPostFrameCallback((_) => logs.close(tail));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tail = _tail;
    if (tail == null) return ColoredBox(color: TerminalLook.screen.background);
    return ListenableBuilder(
      listenable: widget.logs,
      builder: (context, _) => LogView(tail: tail, logs: widget.logs, onClose: () {}, headed: false),
    );
  }
}
