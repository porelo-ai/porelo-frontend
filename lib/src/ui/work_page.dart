import 'dart:async';

import 'package:flutter/material.dart';

import 'package:porelo_frontend/client.dart';

import '../app/attention.dart';
import '../app/fleet_model.dart';
import '../app/machines.dart';
import 'attention_view.dart';
import 'filtered_list_section.dart';
import 'tokens.dart';

/// How the work page was left: its search, its opened rows, which view and which tab. Kept by the
/// window rather than the page, so they stay when something takes the page's place for a while - a
/// refusal, a detail, another page - and the page comes back (walk 9).
class WorkView extends ChangeNotifier {
  /// What the list is searched for: a name, a project or a machine.
  final TextEditingController search = TextEditingController();

  /// Whether *Running* is shown rather than the list.
  bool get running => _running;
  bool _running = false;
  set running(bool value) {
    if (_running == value) return;
    _running = value;
    notifyListeners();
  }

  /// The tab chosen under *Running*, by machine and work.
  String? get tab => _tab;
  String? _tab;

  /// The tab whose unattended agent is being worked with by hand, in a terminal in place of its log.
  String? get byHand => _byHand;
  String? _byHand;

  /// Where a tab is kept, by machine and work.
  static String placeOf(String machine, String task) => '$machine/$task';

  /// Shows *Running* on one tab. With [byHand], an unattended agent's terminal in place of its log.
  void showTab(String tab, {bool byHand = false}) {
    _running = true;
    _tab = tab;
    _byHand = byHand ? tab : null;
    notifyListeners();
  }

  String? _newTerminal;

  /// Shows [task]'s tab with a terminal opened anew: a person asked, so nobody looks first.
  void showNewTerminal(String machine, Task task) {
    _newTerminal = placeOf(machine, task.name);
    _endedTerminals.remove(_terminalOf(machine, task));
    showTab(_newTerminal!);
  }

  /// Whether a new terminal was asked for on [tab], which asks once.
  bool takeNewTerminal(String tab) {
    final asked = _newTerminal == tab;
    if (asked) _newTerminal = null;
    return asked;
  }

  /// Shows the list, with one row unfolded where [unfold] names it, searched for what it holds where
  /// [searchFor] says so.
  void showList({String? unfold, String? searchFor}) {
    _running = false;
    if (unfold != null) open = <String>{...open, unfold};
    if (searchFor != null) search.text = searchFor;
    notifyListeners();
  }

  /// Shows the list with [row] open, while the page is being drawn and so telling nobody.
  void showRevealed(String row) {
    _running = false;
    if (!open.contains(row)) open = <String>{...open, row};
    if (search.text.isNotEmpty) search.value = TextEditingValue.empty;
  }

  /// Selects the work listed by the page and counted in navigation.
  List<Tile> shownTiles(Iterable<Tile> tiles) {
    final query = search.text.trim().toLowerCase();
    return tiles.where((tile) => wordsOf(tile).toLowerCase().contains(query)).toList();
  }

  /// What the search goes through: name, project and machine.
  static String wordsOf(Tile tile) {
    final task = tile.task;
    return <String>[
      task?.name ?? tile.questions.firstOrNull?.task ?? '',
      task?.label ?? '',
      WorkRow.projectOf(task),
      tile.machine.name,
    ].join(' ');
  }

  /// The rows folded open, by machine and work.
  Set<String> open = <String>{};

  /// Whether the person chose to work in the Default project on their first start.
  bool withoutAProject = false;

  /// Whose terminal session the machine last said has ended, by machine, work and start: a start
  /// has a session of its own, so what was said of the last one says nothing about it.
  final Set<String> _endedTerminals = <String>{};

  static String _terminalOf(String machine, Task task) => '$machine/${task.name}/${task.since}';

  /// Whether [task]'s terminal session on [machine] is known to have ended while its work runs on.
  bool terminalEnded(String machine, Task task) =>
      task.running && task.mode != Mode.unattended && _endedTerminals.contains(_terminalOf(machine, task));

  /// Keeps what was learned of [task]'s terminal session.
  void terminalSaid(String machine, Task task, {required bool live}) {
    final key = _terminalOf(machine, task);
    if (live ? _endedTerminals.remove(key) : _endedTerminals.add(key)) notifyListeners();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }
}

/// Every piece of work on every machine, the daily view: one list, sorted by state to begin with, and
/// a tab per running agent. Where it runs and in which project are said on each row and searched for
/// above, never a place to go to first. **Nothing is decided here**: that is what *Needs you* is for.
class WorkPage extends StatefulWidget {
  /// Constructor taking the machines, the tiles and how one is drawn.
  const WorkPage({
    required this.machines,
    required this.attention,
    required this.tile,
    required this.onNewWork,
    required this.view,
    required this.running,
    this.listFocus,
    this.reveal,
    this.onAddAMachine,
    super.key,
  });

  /// How the page was left, kept by the window.
  final WorkView view;

  /// Draws *Running*.
  final WidgetBuilder running;

  /// The frame's keyboard for what is open, around the list alone: under *Running* a terminal holds it.
  final FocusNode? listFocus;

  /// The tile to show open, by machine and work, where the finder went to one of its commands: its
  /// group is opened and the tile unfolded, so what is marked can be seen.
  final String? reveal;

  /// Adds a machine: this computer, or one reached over ssh.
  final VoidCallback? onAddAMachine;

  /// Every machine watched.
  final Machines machines;

  /// Where the tiles come from.
  final Attention attention;

  /// Draws one tile, with everything it can be told to do.
  final Widget Function(Tile tile) tile;

  /// Starts new work, asking where; null where no machine answers.
  final VoidCallback? onNewWork;

  @override
  State<WorkPage> createState() => _WorkPageState();
}

class _WorkPageState extends State<WorkPage> {
  WorkView get _view => widget.view;

  /// Where each tile is drawn, by machine and work, to scroll a revealed one into view. Every tile
  /// keeps its own key, so the tree under a tile never changes when one is revealed or no longer is:
  /// a menu open on it would lose its tile.
  final Map<String, GlobalKey> _where = <String, GlobalKey>{};
  String? _scrolledTo;

  /// Where [tile] is kept among the tiles: by machine and work, and for a question whose work the
  /// machine does not list yet, by the work the question names, so two such tiles never share one.
  static String _placeOf(Tile tile) =>
      '${tile.machine.name}/${tile.task?.name ?? tile.questions.firstOrNull?.task ?? ''}';
  Set<String> get _open => _view.open;
  set _open(Set<String> value) => _view.open = value;
  bool get _withoutAProject => _view.withoutAProject;
  set _withoutAProject(bool value) => _view.withoutAProject = value;

  /// How often the terminal of a row not unfolded is looked at: one call a row, one at a time, on the
  /// connection the person's own actions go through. An unfolded row looks more often by itself.
  static const Duration _terminalsEvery = Duration(seconds: 30);

  Timer? _lookingAtTerminals;
  bool _looking = false;

  @override
  void initState() {
    super.initState();
    unawaited(_lookAtTerminals());
    _lookingAtTerminals = Timer.periodic(_terminalsEvery, (_) => unawaited(_lookAtTerminals()));
  }

  @override
  void dispose() {
    _lookingAtTerminals?.cancel();
    super.dispose();
  }

  /// Asks of every running terminal whether it still has its session, so its row and its tab can say
  /// so folded as well: a session that ended is otherwise found only by opening it.
  Future<void> _lookAtTerminals() async {
    if (_looking) return;
    _looking = true;
    try {
      for (final machine in widget.machines.all) {
        for (final tile in widget.attention.tilesOn(machine)) {
          final task = tile.task;
          if (task == null || !task.running || task.mode == Mode.unattended) continue;
          if (_view.open.contains(_placeOf(tile))) continue;
          if (!mounted) return;
          try {
            final screen = await tile.fleet.backend.screen(task.name, last: 1);
            _view.terminalSaid(machine.name, task, live: screen.live);
          } on Object {
            // A Porelo without Screen, or one not answering now: nothing is known, so nothing is said.
          }
        }
      }
    } finally {
      _looking = false;
    }
  }

  /// The list's first order: what asks most of a person first, the work active last first within that.
  static String _stateKey(Tile tile) {
    final at = tile.task?.startedAt?.millisecondsSinceEpoch ?? 0;
    return '${tile.demand.index}${(_latest - at).toString().padLeft(16, '0')}';
  }

  static const int _latest = 9999999999999;

  /// The first start, while there is no work anywhere: a machine, a
  /// project or none, then the first work. Each step says when it is done, and the window opens
  /// on the work once there is some.
  Widget _firstSteps(BuildContext context) {
    final machineReady = widget.machines.all.any(
      (each) => widget.machines.of(each).reachability == Reachability.connected,
    );
    final projectReady =
        _withoutAProject ||
        widget.machines.all.any(
          (each) => widget.machines.of(each).projects.any((project) => project.name != defaultProject),
        );
    Widget step(int number, String key, String title, String says, bool done, bool open, List<Widget> actions) => Card(
      key: ValueKey<String>('first-step $key'),
      child: ListTile(
        leading: CircleAvatar(child: done ? const Icon(Icons.check) : Text('$number')),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(says),
            if (open && !done) ...<Widget>[
              const SizedBox(height: Space.small),
              Wrap(spacing: Space.small, runSpacing: Space.tight, children: actions),
            ],
          ],
        ),
      ),
    );
    return Column(
      key: const Key('work-none'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'No work yet. Three steps, and the first work runs; machines and projects are '
          'then under Set up, out of the way.',
        ),
        const SizedBox(height: Space.small),
        step(
          1,
          'machine',
          'A machine',
          'Where work runs: this computer, or one you reach over ssh.',
          machineReady,
          true,
          <Widget>[
            FilledButton(
              key: const Key('first-add-machine'),
              onPressed: widget.onAddAMachine,
              child: const Text('Set up a machine'),
            ),
          ],
        ),
        step(
          2,
          'project',
          'A project, or Default',
          'How work runs: its repositories, who reviews what it pushes. A project comes from your organization; '
              'work can also run in Default, the project every machine has.',
          projectReady,
          machineReady,
          <Widget>[
            OutlinedButton(
              key: const Key('first-no-project'),
              onPressed: () => setState(() => _withoutAProject = true),
              child: const Text('Skip: work in the Default project'),
            ),
          ],
        ),
        step(
          3,
          'work',
          'The first work',
          'An agent, in a repository, on the machine.',
          false,
          machineReady && projectReady,
          <Widget>[
            FilledButton(
              key: const Key('first-new-work'),
              onPressed: widget.onNewWork,
              child: const Text('Start the first work'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge(<Listenable>[
      widget.attention,
      _view,
      for (final machine in widget.machines.all) widget.machines.of(machine),
    ]),
    builder: (context, _) => _build(context),
  );

  Widget _head(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Space.normal),
    child: Wrap(
      spacing: Space.normal,
      runSpacing: Space.small,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text('Work', style: Theme.of(context).textTheme.headlineSmall),
        FilledButton.icon(
          key: const Key('new-work'),
          onPressed: widget.onNewWork,
          icon: const Icon(Icons.add, size: Sizes.rowIcon),
          label: const Text('New work'),
        ),
        SegmentedButton<bool>(
          key: const Key('work-view'),
          showSelectedIcon: false,
          segments: const <ButtonSegment<bool>>[
            ButtonSegment<bool>(value: false, label: Text('List', key: Key('work-view-list'))),
            ButtonSegment<bool>(value: true, label: Text('Running', key: Key('work-view-running'))),
          ],
          selected: <bool>{_view.running},
          onSelectionChanged: (chosen) => _view.running = chosen.single,
        ),
      ],
    ),
  );

  Widget _build(BuildContext context) {
    final reveal = widget.reveal;
    final tiles = <Tile>[for (final machine in widget.machines.all) ...widget.attention.tilesOn(machine)];
    if (reveal != null && tiles.any((tile) => _placeOf(tile) == reveal)) {
      // Where the finder went to one of a row's commands: the list, with that row open. Said on the way
      // through this frame, so nobody is told of it twice.
      _view.showRevealed(reveal);
      if (_scrolledTo != reveal) {
        _scrolledTo = reveal;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final there = _where[reveal]?.currentContext;
          // Moved only where it is out of view: a row on screen stays where it is.
          if (there != null && there.mounted) {
            unawaited(Scrollable.ensureVisible(there, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd));
          }
        });
      }
    } else if (reveal == null) {
      _scrolledTo = null;
    }
    final list = ListView(
      key: const Key('work-page'),
      padding: const EdgeInsets.symmetric(horizontal: Space.normal),
      children: <Widget>[
        if (tiles.isEmpty)
          _firstSteps(context)
        else
          TileFolding(
            open: _open,
            toggle: (tile) => setState(() {
              _open = <String>{..._open};
              if (!_open.remove(tile)) _open.add(tile);
            }),
            child: FilteredListSection(
              title: 'All work',
              storageId: 'work-list',
              search: _view.search,
              searchHint: 'Name, project or machine',
              reveal: reveal,
              sorts: <SectionSort>[
                SectionSort('Sorted by state', (row) => _stateKey(tiles[row])),
                SectionSort('Sorted by name', (row) => tiles[row].task?.name ?? ''),
                SectionSort('Sorted by project', (row) => WorkRow.projectOf(tiles[row].task)),
                SectionSort('Sorted by machine', (row) => tiles[row].machine.name),
              ],
              rows: <FilteredRow>[
                for (final tile in tiles)
                  (
                    words: WorkView.wordsOf(tile),
                    child: KeyedSubtree(
                      key: _where.putIfAbsent(_placeOf(tile), GlobalKey.new),
                      child: widget.tile(tile),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
    final focus = widget.listFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _head(context),
        Expanded(
          child: _view.running
              ? widget.running(context)
              : (focus == null ? list : Focus(focusNode: focus, child: list)),
        ),
      ],
    );
  }
}
