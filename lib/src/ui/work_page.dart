import 'dart:async';

import 'package:flutter/material.dart';

import 'package:porelo_frontend/client.dart';

import '../app/attention.dart';
import '../app/fleet_model.dart';
import '../app/machines.dart';
import 'attention_view.dart';
import 'tokens.dart';

/// How the work page was left: its filters, its folded groups and its opened tiles. Kept by the
/// window rather than the page, so they stay when something takes the page's place for a while - a
/// refusal, a detail - and the page comes back (walk 9).
class WorkView {
  /// The machine the work is narrowed to, or null for every machine.
  String? machine;

  /// The project the work is narrowed to, empty for work in none, or null for every project.
  String? project;

  /// The tiles folded open, by machine and work.
  Set<String> open = <String>{};

  /// The groups folded shut, by name: stopped work at first, rarely what a person looks for.
  final Set<String> shut = <String>{'stopped'};

  /// Whether the person chose to work without a project on their first start.
  bool withoutAProject = false;
}

/// Every piece of work on every machine, the daily view: what waits
/// for a person first, then what runs, then what stopped. Where it runs and in which project are
/// marks on each tile and filters above, never a place to go to first.
class WorkPage extends StatefulWidget {
  /// Constructor taking the machines, the tiles and how one is drawn.
  const WorkPage({
    required this.machines,
    required this.attention,
    required this.tile,
    required this.onNewWork,
    required this.view,
    this.reveal,
    this.onAddAMachine,
    this.onSetUpAProject,
    super.key,
  });

  /// How the page was left, kept by the window.
  final WorkView view;

  /// The tile to show open, by machine and work, where the finder went to one of its commands: its
  /// group is opened and the tile unfolded, so what is marked can be seen.
  final String? reveal;

  /// Adds a machine: this computer, or one reached over ssh.
  final VoidCallback? onAddAMachine;

  /// Sets up a project from a repository the person has; null where no machine answers.
  final VoidCallback? onSetUpAProject;

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

/// A tile's place in the list, by what it asks of a person.
enum _Group {
  waiting('Waits for you'),
  running('Running'),
  stopped('Stopped');

  const _Group(this.label);

  final String label;
}

/// The project filter's value for work in no project of its own.
const String _noProject = '';

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
  String? get _machine => _view.machine;
  set _machine(String? value) => _view.machine = value;
  String? get _project => _view.project;
  set _project(String? value) => _view.project = value;
  Set<String> get _open => _view.open;
  set _open(Set<String> value) => _view.open = value;
  bool get _withoutAProject => _view.withoutAProject;
  set _withoutAProject(bool value) => _view.withoutAProject = value;
  bool _isShut(_Group group) => _view.shut.contains(group.name);

  /// Newest first: when a task's state began - its start, or its end - is its last activity here.
  static int _newestFirst(Tile a, Tile b) {
    final at = a.task?.startedAt;
    final bt = b.task?.startedAt;
    if (at == null || bt == null) return at == null ? (bt == null ? 0 : 1) : -1;
    return bt.compareTo(at);
  }

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
          'A project, or none',
          'How work runs: its repositories, who reviews what it pushes. Work can also run without one.',
          projectReady,
          machineReady,
          <Widget>[
            FilledButton(
              key: const Key('first-set-up-project'),
              onPressed: widget.onSetUpAProject,
              child: const Text('From a repository you have'),
            ),
            OutlinedButton(
              key: const Key('first-no-project'),
              onPressed: () => setState(() => _withoutAProject = true),
              child: const Text('Skip: work without a project'),
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

  static _Group _groupOf(Tile tile) => switch (tile.demand) {
    Demand.question || Demand.ended || Demand.gate => _Group.waiting,
    Demand.stopped => _Group.stopped,
    _ => _Group.running,
  };

  /// The project a tile's work is in, `default` (work in none) said as none.
  static String _projectOf(Tile tile) {
    final project = tile.task?.project ?? '';
    return project == 'default' ? _noProject : project;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge(<Listenable>[
      widget.attention,
      for (final machine in widget.machines.all) widget.machines.of(machine),
    ]),
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tiles = <Tile>[for (final machine in widget.machines.all) ...widget.attention.tilesOn(machine)];
    final projects = <String>{for (final tile in tiles) _projectOf(tile)}.toList()
      ..sort((a, b) => a == _noProject ? 1 : (b == _noProject ? -1 : a.compareTo(b)));
    final shown = tiles
        .where(
          (tile) =>
              (_machine == null || tile.machine.name == _machine) && (_project == null || _projectOf(tile) == _project),
        )
        .toList();
    final reveal = widget.reveal;
    if (reveal != null) {
      final revealed = tiles.where((tile) => '${tile.machine.name}/${tile.task?.name ?? ''}' == reveal).firstOrNull;
      if (revealed != null) {
        _view.shut.remove(_groupOf(revealed).name);
        _view.open = <String>{..._view.open, reveal};
        // Brought into view once, so what the finder marked on it is on screen.
        if (_scrolledTo != reveal) {
          _scrolledTo = reveal;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final there = _where[reveal]?.currentContext;
            // Moved only where it is out of view: a tile on screen stays where it is.
            if (there != null && there.mounted) {
              unawaited(
                Scrollable.ensureVisible(there, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd),
              );
            }
          });
        }
      }
    } else {
      _scrolledTo = null;
    }
    final groups = <_Group, List<Tile>>{
      for (final group in _Group.values)
        group: shown.where((tile) => _groupOf(tile) == group).toList()..sort(_newestFirst),
    };
    Widget chip(String key, String label, bool selected, VoidCallback onSelected) => ChoiceChip(
      key: ValueKey<String>(key),
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(onSelected),
    );
    return ListView(
      key: const Key('work-page'),
      padding: const EdgeInsets.all(Space.normal),
      children: <Widget>[
        Wrap(
          spacing: Space.normal,
          runSpacing: Space.small,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text('Work', style: text.headlineSmall),
            FilledButton.icon(
              key: const Key('new-work'),
              onPressed: widget.onNewWork,
              icon: const Icon(Icons.add, size: Sizes.rowIcon),
              label: const Text('New work'),
            ),
          ],
        ),
        const SizedBox(height: Space.normal),
        if (widget.machines.all.length > 1)
          Wrap(
            spacing: Space.small,
            runSpacing: Space.tight,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text('Machine', style: text.labelMedium),
              chip('work-machine-all', 'All', _machine == null, () => _machine = null),
              for (final machine in widget.machines.all)
                chip(
                  'work-machine ${machine.name}',
                  machine.name,
                  _machine == machine.name,
                  () => _machine = machine.name,
                ),
            ],
          ),
        // Shown while a project is chosen too, even when only one is left: a filter nobody can see made
        // "No work matches" a riddle (walk 10).
        if (projects.length > 1 || (_project != null && !projects.contains(_project))) ...<Widget>[
          const SizedBox(height: Space.tight),
          Wrap(
            spacing: Space.small,
            runSpacing: Space.tight,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text('Project', style: text.labelMedium),
              chip('work-project-all', 'All', _project == null, () => _project = null),
              for (final project in <String>[
                ...projects,
                if (_project != null && !projects.contains(_project)) _project!,
              ])
                chip(
                  'work-project $project',
                  project == _noProject ? 'Default' : project,
                  _project == project,
                  () => _project = project,
                ),
            ],
          ),
        ],
        const SizedBox(height: Space.normal),
        if (tiles.isEmpty)
          _firstSteps(context)
        else if (shown.isEmpty)
          Row(
            children: <Widget>[
              const Text('No work matches.', key: Key('work-none-matches')),
              TextButton(
                key: const Key('work-filters-clear'),
                onPressed: () => setState(() => _machine = _project = null),
                child: const Text('Show all'),
              ),
            ],
          ),
        for (final group in _Group.values)
          if (groups[group]!.isNotEmpty) ...<Widget>[
            InkWell(
              key: ValueKey<String>('work-group-fold ${group.name}'),
              onTap: () => setState(() => _isShut(group) ? _view.shut.remove(group.name) : _view.shut.add(group.name)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.small),
                child: Row(
                  children: <Widget>[
                    Icon(_isShut(group) ? Icons.chevron_right : Icons.expand_more, size: Sizes.rowIcon),
                    const SizedBox(width: Space.tight),
                    Text(
                      '${group.label} (${groups[group]!.length})',
                      key: ValueKey<String>('work-group ${group.name}'),
                      style: text.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
            if (!_isShut(group))
              TileFolding(
                open: _open,
                toggle: (tile) => setState(() {
                  _open = <String>{..._open};
                  if (!_open.remove(tile)) _open.add(tile);
                }),
                child: Wrap(
                  spacing: Space.normal,
                  runSpacing: Space.normal,
                  children: <Widget>[
                    for (final tile in groups[group]!)
                      KeyedSubtree(key: _where.putIfAbsent(_placeOf(tile), GlobalKey.new), child: widget.tile(tile)),
                  ],
                ),
              ),
            const SizedBox(height: Space.normal),
          ],
      ],
    );
  }
}
