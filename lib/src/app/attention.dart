import 'homeserver_forwards.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_model.dart';
import 'machines.dart';
import 'operations.dart';
import 'settings.dart';

/// Why a tile sits where it does. Earlier is more urgent.
enum Demand {
  /// A question is open, or the task says it waits on one. It has a deadline.
  question,

  /// Its agent ended before finishing its prompt, or left work that never reached the gate.
  /// Nothing more happens until somebody looks.
  ended,

  /// Its own work waits at the gate. No deadline, and it can sit for days.
  gate,

  /// Producing output.
  working,

  /// Quiet, as far as anything can tell. A guess.
  quiet,

  /// Up, and nothing on this side can see what it is doing.
  unseen,

  /// Not running.
  stopped,
}

/// One tile: a piece of work, or a question the list has not caught up with.
@immutable
class Tile {
  /// Constructor taking what the tile is about.
  const Tile({
    required this.machine,
    required this.fleet,
    required this.demand,
    this.task,
    this.questions = const <Prompt>[],
    this.settled,
  });

  /// Which machine it belongs to. On the tile, never a mode of the window.
  final Machine machine;

  /// That machine's model, which answers for it.
  final FleetModel fleet;

  /// Why it sits where it does.
  final Demand demand;

  /// The work, or null for a question the list has not caught up with.
  final Task? task;

  /// Questions open for this work, oldest first.
  final List<Prompt> questions;

  /// The last question about this work that was answered or ran out, or null.
  final Prompt? settled;

  /// Whether what the tile says is a guess rather than something the machine knows.
  bool get inferred => demand == Demand.quiet;
}

/// The kinds of attention row, including notices that are not work.
enum AttentionKind {
  /// A machine is not answering.
  silent,

  /// A project stopped following its repository.
  following,

  /// A homeserver forward failed.
  forward,

  /// Project messages wait on a dependency.
  waiting,

  /// Held messages could not be listed.
  unlisted,

  /// A message is held for a person.
  message,

  /// A service needs authorization.
  authorization,

  /// A person's operation failed.
  operation,

  /// Work needs a decision or has an outcome to put away.
  tile,

  /// A machine dropped questions unseen.
  missed,
}

/// An immutable row snapshot, retained when the condition it describes is resolved.
class AttentionRow {
  /// Keeps the row's identity, machine and the values it last showed.
  const AttentionRow(this.kind, this.id, this.machine, this.value, {this.read});

  /// Which renderer and actions belong to it.
  final AttentionKind kind;

  /// Identity across refreshes, scoped to the machine.
  final String id;

  /// The machine's display name.
  final String machine;

  /// The last observed facts, independent of later model changes.
  final Object value;

  /// A held message read by a person, available without another daemon call.
  final HeldMessageRead? read;
}

/// A row and the instant it was resolved; these records never reach Settings.
class ResolvedAttention {
  /// Keeps a row until its retention period ends.
  const ResolvedAttention(this.row, this.at);

  /// The row as it was last shown.
  final AttentionRow row;

  /// When its resolution was observed.
  final DateTime at;
}

/// Everything that might need a person, from every machine at once, most urgent first.
///
/// **Read from the models that already exist, never from a stream of its own.** Each machine's
/// `FleetModel` watches its tasks and its `Clearance` watches its questions; a second subscription
/// here would be two answers to one question.
class Attention extends ChangeNotifier {
  /// Constructor taking the machines to read across.
  Attention(this._machines, [this._settings, this._operations, DateTime Function()? clock])
    : _clock = clock ?? DateTime.now {
    _machines.addListener(_follow);
    _settings?.addListener(_changed);
    _operations?.addListener(_changed);
    _follow();
  }

  final Machines _machines;
  final Settings? _settings;
  final Operations? _operations;
  final DateTime Function() _clock;
  List<AttentionRow> _openRows = [];
  final Map<String, AttentionRow> _lastRows = {};
  final Map<String, ResolvedAttention> _resolved = {};
  final Set<String> _readMessages = {};
  Timer? _expiry;

  /// Rows that still need a person, in display order.
  List<AttentionRow> get openRows => List.unmodifiable(_openRows);

  /// Resolved rows, newest first, with expiry measured by the supplied clock.
  List<ResolvedAttention> get recentlyResolved {
    _prune();
    return _resolved.values.toList()..sort((a, b) => b.at.compareTo(a.at));
  }

  /// Remembers a message only after its full text was successfully opened by a person.
  void messageRead(Machine machine, HeldMessage message, HeldMessageRead read) {
    if (!read.found) return;
    final id = _messageId(machine, message);
    final row = _lastRows.remove(id);
    if (row == null) return;
    _readMessages.add(id);
    _resolved[id] = ResolvedAttention(AttentionRow(row.kind, row.id, row.machine, row.value, read: read), _clock());
    _changed();
  }

  static String _messageId(Machine machine, HeldMessage message) =>
      'message ${machine.name}/${message.task}/${message.handle}';

  Iterable<AttentionRow> _rows() sync* {
    for (final machine in missedQuestions) {
      yield AttentionRow(AttentionKind.missed, 'missed ${machine.name}', machine.name, (
        machine: machine,
        count: fleetOf(machine).clearance.missed,
      ));
    }
    for (final machine in silent) {
      final fleet = fleetOf(machine);
      final what = switch (fleet.reachability) {
        Reachability.connecting => 'This machine is still connecting, so nothing is known yet',
        Reachability.incompatible => 'This machine serves nothing this build understands',
        _ => 'This machine cannot be reached',
      };
      yield AttentionRow(AttentionKind.silent, 'silent ${machine.name}', machine.name, (
        machine: machine,
        words: '$what, and anything it is asking waits unseen.  ${fleet.status}',
      ));
    }
    for (final row in notFollowing) {
      yield AttentionRow(
        AttentionKind.following,
        'following ${row.machine.name}/${row.project.name}',
        row.machine.name,
        row,
      );
    }
    for (final row in forwardsRefused) {
      yield AttentionRow(AttentionKind.forward, 'forward ${row.machine}/${row.project}', row.machine, row);
    }
    for (final row in messagesWaiting) {
      yield AttentionRow(
        AttentionKind.waiting,
        'waiting ${row.machine.name}/${row.waitsOn}/${row.waits}',
        row.machine.name,
        row,
      );
    }
    for (final row in unlistedMessages) {
      yield AttentionRow(AttentionKind.unlisted, 'unlisted ${row.machine.name}', row.machine.name, row);
    }
    for (final row in heldMessages) {
      yield AttentionRow(AttentionKind.message, _messageId(row.machine, row.message), row.machine.name, row);
    }
    for (final row in authorizationsNeeded) {
      yield AttentionRow(
        AttentionKind.authorization,
        'authorization ${row.machine.name}/${row.needed.credential}',
        row.machine.name,
        row,
      );
    }
    for (final tile in needing.where((tile) => tile.demand == Demand.question)) {
      yield _tileRow(tile);
    }
    for (final operation in failedUnseen) {
      yield AttentionRow(
        AttentionKind.operation,
        'operation ${operation.id}',
        operation.machine,
        Operation.fromStored(operation.toStored(operation.output.length))!,
      );
    }
    for (final tile in needing.where((tile) => tile.demand != Demand.question)) {
      yield _tileRow(tile);
    }
  }

  AttentionRow _tileRow(Tile tile) => AttentionRow(
    AttentionKind.tile,
    'tile ${tile.machine.name}/${tile.task?.name ?? tile.questions.first.task}',
    tile.machine.name,
    tile,
  );

  void _rememberRows() {
    final rows = _rows().toList();
    final ids = rows.map((row) => row.id).toSet();
    _readMessages.removeWhere((id) => !ids.contains(id));
    _openRows = rows.where((row) => !_readMessages.contains(row.id)).toList();
    final open = {for (final row in _openRows) row.id: row};
    for (final row in _lastRows.values) {
      if (open.containsKey(row.id)) continue;
      final machine = machineNamed(row.machine);
      // Losing contact is not resolution; retain the last facts until this machine answers again.
      final resolved =
          row.kind == AttentionKind.operation ||
          (machine != null &&
              (fleetOf(machine).reachability == Reachability.connected &&
                      (row.kind != AttentionKind.message || fleetOf(machine).mailboxes.problem == null) ||
                  row.kind == AttentionKind.silent && (_settings?.seenSilent.contains(row.machine) ?? false)));
      if (resolved) _resolved[row.id] = ResolvedAttention(row, _clock());
    }
    _lastRows.removeWhere(
      (id, row) =>
          open.containsKey(id) ||
          _resolved.containsKey(id) ||
          row.kind != AttentionKind.operation && machineNamed(row.machine) == null,
    );
    _lastRows.addAll(open);
    for (final id in open.keys) {
      _resolved.remove(id);
    }
    _resolved.removeWhere(
      (_, each) => each.row.kind != AttentionKind.operation && machineNamed(each.row.machine) == null,
    );
    _prune();
    _scheduleExpiry();
  }

  Duration get _retention => Duration(minutes: _settings?.keepResolvedMinutes ?? 60);

  void _prune() {
    final oldest = _clock().subtract(_retention);
    _resolved.removeWhere((_, resolved) => !resolved.at.isAfter(oldest));
  }

  void _scheduleExpiry() {
    _expiry?.cancel();
    _expiry = null;
    if (_resolved.isEmpty) return;
    final first = _resolved.values.map((row) => row.at).reduce((a, b) => a.isBefore(b) ? a : b);
    final delay = first.add(_retention).difference(_clock());
    _expiry = Timer(delay.isNegative ? Duration.zero : delay, () {
      _prune();
      _scheduleExpiry();
      notifyListeners();
    });
  }

  /// Operations a person started that failed and that nobody has opened since, oldest first.
  ///
  /// **Waiting until seen**: a start that failed while its
  /// view was closed was found only by going to that machine, and nobody looked there.
  List<Operation> get failedUnseen => <Operation>[
    for (final operation in _operations?.all ?? const <Operation>[])
      if (operation.failed && !operation.seen) operation,
  ];
  final Set<Listenable> _following = <Listenable>{};

  /// Every machine that is not answering. Said about the machine, above the tiles, never as one:
  /// a machine is not work, and its silence may be hiding a question.
  ///
  /// This computer, where no Porelo is installed, is not one: nothing was ever going to answer there.
  List<Machine> get silent => <Machine>[
    for (final machine in _counted)
      if (_machines.of(machine).reachability != Reachability.connected &&
          !(_settings?.seenSilent.contains(machine.name) ?? false) &&
          !(machine.isThisComputer && !_machines.poreloIsInstalledHere))
        machine,
  ];

  /// Every machine once: one node reached two ways would deliver every question twice.
  List<Machine> get _counted {
    final machines = _machines.all;
    return <Machine>[
      for (var i = 0; i < machines.length; i++)
        if (!_machines.sameNodeAs(machines[i]).any((other) {
          final at = machines.indexOf(other);
          return at >= 0 && at < i;
        }))
          machines[i],
    ];
  }

  /// Every followed project whose repository stopped being taken **and will stay stopped until
  /// somebody acts**, as the daemon says. Said about the project, never as a tile: it is not work,
  /// and a refused signature may be somebody putting a project file past the machine.
  List<({Machine machine, Project project, Followed followed})> get notFollowing =>
      <({Machine machine, Project project, Followed followed})>[
        for (final machine in _counted)
          for (final each in _machines.of(machine).projects)
            if (each.project.following case final followed? when followed.needsAPerson)
              (machine: machine, project: each.project, followed: followed),
      ];

  /// Every machine whose messages wait, with the machine's reason and the projects it holds up: the
  /// vault locked stops every conversation at once, and said nowhere a person looked (walk 10).
  List<({Machine machine, String waits, String waitsOn, List<String> projects})> get messagesWaiting => [
    for (final machine in _counted)
      for (final reason in <(String, String)>{
        for (final each in fleetOf(machine).projects)
          if (each.project.messages case final messages? when messages.waits.isNotEmpty)
            (messages.waits, messages.waitsOn),
      })
        (
          machine: machine,
          waits: reason.$1,
          waitsOn: reason.$2,
          projects: [
            for (final each in fleetOf(machine).projects)
              if (each.project.messages?.waits == reason.$1 && each.project.messages?.waitsOn == reason.$2) each.name,
          ],
        ),
  ];

  /// The homeservers joined from here, whose forwards can fail; set by the window once it holds them.
  HomeserverForwards? get homeservers => _homeservers;
  set homeservers(HomeserverForwards? forwards) {
    _homeservers?.removeListener(_changed);
    _homeservers = forwards;
    forwards?.addListener(_changed);
    _changed();
  }

  HomeserverForwards? _homeservers;

  /// The watched machine called [name], or null.
  Machine? machineNamed(String name) => _machines.all.where((each) => each.name == name).firstOrNull;

  /// Every homeserver a Matrix client here cannot reach, since its forward cannot be raised.
  List<({String machine, String project, String words})> get forwardsRefused =>
      _homeservers?.refused ?? const <({String machine, String project, String words})>[];

  /// Every message waiting for a person to read it and decide, on every machine, oldest first.
  /// Said as messages, never as a tile: a message is not work, and the task that wrote it may be
  /// busy with something else entirely.
  List<({Machine machine, HeldMessage message})> get heldMessages => <({Machine machine, HeldMessage message})>[
    for (final machine in _counted)
      for (final message in _machines.of(machine).mailboxes.waiting) (machine: machine, message: message),
  ];

  /// Every authorization a person has to grant before work can use it, on every machine, oldest first.
  List<({Machine machine, AuthorizationNeeded needed})> get authorizationsNeeded =>
      <({Machine machine, AuthorizationNeeded needed})>[
        for (final machine in _counted)
          for (final needed in _machines.of(machine).authorizations.open) (machine: machine, needed: needed),
      ];

  /// Every machine that cannot say what is held for a person, so its silence is not read as none.
  List<({Machine machine, String problem})> get unlistedMessages => <({Machine machine, String problem})>[
    for (final machine in _counted)
      if (_machines.of(machine).reachability == Reachability.connected &&
          _machines.of(machine).mailboxes.problem != null)
        (machine: machine, problem: _machines.of(machine).mailboxes.problem!),
  ];

  /// Stops saying that [machine] is silent, until it has answered again.
  Future<void> markSeen(Machine machine) async {
    final settings = _settings;
    if (settings == null) return;
    await settings.setSeenSilent(<String>{...settings.seenSilent, machine.name});
  }

  /// A machine that answers again is forgotten as seen, so its next silence is said.
  void _changed() {
    final settings = _settings;
    if (settings != null) {
      final answering = <String>{
        for (final machine in _machines.all)
          if (_machines.of(machine).reachability == Reachability.connected) machine.name,
      };
      final stillSilent = settings.seenSilent.difference(answering);
      if (stillSilent.length != settings.seenSilent.length) {
        // Not now: this runs while the frame is being drawn, and settings changing would redraw it.
        scheduleMicrotask(() => settings.setSeenSilent(stillSilent));
      }
    }
    _rememberRows();
    notifyListeners();
  }

  /// The model of one machine.
  FleetModel fleetOf(Machine machine) => _machines.of(machine);

  /// Every tile, most urgent first.
  List<Tile> get tiles => <Tile>[for (final machine in _counted) ..._tilesOf(machine)]..sort(_byDemand);

  /// The tiles that need a person: an open question, work waiting at the gate, or the outcome of a
  /// question that was answered or ran out and has not been put away.
  ///
  /// **What the window opens on**. A list of every tile is,
  /// at fifty tasks, fifty tiles of which two need anybody — and the reason to open the window is
  /// the two. Everything else — working, quiet, unseen, stopped — is still drawn, in its machine's
  /// area, which is where somebody looking at that machine goes.
  ///
  /// **An outcome stays until it is put away**, decided the same day: a question that ran out while
  /// nobody looked would otherwise leave without a trace, and an answer's confirmation would go with
  /// the click that gave it.
  List<Tile> get needing => <Tile>[
    for (final tile in tiles)
      if (tile.demand == Demand.question ||
          tile.demand == Demand.ended ||
          tile.demand == Demand.gate ||
          tile.settled != null)
        tile,
  ];

  /// One machine's tiles, most urgent first. While it is not answering they are what it last
  /// said: a lost tunnel is a disconnection, never a machine with nothing on it.
  List<Tile> tilesOn(Machine machine) => _tilesOf(machine, evenSilent: true)..sort(_byDemand);

  List<Tile> _tilesOf(Machine machine, {bool evenSilent = false}) {
    final out = <Tile>[];
    final fleet = _machines.of(machine);
    if (evenSilent || fleet.reachability == Reachability.connected) {
      final settled = fleet.clearance.settled;
      final asked = <String, List<Prompt>>{};
      for (final prompt in fleet.clearance.waiting) {
        asked.putIfAbsent(prompt.task, () => <Prompt>[]).add(prompt);
      }
      for (final questions in asked.values) {
        questions.sort(_nearestFirst);
      }
      for (final task in fleet.tasks) {
        final questions = asked.remove(task.name) ?? const <Prompt>[];
        out.add(
          Tile(
            machine: machine,
            fleet: fleet,
            demand: demandOf(task, questions),
            task: task,
            questions: questions,
            settled: settled.where((each) => each.task == task.name).firstOrNull,
          ),
        );
      }
      // A question can arrive before the list names its task. It is shown, not held back.
      for (final questions in asked.values) {
        out.add(Tile(machine: machine, fleet: fleet, demand: Demand.question, questions: questions));
      }
    }
    return out;
  }

  /// Machines that dropped questions about blocked connections unseen: those are not asked again,
  /// so work may be held until its deadline with nobody told (the contracts review).
  List<Machine> get missedQuestions => <Machine>[
    for (final machine in _counted)
      if (_machines.of(machine).clearance.missed > 0) machine,
  ];

  /// How many things need somebody now: an open question, a machine that cannot say, or a failure
  /// nobody has seen; the count *Needs you*'s badge shows.
  int get needingSomebody => _openRows
      .where(
        (row) =>
            row.kind != AttentionKind.tile ||
            (row.value as Tile).demand == Demand.question ||
            (row.value as Tile).demand == Demand.ended,
      )
      .length;

  /// Why one piece of work sits where it does.
  static Demand demandOf(Task task, List<Prompt> questions) {
    if (questions.isNotEmpty || task.activity == Activity.waiting) return Demand.question;
    // Before the gate and before working: an ended agent's container can still look busy.
    if (task.agentEnded?.needsSomebody ?? false) return Demand.ended;
    if (task.hasWorkWaiting) return Demand.gate;
    if (task.activity == Activity.dead || !task.running) return Demand.stopped;
    return switch (task.activity.name) {
      'WORKING' => Demand.working,
      'IDLE' => Demand.quiet,
      _ => Demand.unseen,
    };
  }

  static int _byDemand(Tile a, Tile b) {
    final byDemand = a.demand.index.compareTo(b.demand.index);
    if (byDemand != 0) return byDemand;
    final byDeadline = _endOf(a).compareTo(_endOf(b));
    if (byDeadline != 0) return byDeadline;
    // Then the oldest question: without a deadline, it is the likeliest to be given up on first.
    final byAge = _oldest(a).compareTo(_oldest(b));
    if (byAge != 0) return byAge;
    final byMachine = a.machine.name.compareTo(b.machine.name);
    if (byMachine != 0) return byMachine;
    return (a.task?.name ?? '').compareTo(b.task?.name ?? '');
  }

  static final _never = DateTime.utc(9999);

  static DateTime _endOf(Tile tile) => tile.questions.isEmpty ? _never : tile.questions.first.expiresAt ?? _never;

  static int _nearestFirst(Prompt a, Prompt b) {
    final byEnd = (a.expiresAt ?? _never).compareTo(b.expiresAt ?? _never);
    return byEnd != 0 ? byEnd : a.at.compareTo(b.at);
  }

  static String _oldest(Tile tile) => tile.questions.isNotEmpty
      ? tile.questions.first.at
      : tile.demand == Demand.question
      ? tile.task?.since ?? ''
      : '';

  void _follow() {
    final wanted = <Listenable>{
      for (final machine in _machines.all) ...<Listenable>[
        _machines.of(machine),
        _machines.of(machine).clearance,
        _machines.of(machine).mailboxes,
        _machines.of(machine).authorizations,
      ],
    };
    for (final gone in _following.difference(wanted)) {
      gone.removeListener(_changed);
    }
    for (final added in wanted.difference(_following)) {
      added.addListener(_changed);
    }
    _following
      ..clear()
      ..addAll(wanted);
    _changed();
  }

  @override
  void dispose() {
    _machines.removeListener(_follow);
    _settings?.removeListener(_changed);
    _operations?.removeListener(_changed);
    _homeservers?.removeListener(_changed);
    _expiry?.cancel();
    for (final each in _following) {
      each.removeListener(_changed);
    }
    super.dispose();
  }
}
