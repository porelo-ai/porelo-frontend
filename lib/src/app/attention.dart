import 'homeserver_forwards.dart';
import 'host_runs.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_planning/porelo_planning.dart'
    show PlanningAttention, PlanningBoard, PlanningBoards, PlanningNeedsYou;

import 'clearance.dart';
import 'fleet_model.dart';
import 'host_pull_requests.dart';
import 'machines.dart';
import 'operations.dart';
import 'organization_source.dart';
import 'settings.dart';
import 'window_log.dart';

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

  /// Attached, and its agent's screen shows it at its prompt, waiting for its next turn. Read, not guessed.
  atRest,

  /// Quiet, as far as anything can tell. A guess.
  quiet,

  /// Up, and nothing on this side can see what it is doing.
  unseen,

  /// Its agent said its work is done, and it rests: it waits on nobody, and it is not running work.
  done,

  /// Not running.
  stopped,
}

/// One tile: a piece of work, or a question the list has not caught up with; under *Needs you*, one cause of it.
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
  /// A story ended or an issue reading stopped on its planning source.
  planning,

  /// A project server stopped for a person during preparation.
  host,

  /// A machine is not answering.
  silent,

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

  /// A pull request on a host's forge waits for the person's approval and merge.
  pullRequest,

  /// A host forge's pull requests cannot be read: a forge token is missing, or the machine refused.
  pullRequestsRefused,

  /// A person's operation failed.
  operation,

  /// One cause of one piece of work waiting on a person - a question, an end nobody has seen, a push at the gate -
  /// or what came out of a question.
  tile,

  /// A machine dropped questions unseen.
  missed,

  /// A question ran out with nobody answering it.
  ranOut,

  /// A machine waits for its first token, from the person looking.
  token,

  /// A project waits for its Git repository, from its Project Admin looking.
  repository,

  /// Stored machines are kept unread and not watched, as their host card does not read in this version.
  setAside,
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

/// One dependency holding up projects on a machine, with the daemon's vault path if reported.
typedef WaitingMessages = ({Machine machine, String waits, String waitsOn, String vault, List<Project> projects});

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

  /// Host setup owned by the frame, including stops before a Machine exists.
  HostRuns? get hostRuns => _hostRuns;
  set hostRuns(HostRuns? runs) {
    _hostRuns?.removeListener(_changed);
    _hostRuns = runs;
    runs?.addListener(_changed);
    _changed();
  }

  HostRuns? _hostRuns;

  PlanningBoards? _planning;

  /// Reuses the shell's planning watches rather than opening another subscription.
  set planning(PlanningBoards? boards) {
    _planning?.removeListener(_changed);
    _planning = boards;
    boards?.addListener(_changed);
    _changed();
  }

  /// Follows what [organization] waits for from this person: a machine's first token, as the last *Connect*
  /// found it, and a project's Git repository.
  void watchOrganization(Organization organization, HostConnections? connections) {
    _connections?.removeListener(_changed);
    _tokensOf?.removeListener(_changed);
    _connections = connections?..addListener(_changed);
    _tokensOf = organization..addListener(_changed);
    _changed();
  }

  HostConnections? _connections;
  Organization? _tokensOf;

  /// The machines waiting for a token this person can give; anyone else's row reads who it waits for.
  List<String> get _tokensWaited {
    final connections = _connections;
    final view = _tokensOf?.view;
    if (connections == null || view == null || !view.holdsRoles) return const <String>[];
    return <String>[
      for (final host in view.hosts)
        if (host.admins.contains(view.me) && connections.waitsForToken(host.name)) host.name,
    ];
  }

  /// The projects waiting for a Git repository this person can create. A stale or unread organization
  /// says nothing, as it cannot tell a repository is missing.
  List<String> get _repositoriesWaited {
    final view = _tokensOf?.view;
    if (view == null || view.stale || !view.holdsRoles) return const <String>[];
    return <String>[
      for (final project in view.projects)
        if (view.saysNoRepository(project) && project.admins.contains(view.me)) project.name,
    ];
  }

  /// What the row of a machine waiting for its token says it from.
  OrganizationView? get tokenView => _tokensOf?.view;

  /// This computer's connections to the organization's hosts, through which their forges are reached; null where the
  /// window has none.
  HostConnections? get hostConnections => _connections;

  final Machines _machines;
  final Settings? _settings;
  final Operations? _operations;
  final DateTime Function() _clock;

  /// The current instant from the frame's injectable clock.
  DateTime get now => _clock();

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
    _resolve(AttentionRow(row.kind, row.id, row.machine, row.value, read: read));
    _changed();
  }

  static String _messageId(Machine machine, HeldMessage message) =>
      'message ${machine.name}/${message.task}/${message.handle}';

  Iterable<AttentionRow> _rows() sync* {
    for (final entry in _planning?.needsYou ?? const <PlanningNeedsYou>[]) {
      if (_storyEndSeen(entry.id, entry.attention)) continue;
      yield AttentionRow(AttentionKind.planning, entry.id, entry.machine, entry.attention);
    }
    // Said here, where it stays while the records are set aside, never on a status line the next connection overwrites.
    if (_machines.setAside case final words? when !_seenMarks.contains(_setAsideKey(words))) {
      yield AttentionRow(AttentionKind.setAside, 'set aside', 'This computer', words);
    }
    for (final run in _hostRuns?.needingYou ?? <HostPreparation>[]) {
      yield AttentionRow(AttentionKind.host, 'host ${run.project}', run.name, HostStop(run));
    }
    for (final machine in missedQuestions) {
      yield AttentionRow(AttentionKind.missed, 'missed ${machine.name}', machine.name, (
        machine: machine,
        count: _fleet(machine)?.clearance.missed ?? 0,
      ));
    }
    for (final question in _ranOut) {
      if (!question.seen) {
        yield AttentionRow(AttentionKind.ranOut, 'ran out ${question.id}', question.machine, question);
      }
    }
    for (final project in _repositoriesWaited) {
      yield AttentionRow(AttentionKind.repository, 'repository $project', project, project);
    }
    final tokens = _tokensWaited;
    for (final host in tokens) {
      yield AttentionRow(AttentionKind.token, 'token $host', host, host);
    }
    // Connecting is still being read; a settled refusal or a token wait is what asks for a person.
    for (final (:machine, :fleet) in [
      for (final each in silent)
        if (_fleet(each) case final fleet?
            when fleet.reachability != Reachability.connecting && !tokens.contains(each.hostCard?.name))
          (machine: each, fleet: fleet),
    ]) {
      final what = switch (fleet.reachability) {
        _ when notConnectedYet(machine) => 'You have not connected to this machine yet',
        Reachability.connecting => 'This machine is still connecting, so nothing is known yet',
        Reachability.incompatible => 'This machine serves nothing this build understands',
        _ => 'This machine cannot be reached',
      };
      yield AttentionRow(AttentionKind.silent, 'silent ${machine.name}', machine.name, (
        machine: machine,
        words: '$what, and anything it is asking waits unseen.  ${fleet.status}',
      ));
    }
    for (final row in forwardsRefused) {
      yield AttentionRow(AttentionKind.forward, 'forward ${row.machine}/${row.project}', row.machine, row);
    }
    for (final row in messagesWaiting) {
      yield AttentionRow(
        AttentionKind.waiting,
        'waiting ${row.machine.name}/${row.waitsOn}/${row.vault}/${row.waits}',
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
    for (final machine in _counted) {
      final pullRequests = _fleet(machine)?.pullRequests;
      if (pullRequests == null) continue;
      for (final each in pullRequests.open) {
        yield AttentionRow(
          AttentionKind.pullRequest,
          'pull request ${machine.name}/${each.project.name}/${each.request.key}',
          machine.name,
          PullRequestRow(machine: machine, project: each.project, request: each.request, stale: each.stale),
        );
      }
      for (final each in pullRequests.refused) {
        yield AttentionRow(
          AttentionKind.pullRequestsRefused,
          'pull requests refused ${machine.name}/${each.project}',
          machine.name,
          PullRequestsRefusedRow(machine: machine, project: each.project, refusal: each.refusal),
        );
      }
    }
    final causes = this.causes;
    for (final cause in causes.where((cause) => cause.demand == Demand.question)) {
      yield _causeRow(cause);
    }
    for (final operation in failedUnseen) {
      yield AttentionRow(
        AttentionKind.operation,
        'operation ${operation.id}',
        operation.machine,
        Operation.fromStored(operation.toStored(operation.output.length))!,
      );
    }
    for (final cause in causes.where((cause) => cause.demand != Demand.question)) {
      yield _causeRow(cause);
    }
  }

  /// Whether the question [row] asked ran out, as its machine says now.
  bool _ranOutNow(AttentionRow row) {
    final cause = row.value;
    if (cause is! Tile || cause.questions.isEmpty) return false;
    final asked = cause.questions.first.identity;
    return cause.fleet.clearance.settled.any((each) => each.expired && each.identity == asked);
  }

  AttentionRow _causeRow(Tile cause) => AttentionRow(AttentionKind.tile, causeId(cause), cause.machine.name, cause);

  /// The row id of one cause from [causes], or of what came out of a question: a question by its own identity, so
  /// two questions of one task are two rows and its answer replaces the question it answers.
  static String causeId(Tile cause) {
    final machine = cause.machine.name;
    final work = '$machine/${cause.task?.name ?? cause.questions.firstOrNull?.task ?? cause.settled?.task ?? ''}';
    return switch (cause.demand) {
      Demand.question when cause.questions.isNotEmpty => 'question $machine/${cause.questions.first.identity}',
      Demand.question when cause.settled != null => 'question $machine/${cause.settled!.identity}',
      Demand.question => 'waits $work',
      Demand.ended => 'ended $work',
      _ => 'gate $work',
    };
  }

  /// Each cause that waits on a person, as a tile of its own, most urgent first: every open question, a wait the
  /// task says it is in with nothing asked, an end nobody has seen and a push at the gate. One piece of work can
  /// hold several at once, and none hides another.
  List<Tile> get causes => <Tile>[for (final tile in needing) ..._causesOf(tile)]..sort(_byDemand);

  /// Whether a question of [tile]'s work was settled since its wait began: the list has not caught up with the
  /// answer yet, and the wait it still says is that question's. Unknown where the list says no start.
  static bool _answeredSince(Tile tile) {
    final since = DateTime.tryParse(tile.task?.since ?? '');
    if (since == null) return false;
    return tile.fleet.clearance.settled.any(
      (each) => each.task == tile.task!.name && !(DateTime.tryParse(each.at)?.isBefore(since) ?? true),
    );
  }

  List<Tile> _causesOf(Tile tile) {
    final task = tile.task;
    Tile cause(Demand demand, [List<Prompt> questions = const <Prompt>[]]) =>
        Tile(machine: tile.machine, fleet: tile.fleet, demand: demand, task: task, questions: questions);
    return <Tile>[
      for (final question in tile.questions) cause(Demand.question, <Prompt>[question]),
      if (task != null && tile.questions.isEmpty && task.activity == Activity.waiting && !_answeredSince(tile))
        cause(Demand.question),
      if (task != null && !_endSeen(tile.machine, task) && (task.agentEnded?.needsSomebody ?? false))
        cause(Demand.ended),
      if (task?.hasWorkWaiting ?? false) cause(Demand.gate),
    ];
  }

  /// [row] as it ended: a pull request with how the machine confirmed it ended, where it did.
  AttentionRow _asItEnded(AttentionRow row, Machine? machine) {
    if (row.kind != AttentionKind.pullRequest || machine == null) return row;
    final value = row.value as PullRequestRow;
    final ended = _fleet(machine)?.pullRequests.endedAs(value.project.name, value.request.key);
    if (ended == null) return row;
    return AttentionRow(
      row.kind,
      row.id,
      row.machine,
      PullRequestRow(
        machine: value.machine,
        project: value.project,
        request: value.request,
        stale: false,
        ended: ended,
      ),
      read: row.read,
    );
  }

  void _rememberRows() {
    _noteRanOut();
    final rows = _rows().toList();
    final present = rows.map((row) => row.id).toSet();
    for (final old in _lastRows.values.where(
      (row) => row.kind == AttentionKind.planning && !present.contains(row.id),
    )) {
      final value = old.value as PlanningAttention;
      if (machineNamed(old.machine) == null || _storyEndSeen(old.id, value)) continue;
      final source = _planning?.sources
          .where((board) => _planning!.machineOf(board) == old.machine && board.project == value.project)
          .firstOrNull;
      if (source == null ||
          !source.live ||
          source.snapshot?.complete != true ||
          value.ended != null &&
              source.stories.any((story) => story.id == value.story.id) &&
              !source.endedCurrent(source.stories.firstWhere((story) => story.id == value.story.id))) {
        rows.add(old);
      }
    }
    final ids = rows.map((row) => row.id).toSet();
    _readMessages.removeWhere((id) => !ids.contains(id));
    final wasOpen = {for (final row in _openRows) row.id};
    _openRows = rows.where((row) => !_readMessages.contains(row.id)).toList();
    final open = {for (final row in _openRows) row.id: row};
    // A wait that ends became its question or went on, and a question that ran out has its own row: neither is
    // resolved, so neither is said to be.
    _lastRows.removeWhere(
      (id, row) => !open.containsKey(id) && (id.startsWith('waits ') || id.startsWith('question ') && _ranOutNow(row)),
    );
    for (final row in _lastRows.values) {
      if (open.containsKey(row.id)) continue;
      final machine = machineNamed(row.machine);
      final fleet = machine == null ? null : _fleet(machine);
      // Losing contact is not resolution; retain the last facts until this machine answers again.
      final resolved =
          row.kind == AttentionKind.operation ||
          row.kind == AttentionKind.ranOut ||
          row.kind == AttentionKind.host && _hostResolved(row.value as HostStop) ||
          (row.kind != AttentionKind.host &&
              fleet != null &&
              (fleet.reachability == Reachability.connected &&
                      (row.kind != AttentionKind.message || fleet.mailboxes.problem == null) ||
                  row.kind == AttentionKind.silent && _seenMarks.contains(row.machine)));
      if (resolved) _resolve(_asItEnded(row, machine));
    }
    _keepOutcomes(open);
    _lastRows.removeWhere(
      (id, row) =>
          open.containsKey(id) ||
          _resolved.containsKey(id) ||
          row.kind != AttentionKind.operation &&
              row.kind != AttentionKind.ranOut &&
              row.kind != AttentionKind.host &&
              machineNamed(row.machine) == null,
    );
    _lastRows.addAll(open);
    for (final id in open.keys) {
      _resolved.remove(id);
    }
    // A row that came back is a new occurrence, and a row gone with nobody resolving it needs no mark.
    _saidPutAway.removeWhere(
      (id) => open.containsKey(id) && !wasOpen.contains(id) || !_lastRows.containsKey(id) && !open.containsKey(id),
    );
    _resolved.removeWhere(
      (_, each) =>
          each.row.kind != AttentionKind.operation &&
          each.row.kind != AttentionKind.ranOut &&
          each.row.kind != AttentionKind.host &&
          machineNamed(each.row.machine) == null,
    );
    _prune();
    _scheduleExpiry();
  }

  /// Places [row] under *Recently resolved*, writing to the window's log once that it was, unless a person put it
  /// away and that was written already.
  void _resolve(AttentionRow row) {
    final already = _resolved.containsKey(row.id);
    _resolved[row.id] = ResolvedAttention(row, _clock());
    if (already || _saidPutAway.remove(row.id)) return;
    windowLog.info('Needs you: resolved ${_wordsOf(row)}', machine: row.machine);
  }

  /// Rows whose putting away was written to the log, so their resolution is not written again.
  final Set<String> _saidPutAway = <String>{};

  /// Writes to the window's log that a person put away the row [id], with what it said: the open one, or the one last
  /// shown where it is out for a moment while its machine is tried again.
  void _putAway(String id) {
    final row = _openRows.where((each) => each.id == id).firstOrNull ?? _lastRows[id];
    if (row == null) return;
    _saidPutAway.add(id);
    windowLog.info('Needs you: put away ${_wordsOf(row)}', machine: row.machine);
  }

  /// What [row] said, on one line, by its kind; never a message's or a credential's content.
  static String _wordsOf(AttentionRow row) {
    final words = switch (row.value) {
      (machine: Machine _, words: final String words) => words,
      (machine: Machine _, problem: final String problem) => problem,
      (machine: Machine _, count: final int count) => '$count questions were dropped unseen',
      (machine: Machine _, message: final HeldMessage message) =>
        'a ${message.kind.isEmpty ? 'message' : message.kind} of ${message.task} is held for you',
      (machine: Machine _, needed: final AuthorizationNeeded needed) => '${needed.credential} needs a grant',
      (machine: String _, project: final String project, words: final String words) => '$project: $words',
      final WaitingMessages waiting => 'messages wait: ${waiting.waits}',
      final Tile tile => _tileWords(tile),
      final Operation operation => '${operation.title}: ${operation.summary}',
      final RanOutQuestion question => '${question.task} asked to reach ${question.shown}, and it ran out',
      final HostStop stop => '${stop.project} server: ${stop.text}',
      final PullRequestRow each => 'pull request ${each.request.title} of ${each.project.name}',
      final PullRequestsRefusedRow each => each.words,
      final PlanningAttention planning =>
        'story ${planning.story.id} of ${planning.project}'
            '${planning.ended == null ? '' : ', its work ended'}${planning.reason.isEmpty ? '' : ': ${planning.reason}'}',
      final String words when row.kind == AttentionKind.setAside => words,
      final String name when row.kind == AttentionKind.token => '$name waits for your token',
      final String name when row.kind == AttentionKind.repository => '$name waits for its Git repository',
      _ => row.id,
    };
    return '(${row.kind.name}) $words';
  }

  static String _tileWords(Tile tile) {
    final work = tile.task?.name ?? tile.questions.firstOrNull?.task ?? tile.settled?.task ?? 'work not listed yet';
    final asked = tile.questions.firstOrNull ?? tile.settled;
    return switch (tile.demand) {
      Demand.question when asked != null =>
        '$work asked to reach ${asked.shown}${asked.verdict == null ? '' : ', answered ${asked.verdict}'}',
      Demand.question => '$work waits on a person',
      Demand.ended => '$work ended, and nobody had looked',
      _ => '$work has a push waiting at the gate',
    };
  }

  /// Questions that ran out, where no settings keep them.
  List<RanOutQuestion> _ranOutHere = const <RanOutQuestion>[];

  List<RanOutQuestion> get _ranOut => _settings?.ranOut ?? _ranOutHere;

  /// How many seen questions are kept, so a machine saying one again does not bring it back.
  static const _ranOutSeenKept = 50;

  /// How long a seen question that ran out is kept. `Prompts` is a stream that never says a question is gone, so its
  /// mark cannot wait for a whole read: it guards a machine sending the same occurrence again, which happens on a
  /// connection made again, and a week outlasts a computer asleep over a weekend.
  static const ranOutSeenKeptFor = Duration(days: 7);

  /// One occurrence of a question that ran out: its machine, its identity there, and when it ran out.
  static String _ranOutId(String machine, Prompt prompt) => '$machine/${prompt.identity} at ${prompt.at}';

  /// Whether the marks kept in the settings may be pruned and written: they have been read, or none are kept.
  bool get _marksRead => _settings?.loaded ?? true;

  void _setRanOut(List<RanOutQuestion> questions) {
    final settings = _settings;
    if (settings == null) {
      _ranOutHere = questions;
    } else {
      unawaited(settings.setRanOut(questions));
    }
  }

  /// Files each question a machine says ran out, once per occurrence, so it counts until seen and past a restart,
  /// and drops seen ones past [ranOutSeenKeptFor]. A seen one an older build kept says no occurrence and hides none,
  /// so it is dropped too. Nothing is filed or dropped before the settings are read.
  ///
  /// An occurrence already seen is forgotten as its machine says it again, so it is not filed again once its mark is
  /// gone; a later occurrence of a question nobody has seen yet takes the place of the earlier, so work retrying a
  /// blocked connection is one row.
  void _noteRanOut() {
    if (!_marksRead) return;
    final seen = {
      for (final each in _ranOut)
        if (each.seen) each.id,
    };
    final oldest = _clock().subtract(ranOutSeenKeptFor);
    var kept = [
      for (final each in _ranOut)
        if (!each.seen || (DateTime.tryParse(each.seenAt)?.isAfter(oldest) ?? false)) each,
    ];
    final known = {for (final each in kept) each.id};
    final fresh = <RanOutQuestion>[];
    final again = <({Clearance clearance, Prompt prompt})>[];
    for (final machine in _machines.all) {
      final clearance = _fleet(machine)?.clearance;
      if (clearance == null) continue;
      for (final prompt in clearance.settled.where((each) => each.expired)) {
        final id = _ranOutId(machine.name, prompt);
        if (seen.contains(id)) again.add((clearance: clearance, prompt: prompt));
        if (!known.add(id)) continue;
        final question = '${machine.name}/${prompt.identity} at ';
        kept = [
          for (final each in kept)
            if (each.seen || !each.id.startsWith(question)) each,
        ];
        fresh.add(RanOutQuestion(id: id, machine: machine.name, task: prompt.task, shown: prompt.shown));
      }
    }
    if (again.isNotEmpty) {
      // Not now: this runs while rows are worked out, and forgetting changes what they are worked out from.
      scheduleMicrotask(() {
        if (_disposed) return;
        for (final (:clearance, :prompt) in again) {
          if (clearance.settled.any((each) => each.identity == prompt.identity && each.at == prompt.at)) {
            clearance.forget(prompt);
          }
        }
      });
    }
    final now = [...kept, ...fresh];
    if (now.length != _ranOut.length || fresh.isNotEmpty) _setRanOut(now);
  }

  /// Takes a failed operation off what needs a person unopened: somebody has seen it. A row holds a copy, so the
  /// operation is found by its id.
  void operationSeen(Operation operation) {
    _putAway('operation ${operation.id}');
    final operations = _operations;
    final kept = operations?.all.where((each) => each.id == operation.id).firstOrNull;
    if (kept != null) operations!.see(kept);
  }

  /// Takes a question that ran out off what needs a person: somebody has seen it.
  void ranOutSeen(RanOutQuestion question) {
    _putAway('ran out ${question.id}');
    final seen = [
      for (final each in _ranOut)
        if (each.id != question.id && each.seen) each,
    ];
    _setRanOut([
      ...seen.skip(seen.length > _ranOutSeenKept ? seen.length - _ranOutSeenKept : 0),
      question.seenAs(_clock()),
      for (final each in _ranOut)
        if (each.id != question.id && !each.seen) each,
    ]);
    for (final machine in _machines.all.where((each) => each.name == question.machine)) {
      final clearance = _fleet(machine)?.clearance;
      if (clearance == null) continue;
      for (final prompt in clearance.settled) {
        if (_ranOutId(machine.name, prompt) == question.id) clearance.forget(prompt);
      }
    }
    _changed();
  }

  /// Outcomes already placed under *Recently resolved*, so one whose time is up does not return.
  final Set<String> _outcomesKept = <String>{};

  /// Places what came out of each question under *Recently resolved*, once, with its words, under the id of the
  /// question it answers: whatever else its work holds has rows of its own.
  void _keepOutcomes(Map<String, AttentionRow> open) {
    String keyOf(String machine, Prompt prompt) => '$machine/${prompt.identity}';
    for (final machine in _counted) {
      final fleet = _fleet(machine);
      if (fleet == null || fleet.reachability != Reachability.connected) continue;
      for (final asked in fleet.clearance.waiting) {
        _outcomesKept.remove(keyOf(machine.name, asked));
      }
      // One that ran out has a row of its own until it is seen.
      for (final settled in fleet.clearance.settled.where((each) => !each.expired)) {
        final row = _causeRow(
          Tile(
            machine: machine,
            fleet: fleet,
            demand: Demand.question,
            task: fleet.tasks.where((task) => task.name == settled.task).firstOrNull,
            settled: settled,
          ),
        );
        if (open.containsKey(row.id) || !_outcomesKept.add(keyOf(machine.name, settled))) continue;
        _resolve(row);
      }
    }
    _outcomesKept.retainAll(<String>{
      for (final machine in _machines.all)
        for (final prompt in _fleet(machine)?.clearance.settled ?? const <Prompt>[]) keyOf(machine.name, prompt),
    });
  }

  bool _hostResolved(HostStop stop) {
    final run = _hostRuns?.of(stop.project);
    return run != null && (run.ready || run.givenBack || stop.interrupted && !run.interrupted);
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
  /// This computer, where no Porelo is installed, is not one: nothing was ever going to answer there. Nor is one not
  /// opened yet: its opening is the try a person would ask for.
  List<Machine> get silent => <Machine>[
    for (final machine in _counted)
      if (_fleet(machine)?.reachability case final reachability?
          when reachability != Reachability.connected &&
              !_seenMarks.contains(machine.name) &&
              !(machine.isThisComputer && !_machines.poreloIsInstalledHere))
        machine,
  ];

  /// Whether [machine] is a host that has not answered yet: quiet because nobody has connected, not gone silent.
  bool notConnectedYet(Machine machine) =>
      machine.kind == 'host' &&
      !(_fleet(machine)?.answered ?? false) &&
      _fleet(machine)?.reachability != Reachability.incompatible;

  /// Every machine once: one node reached two ways would deliver every question twice, and draw all
  /// its work twice.
  List<Machine> get machinesOnce => _counted;

  /// Whether every machine in the Work scope has a current list, including an empty scope.
  bool workRead({Machine? onlyMachine}) {
    final scope = onlyMachine == null ? machinesOnce : [onlyMachine];
    return scope.every(
      (machine) =>
          _machines.all.contains(machine) &&
          _fleet(machine)?.reachability == Reachability.connected &&
          _fleet(machine)!.listRead,
    );
  }

  /// The whole Work total; a filter never changes it and an incomplete read has no total.
  int? get workCount => workRead() ? tiles.length : null;

  /// Whether every machine has either supplied a list or reported why it cannot answer.
  bool get needsRead => machinesOnce.every(
    (machine) => switch (_fleet(machine)?.reachability) {
      null || Reachability.connecting => false,
      Reachability.connected => _fleet(machine)!.listRead,
      Reachability.unreachable || Reachability.incompatible => true,
    },
  );

  /// Visible waiting rows always count; an incomplete empty read is not a known zero.
  int? get needingCount => needingSomebody > 0 || needsRead ? needingSomebody : null;

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

  /// Every machine whose messages wait, with the machine's reason and the projects it holds up: the
  /// vault locked stops every conversation at once, and said nowhere a person looked (walk 10).
  List<WaitingMessages> get messagesWaiting => [
    for (final machine in _counted)
      for (final reason in <(String, String, String)>{
        for (final each in _fleet(machine)?.projects ?? const <ProjectOnScreen>[])
          if (each.project.messages case final messages? when messages.waits.isNotEmpty)
            (messages.waits, messages.waitsOn, messages.vault),
      })
        (
          machine: machine,
          waits: reason.$1,
          waitsOn: reason.$2,
          vault: reason.$3,
          projects: [
            for (final each in _fleet(machine)?.projects ?? const <ProjectOnScreen>[])
              if (each.project.messages?.waits == reason.$1 &&
                  each.project.messages?.waitsOn == reason.$2 &&
                  each.project.messages?.vault == reason.$3)
                each.project,
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
      for (final message in _fleet(machine)?.mailboxes.waiting ?? const <HeldMessage>[])
        (machine: machine, message: message),
  ];

  /// Every authorization a person has to grant before work can use it, on every machine, oldest first.
  List<({Machine machine, AuthorizationNeeded needed})> get authorizationsNeeded =>
      <({Machine machine, AuthorizationNeeded needed})>[
        for (final machine in _counted)
          for (final needed in _fleet(machine)?.authorizations.open ?? const <AuthorizationNeeded>[])
            (machine: machine, needed: needed),
      ];

  /// Every machine that cannot say what is held for a person, so its silence is not read as none.
  List<({Machine machine, String problem})> get unlistedMessages => <({Machine machine, String problem})>[
    for (final machine in _counted)
      if (_fleet(machine) case final fleet? when fleet.reachability == Reachability.connected)
        if (fleet.mailboxes.problem case final problem?) (machine: machine, problem: problem),
  ];

  /// One occurrence of a story's ended work: the entry's id and when its work ended; null where nothing ended.
  static String? _storyEndKey(String id, PlanningAttention attention) {
    final ended = attention.ended;
    return ended == null ? null : '$id at ${ended.at}';
  }

  bool _storyEndSeen(String id, PlanningAttention attention) {
    final key = _storyEndKey(id, attention);
    return key != null && _endedPutAway.contains(key);
  }

  /// Takes a story's ended work off what needs a person: somebody has seen it. Its next end is said again.
  ///
  /// A story's mark is dropped only once the board that names the story is live and complete and says that end no
  /// longer; the marks of work's own ends are not touched here.
  void storyEndSeen(AttentionRow row) {
    if (row.kind != AttentionKind.planning) return;
    final attention = row.value as PlanningAttention;
    final key = _storyEndKey(row.id, attention);
    if (key == null) return;
    _putAway(row.id);
    final settings = _settings;
    if (settings == null || !_marksRead || attention.ended!.at.isEmpty) {
      // Without a time, a mark could hide the story's next end; it lasts as long as this window.
      _endedSession.add(key);
      _changed();
      return;
    }
    final storyEndGone = _storyEndGone();
    unawaited(
      settings.setEndedPutAway(<String>{
        for (final end in settings.endedPutAway)
          if (!storyEndGone(end)) end,
        key,
      }),
    );
  }

  /// Whether a mark of a story's end names one its board no longer says, read whole: live, complete, and every
  /// story's work read, so a story whose work cannot be read now keeps its mark. False for any other mark.
  bool Function(String mark) _storyEndGone() {
    final planning = _planning;
    final current = <String>{
      for (final entry in planning?.needsYou ?? const <PlanningNeedsYou>[]) ?_storyEndKey(entry.id, entry.attention),
    };
    final readWhole = <String>[
      for (final board in planning?.sources ?? const <PlanningBoard>[])
        if (board.live && board.snapshot?.complete == true && board.stories.every(board.endedCurrent))
          '$_storyEnded${planning!.machineOf(board)}/${board.project}/',
    ];
    return (mark) => mark.startsWith(_storyEnded) && !current.contains(mark) && readWhole.any(mark.startsWith);
  }

  /// Whether a mark of a task's end names one its machine no longer lists, having said its list: one not loaded,
  /// not answering or still reading its list says nothing, so its ends stay. False for a story's mark.
  bool Function(String mark) _taskEndGone() {
    final listed = <String>{
      for (final machine in _machines.all)
        for (final each in _fleet(machine)?.tasks ?? const <Task>[])
          if (each.agentEnded case final end?) _endKey(machine.name, each, end),
    };
    final saidItsList = <String>[
      for (final machine in _machines.all)
        if (_fleet(machine) case final fleet? when fleet.reachability == Reachability.connected && fleet.listRead)
          '${machine.name}/',
    ];
    return (mark) => !mark.startsWith(_storyEnded) && !listed.contains(mark) && saidItsList.any(mark.startsWith);
  }

  /// How the id of a story's ended work begins.
  static const _storyEnded = 'story ended ';

  /// The mark of the notice of machines set aside, by its words, which name them.
  static String _setAsideKey(String words) => 'set aside: $words';

  /// Takes the notice of machines set aside off what needs a person, until the machines set aside change.
  void setAsideSeen() {
    final words = _machines.setAside;
    if (words == null) return;
    _putAway('set aside');
    final settings = _settings;
    if (settings == null || !_marksRead) {
      _silentSession.add(_setAsideKey(words));
      _changed();
      return;
    }
    unawaited(settings.setSeenSilent(<String>{...settings.seenSilent, _setAsideKey(words)}));
  }

  /// Marks of silence and of the set-aside notice: the settings' and this window's own.
  Set<String> get _seenMarks => <String>{...?_settings?.seenSilent, ..._silentSession};

  /// Such marks made where no settings keep them, or before they were read.
  final Set<String> _silentSession = <String>{};

  /// Stops saying that [machine] is silent, until it has answered again.
  Future<void> markSeen(Machine machine) async {
    _putAway('silent ${machine.name}');
    final settings = _settings;
    if (settings == null || !_marksRead) {
      _silentSession.add(machine.name);
      _changed();
      return;
    }
    await settings.setSeenSilent(<String>{...settings.seenSilent, machine.name});
  }

  bool _disposed = false;

  /// A machine that answers again is forgotten as seen, so its next silence is said; so is the notice of machines set
  /// aside once the stored machines were read and others are set aside. Only once the settings were read.
  void _changed() {
    if (_disposed) return;
    final settings = _settings;
    final answering = <String>{
      for (final machine in _machines.all)
        if (_fleet(machine)?.reachability == Reachability.connected) machine.name,
    };
    final setAside = _machines.setAside;
    bool gone(String mark) =>
        answering.contains(mark) ||
        mark.startsWith(_setAsideKey('')) &&
            (settings?.machinesRead ?? true) &&
            (setAside == null || mark != _setAsideKey(setAside));
    _silentSession.removeWhere(gone);
    if (_endedSession.isNotEmpty) {
      // This window's own marks go as the stored ones do, so a mark with no time hides no later end.
      final taskEndGone = _taskEndGone();
      final storyEndGone = _storyEndGone();
      _endedSession.removeWhere((mark) => taskEndGone(mark) || storyEndGone(mark));
    }
    if (settings != null && settings.loaded && settings.seenSilent.any(gone)) {
      // Not now: this runs while the frame is being drawn, and settings changing would redraw it. Pruned from the
      // marks as they are then, so one set meanwhile is kept.
      scheduleMicrotask(() {
        if (_disposed || !settings.seenSilent.any(gone)) return;
        unawaited(settings.setSeenSilent({...settings.seenSilent.where((mark) => !gone(mark))}));
      });
    }
    _rememberRows();
    notifyListeners();
  }

  /// The model of one machine, for a row's machine: rows are worked out from watched machines alone.
  FleetModel fleetOf(Machine machine) => _machines.of(machine);

  /// The model of [machine] while it is watched; one listed and not opened yet answers nothing.
  FleetModel? _fleet(Machine machine) => _machines.watching(machine);

  /// Every tile, most urgent first.
  List<Tile> get tiles => <Tile>[for (final machine in _counted) ..._tilesOf(machine)]..sort(_byDemand);

  /// The tiles that need a person: an open question, work waiting at the gate, work that ended with
  /// a failure or left something nobody has seen, until it is opened or put away, or the outcome of a
  /// question that was answered or ran out and has not been put away. Work that finished with nothing
  /// waiting is none of these: it stays under Work alone.
  ///
  /// **What the window opens on**, as [causes], one row per cause of each. A list of every tile is,
  /// at fifty tasks, fifty tiles of which two need anybody — and the reason to open the window is
  /// the two. Everything else — working, quiet, unseen, stopped — is still drawn, in its machine's
  /// area, which is where somebody looking at that machine goes.
  ///
  /// **What came out of a question needs nobody**: it goes under *Recently resolved*, which keeps it
  /// for a set time, so a question that ran out while nobody looked leaves a trace, an answer keeps
  /// its confirmation, and neither counts for ever.
  List<Tile> get needing => <Tile>[
    for (final tile in tiles)
      if (tile.demand == Demand.question || tile.demand == Demand.ended || tile.demand == Demand.gate) tile,
  ];

  /// One machine's tiles, most urgent first. While it is not answering they are what it last
  /// said: a lost tunnel is a disconnection, never a machine with nothing on it.
  List<Tile> tilesOn(Machine machine) => _tilesOf(machine, evenSilent: true)..sort(_byDemand);

  List<Tile> _tilesOf(Machine machine, {bool evenSilent = false}) {
    final out = <Tile>[];
    final fleet = _fleet(machine);
    if (fleet != null && (evenSilent || fleet.reachability == Reachability.connected)) {
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
            demand: demandOf(task, questions, endSeen: _endSeen(machine, task)),
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
      if ((_fleet(machine)?.clearance.missed ?? 0) > 0) machine,
  ];

  /// How many things need somebody now: every row, work at the gate like any other. The page's
  /// header and the rail's badge both say this one number.
  int get needingSomebody => _openRows.length;

  /// Ends put away where no settings keep them, before they were read, or with no time to tell them from the next.
  final Set<String> _endedSession = <String>{};

  Set<String> get _endedPutAway => <String>{...?_settings?.endedPutAway, ..._endedSession};

  /// One end of one task's work. Its time tells ends apart where the machine gives one, and when the
  /// work's state began where it gives none; what the end says tells apart what came to light later.
  /// The error's own words are not kept: they are the agent's and the provider's, in the settings file.
  static String _endKey(String machine, Task task, AgentEnded ended) =>
      '$machine/${task.name}/${ended.at.isEmpty ? task.since : ended.at}/${ended.finished}/${ended.status}/${ended.unpushed}';

  /// Whether somebody opened or put away how [task] on [machine] ended. The next end is another one, and an end
  /// that left files outside the gate is never seen away, whatever a mark says: those files are still owed.
  ///
  /// An end with no time is seen only by this window's own mark: one an older build kept names no occurrence.
  bool _endSeen(Machine machine, Task task) {
    final ended = task.agentEnded;
    if (ended == null || ended.unpushed > 0) return false;
    final key = _endKey(machine.name, task, ended);
    return ended.at.isEmpty && task.since.isEmpty ? _endedSession.contains(key) : _endedPutAway.contains(key);
  }

  /// Takes how [tile]'s work ended off what needs a person, because it was opened or put away: what
  /// else the work holds, such as a push at the gate, stays. An end that left files outside the gate stays too.
  void putAwayTheEnd(Tile tile) {
    final task = tile.task;
    final ended = task?.agentEnded;
    if (task == null || ended == null || ended.unpushed > 0) return;
    _putAway(causeId(Tile(machine: tile.machine, fleet: tile.fleet, demand: Demand.ended, task: task)));
    final settings = _settings;
    if (settings == null || !_marksRead || ended.at.isEmpty && task.since.isEmpty) {
      // Without a time, a mark could hide the next end; it lasts as long as this window.
      _endedSession.add(_endKey(tile.machine.name, task, ended));
      _changed();
      return;
    }
    // Only ends still listed are kept, or a machine with years of work would fill the settings.
    final taskEndGone = _taskEndGone();
    final kept = <String>{
      for (final end in settings.endedPutAway)
        if (!taskEndGone(end)) end,
      _endKey(tile.machine.name, task, ended),
    };
    unawaited(settings.setEndedPutAway(kept));
  }

  /// Why one piece of work sits where it does. With [endSeen], how it ended is known to somebody.
  static Demand demandOf(Task task, List<Prompt> questions, {bool endSeen = false}) {
    if (questions.isNotEmpty || task.activity == Activity.waiting) return Demand.question;
    // Before the gate and before working: an ended agent's container can still look busy.
    if (!endSeen && (task.agentEnded?.needsSomebody ?? false)) return Demand.ended;
    if (task.hasWorkWaiting) return Demand.gate;
    // Before stopped and running alike: its own word, which a stopped container and an idle one both keep.
    if (task.activity == Activity.done) return Demand.done;
    if (task.activity == Activity.dead || !task.running) return Demand.stopped;
    return switch (task.activity.name) {
      'WORKING' => Demand.working,
      'AT_REST' => Demand.atRest,
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
    final byTask = (a.task?.name ?? '').compareTo(b.task?.name ?? '');
    if (byTask != 0) return byTask;
    // Two questions of one work, or of work not listed yet, are told apart by what they ask.
    return (a.questions.firstOrNull?.identity ?? '').compareTo(b.questions.firstOrNull?.identity ?? '');
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
      for (final machine in _machines.all)
        if (_fleet(machine) case final fleet?) ...<Listenable>[
          fleet,
          fleet.clearance,
          fleet.mailboxes,
          fleet.authorizations,
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
    _disposed = true;
    _planning?.removeListener(_changed);
    _machines.removeListener(_follow);
    _settings?.removeListener(_changed);
    _operations?.removeListener(_changed);
    _hostRuns?.removeListener(_changed);
    _connections?.removeListener(_changed);
    _tokensOf?.removeListener(_changed);
    _homeservers?.removeListener(_changed);
    _expiry?.cancel();
    for (final each in _following) {
      each.removeListener(_changed);
    }
    super.dispose();
  }
}
