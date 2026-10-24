import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'legacy_forge_key.dart';
export 'legacy_forge_key.dart';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/homeserver_forwards.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/forge_connection.dart';
import 'package:porelo_frontend/src/app/project_workspace.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/fleet_model.dart';
import 'package:porelo_frontend/src/app/host_keys.dart';
import 'package:porelo_frontend/src/app/machine_setup.dart';
import 'package:porelo_frontend/src/app/egress.dart';
import 'package:porelo_frontend/src/app/agent_inventory.dart';
import 'package:porelo_frontend/src/app/emergency_stop.dart';
import 'package:porelo_frontend/src/app/start_work.dart';
import 'package:porelo_frontend/src/app/templates.dart';
import 'package:porelo_frontend/src/app/project_deletion.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:porelo_frontend/src/app/vault.dart';
import 'package:porelo_frontend/src/app/device_key.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_frontend/src/app/widening.dart';
import 'package:porelo_frontend/src/app/work_held.dart';
import 'package:porelo_frontend/src/app/gate.dart';
import 'package:porelo_frontend/src/app/authentication.dart';
import 'package:porelo_frontend/src/app/backups.dart';
import 'package:porelo_frontend/src/app/host_readiness.dart';
import 'package:porelo_frontend/src/app/logs.dart';
import 'package:porelo_frontend/src/app/links.dart';
import 'package:porelo_frontend/src/app/login_forward.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/narrowing.dart';
import 'package:porelo_frontend/src/app/connections.dart';
import 'package:porelo_frontend/src/ui/choice_field.dart';
import 'package:porelo_frontend/src/app/project_following.dart';
import 'package:porelo_frontend/src/app/newer_version.dart';
import 'package:porelo_frontend/src/app/where_you_were.dart';
import 'package:porelo_frontend/src/app/notifications.dart';
import 'package:porelo_frontend/src/app/operations.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/app/porelo_app.dart';

/// A backend that answers whatever a scenario needs it to.
///
/// Not the mock daemon, and the difference is the point: the mock daemon proves the *client*
/// over a real socket, and it lives in `test/client` where the wire is what is being judged.
/// This proves the *frame*, which is judged on what a person sees — including when the backend
/// refuses, has no `Watch`, or goes away. A widget test runs on a fake clock and real socket
/// input never completes under it, so the frame has to be reachable without one.
class FakeBackend implements FleetBackend {
  /// Constructor taking what the machine has on it.
  FakeBackend(this._tasks);

  List<Task> _tasks;
  final _changes = StreamController<List<Task>>.broadcast();

  /// What `GetInfo` answers.
  ServiceInfo whatItIs = const ServiceInfo(
    product: 'Porelo',
    version: '0.1.0-mock',
    vendor: 'fuin.org',
    interfaces: <String>['org.varlink.service', 'org.fuin.porelo.Tasks1'],
  );

  /// Set to refuse [open], the way a machine with no daemon on it does.
  VarlinkDisconnected? absent;

  /// Set to refuse [watch], the way a backend older than `Watch` does.
  bool withoutWatch = false;

  /// What the most recent [startTask] is printing into.
  ///
  /// The scenario drives it: a line at a time, ended when the scenario says so. Nothing here is
  /// on a clock, or a test of a long operation becomes a test of how fast the machine is.
  late StreamController<Object> launch;

  /// How many launches have been asked for, and with what.
  final List<bool> launched = <bool>[];

  /// Every launch, as it was asked for. What mode and prompt went down the socket is the whole
  /// of it — a screen that offered one and sent another would be wrong invisibly.
  final List<({String? task, String? project, String? agent, Mode? mode, String? prompt, String? repository})> starts =
      <({String? task, String? project, String? agent, Mode? mode, String? prompt, String? repository})>[];

  /// What `Agents` answers, and what could not be read.
  List<Agent> theAgentsItHas = <Agent>[
    Agent.from(const <String, dynamic>{
      'name': 'an-agent',
      'label': 'An Agent',
      'binary': '/usr/bin/an-agent',
      'version': '2.4.0',
      'from': '/usr/share/porelo/agents/an-agent.yml',
      'allowedDomains': <String>['api.anthropic.com'],
      'refusedDomains': <String>['telemetry.example.test'],
      // What its commits are attributed to. The second agent has none, which is what an agent
      // installed by a Porelo older than the field answers — a state to render, not a blank.
      'commitsAs': <String, dynamic>{'name': 'An Agent', 'email': 'an-agent@porelo.invalid'},
      'artifacts': <Map<String, dynamic>>[
        <String, dynamic>{
          'url': 'https://example.test/an-agent-2.4.0.tar.gz',
          'sha256': '3b1f8e2a9c4d5067a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718',
          'target': '/opt/an-agent',
          'unverified': false,
          'reason': '',
        },
      ],
    }),
    Agent.from(const <String, dynamic>{
      'name': 'other-agent',
      'label': 'Another Agent',
      'binary': '/usr/bin/other-agent',
      'version': '',
      'from': '/etc/porelo/agents/other-agent.yml',
      'allowedDomains': <String>['api.example.test'],
      'artifacts': <Map<String, dynamic>>[
        <String, dynamic>{
          'url': 'https://example.test/other-agent-latest.tar.gz',
          'sha256': '',
          'target': '/opt/other-agent',
          'unverified': true,
          'reason': 'upstream publishes no digest for the rolling build',
        },
      ],
    }),
  ];

  /// Binaries installed and never started, because another copy wins.
  List<ShadowedAgent> theAgentsItNeverUses = const <ShadowedAgent>[];

  /// Agents that could not be read, and why.
  Map<String, String> theAgentsItCannotRead = const <String, String>{};

  @override
  Future<AgentsOnTheMachine> agentsOn() async {
    if (agentsTake > Duration.zero) await Future<void>.delayed(agentsTake);
    return (agents: theAgentsItHas, failures: theAgentsItCannotRead, shadowed: theAgentsItNeverUses);
  }

  /// How long the machine takes to say which agents it has.
  Duration agentsTake = Duration.zero;

  @override
  String get label => 'mock';

  @override
  Future<ServiceInfo> open() async {
    final later = answersLater;
    if (later != null) await later.future;
    final refusal = absent;
    if (refusal != null) throw refusal;
    return whatItIs;
  }

  /// Set to make the next [open] wait until the scenario completes it; until then, what is asked
  /// of it is refused as the real backend refuses it before its socket answered.
  Completer<void>? answersLater;

  void _mustHaveAnswered() {
    final later = answersLater;
    if (later != null && !later.isCompleted) throw StateError('open() has not answered yet');
  }

  @override
  Future<List<Task>> tasks() async => _tasks;

  /// What `Projects` answers. Assembled by the daemon, so a scenario sets it rather than the
  /// interface deriving it.
  List<Project> theProjectsItHas = <Project>[
    Project.from(<String, dynamic>{
      'name': 'checkout',
      'securityClass': 'guarded',
      'file': '/srv/checkout/project.yml',
      'mirror': '/srv/checkout/.porelo/mirror',
      'lastUsed': DateTime.now().toUtc().subtract(const Duration(minutes: 4)).toIso8601String(),
      'prepared': true,
      'preparedState': 'READY',
      'behind': 3,
      'behindMeasured': DateTime.now().toUtc().subtract(const Duration(minutes: 20)).toIso8601String(),
      'behindReason': 'MEASURED',
      'pending': 2,
      'tasks': 2,
      'running': 1,
    }),
    // Listed and not actionable: no task start has recorded a file, or the recorded one moved.
    Project.from(const <String, dynamic>{
      'name': 'unrecorded',
      'securityClass': 'guarded',
      'file': '',
      'mirror': '/srv/unrecorded/.porelo/mirror',
      'lastUsed': '',
      // Nothing has run here, so no image was built and nothing was ever checked.
      'prepared': false,
      'preparedState': 'ABSENT',
      'behindReason': 'NEVER_CHECKED',
      'pending': 1,
      'tasks': 0,
      'running': 0,
    }),
    Project.from(const <String, dynamic>{
      'name': 'billing',
      'securityClass': 'offline',
      'file': '/srv/billing/project.yml',
      'mirror': '',
      // **Prepared and up to date are different questions**, and this is the pair that shows it:
      // an image is there, and it was built before the project file changed under it.
      'prepared': true,
      'preparedState': 'STALE',
      // Reaches nothing, so nothing was tried. Distinct from zero, which would read as up to date.
      'behindReason': 'OFFLINE',
      'pending': 0,
      'tasks': 2,
      'running': 2,
    }),
  ];

  /// How often the projects were listed, and how often by the time the gate was last decided on.
  int projectsListed = 0;
  int projectsListedAtTheGate = -1;

  @override
  Future<List<Project>> projects() async {
    projectsListed++;
    return _projects();
  }

  List<Project> _projects() => <Project>[
    for (final each in theProjectsItHas)
      // As Porelo lists it (measured on 254): default names the repositories added to it.
      if (each.name == defaultProject && each.repositories.isEmpty && inDefault.isNotEmpty)
        Project.from(<String, dynamic>{
          'name': defaultProject,
          'securityClass': each.securityClass,
          'file': each.file,
          'following': null,
          'repositories': <Map<String, dynamic>>[
            for (final repository in inDefault)
              <String, dynamic>{'name': repository.name, 'own': false, 'upstream': repository.upstream},
          ],
        })
      else
        each,
  ];

  @override
  Stream<List<Task>> watch() async* {
    if (withoutWatch) throw const FeatureNotSupported('Watch');
    yield _tasks;
    yield* _changes.stream;
  }

  @override
  Stream<StartEvent> startTask({
    String? task,
    String? project,
    String? agent,
    bool dryRun = false,
    Mode? mode,
    String? prompt,
    String? model,
    int? maxTurns,
    int? minutes,
    String? repository,
    Map<String, String>? credentials,
  }) {
    if (project != null) mustBeAProject(project);
    launched.add(dryRun);
    starts.add((task: task, project: project, agent: agent, mode: mode, prompt: prompt, repository: repository));
    startedWith.add(credentials ?? const <String, String>{});
    launch = StreamController<Object>();
    return launch.stream.map(
      (event) => switch (event) {
        String() => StartLine(event),
        StartEvent() => event,
        _ => throw ArgumentError.value(event, 'launch'),
      },
    );
  }

  /// Every stop asked for, by task.
  final List<String> stops = <String>[];

  /// Keeps the task listed, stopped: a stop keeps the workspace.
  @override
  Future<Stopped> stopTask(String task) async {
    stops.add(task);
    _tasks = <Task>[
      for (final each in _tasks) each.name == task ? _with(each, running: false, startAction: 'RESUME') : each,
    ];
    _changes.add(_tasks);
    return Stopped.from(const <String, dynamic>{'outcome': 'STOPPED', 'helpers': 2, 'surviving': <String>[]});
  }

  /// What the next [removeTask] answers. Set by the scenario, so a refusal can be produced without
  /// contriving a task that genuinely holds commits.
  Removed nextRemove = Removed.from(const <String, dynamic>{
    'outcome': 'REMOVED',
    'work': '',
    'rescuedRef': '',
    'removed': true,
    'discarded': 3,
  });

  /// Every removal asked for, and how it was asked.
  final List<({String task, bool? rescue, bool? force})> removals = <({String task, bool? rescue, bool? force})>[];

  /// Acts on the machine, rather than only answering about it.
  ///
  /// A stand-in that says a task was removed and goes on listing it makes a working interface
  /// look like one where nothing happens. That was found by hand, against the other stand-in,
  /// with every test green — so both of them act now, and a scenario holds this one to it.
  @override
  Future<Removed> removeTask(String task, {bool? rescue, bool? force}) async {
    removals.add((task: task, rescue: rescue, force: force));
    // Held work is said first; a running task that holds nothing is refused as still running.
    final running = _tasks.any((each) => each.name == task && each.running);
    if (running && nextRemove.removed && rescue != true && force != true) {
      return Removed.from(const <String, dynamic>{
        'outcome': 'STILL_RUNNING',
        'work': '',
        'rescuedRef': '',
        'removed': false,
        'discarded': 0,
      });
    }
    if (nextRemove.removed) {
      _tasks = _tasks.where((each) => each.name != task).toList();
      _changes.add(_tasks);
    }
    return nextRemove;
  }

  /// What the next [startAgain] answers.
  StartProgress nextStart = const StartProgress(
    action: StartAction.resume,
    exitCode: 0,
    helpersStarted: 2,
    helpersRecorded: 2,
  );

  /// Every start of a listed task, by the project file and the name within it that were sent.
  final List<({String project, String task, String? repository})> startedAgain =
      <({String project, String task, String? repository})>[];

  /// Acts like [removeTask]: a task started again goes on listed as running, or a screen that
  /// ignored the answer would pass.
  @override
  Future<StartProgress> startAgain({required String project, required String task, String? repository}) async {
    mustBeAProject(project);
    startedAgain.add((project: project, task: task, repository: repository));
    // A start that worked answers RESUME, or, as Porelo 199.1 does for a task a restart took down,
    // no action at all with exit 0.
    if (nextStart.action == StartAction.resume || (nextStart.action == null && (nextStart.exitCode ?? 0) == 0)) {
      _tasks = <Task>[
        for (final each in _tasks) each.task == task ? _with(each, running: true, startAction: 'RUNNING') : each,
      ];
      _changes.add(_tasks);
    }
    return nextStart;
  }

  /// Lists [task] as the machine would once a start has brought it up.
  void bringsUp(Task task) {
    _tasks = <Task>[
      for (final each in _tasks)
        if (each.name != task.name) each,
      task,
    ];
    _changes.add(_tasks);
  }

  /// [task] with its running state, and what Start would do to it, changed.
  static Task _with(Task task, {required bool running, required String startAction}) => Task.from(<String, dynamic>{
    ...wire(task),
    'state': running ? 'Up 1 second' : 'Exited (143) 0 seconds ago',
    'running': running,
    'helpers': running ? 2 : 0,
    'activity': running ? 'WORKING' : 'DEAD',
    'startAction': startAction,
  });

  /// What the next [tailLog] prints into, so the scenario decides when a line arrives.
  late StreamController<List<String>> tailing;

  /// Logs this machine has. What `Logs` answers, and what `Tail` accepts.
  Set<String> theLogsItHas = <String>{'agent.log'};

  /// What each of them holds, for the ones whose names do not say. The daemon's sentence: nothing
  /// at this end composes one, so a log the scenario says nothing about is described by nothing.
  final Map<String, String> whatTheLogsHold = <String, String>{};

  /// Blocked connections, driven by the scenario. Nothing here is on a clock: a question with a
  /// deadline tested against wall time is a flaky test of the one thing that must not be flaky.
  final asking = StreamController<Prompt>.broadcast();

  /// Every answer that was sent, and what it said.
  final List<({String key, bool allow})> decisions = <({String key, bool allow})>[];

  /// Set to refuse the next answer, the way a task that has stopped running does.
  VarlinkException? refuseTheAnswer;

  /// What the next [panic] answers. A scenario sets it to produce a surviving helper, which no
  /// contrived task list can produce on demand.
  Panicked? nextPanic;

  /// Every panic asked for, and whether it was only a preview.
  final List<bool> panics = <bool>[];

  /// Every caption asked for, and what it was.
  final List<({String task, String? label})> labels = <({String task, String? label})>[];

  /// What the next [labelTask] answers. A scenario sets it for a task older than the field.
  Labelled? nextLabel;

  @override
  Future<Labelled> labelTask(String task, {String? label}) async {
    labels.add((task: task, label: label));
    final answer = nextLabel;
    if (answer != null) return answer;
    final caption = label?.trim() ?? '';
    // The caption goes onto the task, so a screen that said it worked and went on showing the old
    // one would be caught here rather than by hand.
    _tasks = <Task>[
      for (final each in _tasks)
        if (each.name == task)
          Task.from(<String, dynamic>{
            'name': each.name,
            'task': each.task,
            'label': caption,
            'project': each.project,
            'securityClass': each.securityClass,
            'state': each.state,
            'running': each.running,
            'helpers': each.helpers,
            'clearance': each.clearance,
            'mode': each.mode.name,
            'prompt': each.prompt,
            'agent': each.agent,
          })
        else
          each,
    ];
    _changes.add(_tasks);
    return Labelled(outcome: caption.isEmpty ? 'CLEARED' : 'LABELLED', label: caption);
  }

  /// Every part of a hand-in that arrived: which task, which file, where it started and how long.
  final List<({String task, String name, int offset, int length})> parts =
      <({String task, String name, int offset, int length})>[];

  /// Set to lose the reply to the next part after keeping it, as a cut connection does.
  bool loseTheNextReply = false;

  /// Set to refuse the next hand-in or take-back with this, before anything is kept.
  VarlinkException? refuseTheHandIn;

  /// Set for a machine older than hand-in, which answers `MethodNotFound`.
  bool noHandIn = false;

  /// Set to keep every part but never place the file, as a machine that never completes it.
  bool neverPlaces = false;

  final Map<String, ({int bytes, String sha256, List<int> got})> _incoming =
      <String, ({int bytes, String sha256, List<int> got})>{};

  final Map<String, List<HandInEvent>> _handInRecord = <String, List<HandInEvent>>{};

  /// What arrived in a task, by file name, for a scenario to compare with what was read here.
  final Map<String, List<int>> arrived = <String, List<int>>{};

  @override
  Future<HandInPart> handIn(
    String task, {
    required String name,
    required int bytes,
    required String sha256,
    required int offset,
    required List<int> part,
  }) async {
    if (noHandIn) throw const FeatureNotSupported('HandIn');
    parts.add((task: task, name: name, offset: offset, length: part.length));
    final refusal = refuseTheHandIn;
    if (refusal != null) {
      refuseTheHandIn = null;
      throw refusal;
    }
    final to = _runningOrRefused(task);
    final limit = to.handInLimit ?? 0;
    if (bytes > limit) {
      throw VarlinkException('org.fuin.porelo.Tasks1.FileTooLarge', {'bytes': bytes, 'limit': limit});
    }
    final key = '$task/$name';
    var coming = _incoming[key];
    if (coming != null && (coming.bytes != bytes || coming.sha256 != sha256)) {
      throw VarlinkException('org.fuin.porelo.Tasks1.HandInInProgress', {
        'name': name,
        'received': coming.got.length,
        'bytes': coming.bytes,
      });
    }
    coming ??= _incoming[key] = (bytes: bytes, sha256: sha256, got: <int>[]);
    if (offset != coming.got.length) {
      throw VarlinkException('org.fuin.porelo.Tasks1.PartOutOfOrder', {'name': name, 'received': coming.got.length});
    }
    coming.got.addAll(part);
    if (loseTheNextReply) {
      loseTheNextReply = false;
      throw const VarlinkDisconnected('the reply never arrived');
    }
    if (coming.got.length < bytes || neverPlaces) return HandInPart(received: coming.got.length);
    _incoming.remove(key);
    final actual = crypto.sha256.convert(coming.got).toString();
    if (coming.got.length != bytes || actual != sha256) {
      throw VarlinkException('org.fuin.porelo.Tasks1.FileDiffers', {'expected': sha256, 'actual': actual});
    }
    final placed = HandedFile(
      name: name,
      bytes: bytes,
      sha256: sha256,
      at: '2026-10-06T10:00:00Z',
      by: 'somebody',
      run: to.run ?? '',
    );
    final before = to.files ?? const <HandedFile>[];
    final replaced = before.any((each) => each.name == name);
    arrived['$task/$name'] = List<int>.of(coming.got);
    _withFiles(task, [
      for (final each in before)
        if (each.name != name) each,
      placed,
    ]);
    (_handInRecord[task] ??= <HandInEvent>[]).add(HandInEvent(event: replaced ? 'replaced' : 'given', file: placed));
    return HandInPart(received: bytes, file: placed);
  }

  @override
  Future<HandedFile> takeBack(String task, String name) async {
    if (noHandIn) throw const FeatureNotSupported('TakeBack');
    final refusal = refuseTheHandIn;
    if (refusal != null) {
      refuseTheHandIn = null;
      throw refusal;
    }
    final from = _runningOrRefused(task);
    final files = from.files ?? const <HandedFile>[];
    final file = files.where((each) => each.name == name).firstOrNull;
    if (file == null) {
      throw VarlinkException('org.fuin.porelo.Tasks1.NoSuchFile', {'task': task, 'name': name});
    }
    _withFiles(task, [
      for (final each in files)
        if (each.name != name) each,
    ]);
    (_handInRecord[task] ??= <HandInEvent>[]).add(HandInEvent(event: 'taken back', file: file));
    return file;
  }

  @override
  Future<List<HandInEvent>> handIns(String task) async {
    if (noHandIn) throw const FeatureNotSupported('HandIns');
    return List<HandInEvent>.of(_handInRecord[task] ?? const <HandInEvent>[]);
  }

  Task _runningOrRefused(String task) {
    final found = _tasks.where((each) => each.name == task).firstOrNull;
    if (found == null) throw VarlinkException('org.fuin.porelo.Tasks1.NoSuchTask', {'task': task});
    if (!found.running) throw VarlinkException('org.fuin.porelo.Tasks1.NotRunning', {'task': task});
    return found;
  }

  /// Puts [files] onto [task], every other field kept, and tells whoever watches.
  void _withFiles(String task, List<HandedFile> files) {
    _tasks = <Task>[
      for (final each in _tasks)
        if (each.name == task) withHandIn(each, files: files) else each,
    ];
    _changes.add(_tasks);
  }

  /// [task] with what hand-in adds to it, every other field kept.
  static Task withHandIn(
    Task task, {
    required List<HandedFile>? files,
    int? limit,
    String? run,
    List<Build>? builds,
    String? buildReader,
    String? buildProblem,
  }) => Task(
    name: task.name,
    label: task.label,
    project: task.project,
    securityClass: task.securityClass,
    state: task.state,
    running: task.running,
    helpers: task.helpers,
    agent: task.agent,
    provider: task.provider,
    mode: task.mode,
    prompt: task.prompt,
    branch: task.branch,
    since: task.since,
    activity: task.activity,
    waitingFor: task.waitingFor,
    clearance: task.clearance,
    waiting: task.waiting,
    task: task.task,
    startAction: task.startAction,
    startDetail: task.startDetail,
    phase: task.phase,
    repository: task.repository,
    credentials: task.credentials,
    grants: task.grants,
    agentEnded: task.agentEnded,
    run: run ?? task.run,
    handInLimit: limit ?? task.handInLimit,
    files: files,
    builds: builds ?? task.builds,
    buildReader: buildReader ?? task.buildReader,
    buildProblem: buildProblem ?? task.buildProblem,
  );

  /// Changes what the machine says about [work]'s builds, every other field kept.
  void followBuilds(String work, {List<Build>? builds, String? reader, String? problem}) => publish(<Task>[
    for (final task in _tasks)
      if (task.name == work)
        withHandIn(task, files: task.files, builds: builds, buildReader: reader, buildProblem: problem)
      else
        task,
  ]);

  /// What `Credentials` answers. A scenario sets it to produce a shut store, which is a state no
  /// contrived list of names can express.
  VaultState theStoreIs = VaultState.from(const <String, dynamic>{
    'vault': '/home/somebody/.local/share/porelo/vault.bin',
    'exists': true,
    'credentials': <Map<String, dynamic>>[
      <String, dynamic>{'name': 'a-provider', 'type': 'api-key', 'characters': 108},
    ],
    'readable': true,
  });

  /// What the next [lock] answers.
  Locked nextLock = const Locked(keyring: true, wasCached: true, holding: 0);

  /// How long `Credentials` takes to answer, so a slow one can be overtaken by a fast one.
  Duration credentialsTake = Duration.zero;

  /// Every question asked of the store, in the order it was asked.
  final List<String> storeAsked = <String>[];

  @override
  Future<VaultState> credentials() async {
    _mustHaveAnswered();
    storeAsked.add('credentials');
    if (credentialsTake > Duration.zero) await Future<void>.delayed(credentialsTake);
    final store = theStoreIs;
    // The connections come beside what the store holds, and are read even with it shut.
    return VaultState(
      vault: store.vault,
      exists: store.exists,
      credentials: store.credentials,
      readable: store.readable,
      connections: theConnections,
    );
  }

  /// What this machine is configured to connect out with.
  List<Connection> theConnections = <Connection>[];

  /// Files that exist on the machine, which a connection kept in a file finds.
  Set<String> filesOnTheMachine = <String>{};

  /// Every connection declared, as it was asked.
  final List<({String kind, String match, String? id, String? user, String? purpose, String? source})> declared =
      <({String kind, String match, String? id, String? user, String? purpose, String? source})>[];

  /// Every address forgotten.
  final List<String> forgottenMatches = <String>[];

  /// Every address a credential check was asked about.
  final List<String> checkedUrls = <String>[];

  /// What the next credential check answers. Ready by default.
  CredentialChecked nextCheck = const CredentialChecked(outcome: 'READY');

  /// Whether a check is answered only when the scenario says so, and the checks waiting.
  bool holdingChecks = false;
  final List<Completer<void>> heldChecks = <Completer<void>>[];

  /// Acts like Porelo: the record is kept, a vault entry needs storing, and the same address and
  /// purpose declared again replaces the first.
  @override
  Future<CredentialDeclared> credentialDeclare({
    required String kind,
    required String match,
    String? id,
    String? user,
    String? purpose,
    String? source,
    String? fromFile,
    bool? dryRun,
  }) async {
    final where = source ?? 'VAULT';
    final name = id ?? (kind == 'SSH_KEY' ? 'git.ssh.example' : 'git.token.example');
    if (dryRun == true && holdingChecks) {
      final held = Completer<void>();
      heldChecks.add(held);
      await held.future;
    }
    if (dryRun == true) {
      dryRuns.add((kind: kind, match: match, id: id, user: user, purpose: purpose, source: source, fromFile: fromFile));
      return _wouldDeclare(kind, match, where, name, user, purpose, fromFile);
    }
    declared.add((kind: kind, match: match, id: id, user: user, purpose: purpose, source: source));
    fromFiles.add(fromFile);
    final connection = Connection(
      id: where == 'AGENT' ? '' : name,
      kind: kind,
      match: match,
      user: user ?? '',
      purpose: purpose ?? 'git',
      source: where,
      protected: where == 'VAULT',
      present: where == 'FILE' && _onTheMachine(name),
    );
    final replaced = theConnections.any((each) => each.match == match && each.purpose == connection.purpose);
    theConnections = <Connection>[
      for (final each in theConnections)
        if (!(each.match == match && each.purpose == connection.purpose)) each,
      connection,
    ];
    return CredentialDeclared(
      connection: connection,
      storeCommand: _storeCommand(kind, where, name, fromFile),
      storeStdin: where == 'VAULT' && kind == 'SSH_KEY' && fromFile == null ? 'the private key file' : '',
      replaced: replaced,
      recorded: true,
    );
  }

  /// What a dry run asked, in order; nothing of it is recorded.
  final dryRuns =
      <({String kind, String match, String? id, String? user, String? purpose, String? source, String? fromFile})>[];

  /// The `fromFile` of each real declaration, in order.
  final fromFiles = <String?>[];

  /// Variables set on the machine, which a connection kept in one finds.
  Set<String> variablesOnTheMachine = <String>{};

  /// Who the forge says a key logs in as, by its path, as a dry run answers it.
  Map<String, String> identities = <String, String>{};

  /// Whether a file is there: one put there by a scenario, or a key the machine lists.
  bool _onTheMachine(String path) =>
      filesOnTheMachine.contains(path) || (keysOnTheMachine ?? const <SshKey>[]).any((each) => each.path == path);

  List<String> _storeCommand(String kind, String where, String name, String? fromFile) => where != 'VAULT'
      ? const <String>[]
      : <String>[
          'porelo',
          'vault',
          'put',
          name,
          if (kind == 'TOKEN') ...<String>['--type', 'token'],
          if (fromFile != null) ...<String>['--from-file', fromFile],
        ];

  /// Answers a dry run as the machine does: the refusals a declaration owes, a value
  /// that is not there, and for a key the forge's greeting — nothing written.
  CredentialDeclared _wouldDeclare(
    String kind,
    String match,
    String where,
    String name,
    String? user,
    String? purpose,
    String? fromFile,
  ) {
    final overHttps = match.startsWith('https://') || match.startsWith('http://');
    final present = switch (where) {
      'FILE' => _onTheMachine(name),
      'ENVIRONMENT' => variablesOnTheMachine.contains(name),
      'AGENT' => true,
      _ => false,
    };
    final connection = Connection(
      id: where == 'AGENT' ? '' : name,
      kind: kind,
      match: match,
      user: user ?? '',
      purpose: purpose ?? 'any',
      source: where,
      protected: where == 'VAULT',
      present: present,
    );
    if (kind == 'SSH_KEY' && overHttps) {
      return CredentialDeclared(
        connection: const Connection(),
        outcome: 'NO_CREDENTIAL',
        detail:
            "'$match' is reached over https, which asks for a token or a username and password "
            'and never for an ssh key. Declare it as token, basic or oauth, or name an ssh address.',
      );
    }
    if (where == 'VAULT' && !theStoreIs.exists) {
      return CredentialDeclared(
        connection: connection,
        storeCommand: _storeCommand(kind, where, name, fromFile),
        outcome: 'NO_VAULT',
        detail: "this account has no vault yet, so there is nowhere to put '$name'",
      );
    }
    if (where == 'VAULT' && !theStoreIs.readable) {
      return CredentialDeclared(
        connection: connection,
        storeCommand: _storeCommand(kind, where, name, fromFile),
        outcome: 'VAULT_LOCKED',
        detail: 'the vault is shut, so nothing can be put in it',
      );
    }
    if (kind != 'SSH_KEY' && !overHttps) {
      return CredentialDeclared(
        connection: const Connection(),
        outcome: 'NO_CREDENTIAL',
        detail:
            "'$match' is reached over ssh, which asks for a key and never for a token or a "
            'password. Declare it as ssh-key, or name an https address.',
      );
    }
    return CredentialDeclared(
      connection: connection,
      storeCommand: _storeCommand(kind, where, name, fromFile),
      outcome: present ? 'READY' : 'MISSING_VALUE',
      identity: where == 'FILE' ? identities[name] ?? '' : '',
      detail: present ? 'it would be used for $match' : 'nothing holds its value yet',
    );
  }

  @override
  Future<CredentialForgotten> credentialForget(String match) async {
    forgottenMatches.add(match);
    final gone = theConnections.where((each) => each.match == match).firstOrNull;
    theConnections = <Connection>[
      for (final each in theConnections)
        if (each.match != match) each,
    ];
    return CredentialForgotten(
      forgotten: gone != null,
      leftBehind: gone == null || gone.source == 'AGENT' ? '' : 'the ${gone.source.toLowerCase()} entry ${gone.id}',
    );
  }

  /// Whether the machine is a Porelo older than the check.
  bool checkIsMissing = false;

  /// A host whose remembered key no longer matches, so a follow is refused as a possible interception.
  String? changedHost;

  /// The keys of each host this machine trusts, by host, as a person confirmed them.
  final trustedHostKeys = <String, List<String>>{};

  /// What each host offers right now; a fingerprint not offered is refused, as the machine does.
  Map<String, List<HostKey>> hostsOffer = <String, List<HostKey>>{};

  @override
  Future<HostKeyTrusted> trustHostKey(String host, String fingerprint) async {
    final offered = (hostsOffer[host] ?? const <HostKey>[]).where((each) => each.fingerprint == fingerprint);
    if (offered.isEmpty) {
      return HostKeyTrusted(detail: '$host offers no key with that fingerprint right now. Nothing was recorded.');
    }
    trustedHostKeys.putIfAbsent(host, () => <String>[]).add(fingerprint);
    return HostKeyTrusted(recorded: true, type: offered.first.type, fingerprint: fingerprint);
  }

  /// The keys the machine's account has; null answers as a Porelo older than the method.
  List<SshKey>? keysOnTheMachine = const <SshKey>[];

  @override
  Future<List<SshKey>> sshKeys() async {
    final keys = keysOnTheMachine;
    if (keys == null) throw const FeatureNotSupported('SshKeys');
    return keys;
  }

  @override
  Future<CredentialChecked> credentialCheck(String url, {String? purpose}) async {
    if (checkIsMissing) throw const FeatureNotSupported('CredentialCheck');
    checkedUrls.add(url);
    return nextCheck;
  }

  @override
  Future<Locked> lock() async {
    storeAsked.add('lock');
    // Shutting really shuts it, so the button beside the stop turns into the one that opens it.
    if (theStoreIs.readable) {
      _whileOpen = theStoreIs;
      theStoreIs = VaultState.from(<String, dynamic>{
        'vault': theStoreIs.vault,
        'exists': true,
        'credentials': <Map<String, dynamic>>[],
        'readable': false,
      });
    }
    return nextLock;
  }

  /// What the store held before it was shut, for a device to open it onto again.
  VaultState? _whileOpen;

  /// What the next [canStart] answers. A scenario sets it to produce a locked vault or a missing
  /// credential, neither of which a contrived agent list can produce.
  Readiness? nextReadiness;

  /// How often whether work can start was asked.
  int canStartAsked = 0;

  /// What the machine says when it fails to answer whether work can start; null while it answers.
  String? canStartFails;

  /// The vault's keyslots, as Porelo's proposal has them: the recovery passphrase, and every device
  /// enrolled here. Behaves like the node — a share it has seen opens its slot, nothing else does —
  /// so a screen that ignored an answer would fail a scenario rather than pass one.
  final List<({Keyslot slot, String share})> keyslotsHeld = <({Keyslot slot, String share})>[
    (
      slot: const Keyslot(
        id: 'slot-0',
        name: 'recovery passphrase',
        storage: KeyslotStorage(''),
        enrolled: '2026-09-01T10:00:00Z',
        lastUsed: '',
        self: false,
        recovery: true,
      ),
      share: '',
    ),
  ];

  /// Every share that was sent here, to check nothing was sent twice or kept.
  final List<String> sharesSent = <String>[];

  /// How long each unlock asked for, null where it asked for no bound.
  final List<int?> unlocksFor = <int?>[];

  /// Set for a Porelo from before keyslots, which does not know the four methods.
  bool keyslotsUnknown = false;

  /// What the next enrollment answers instead of enrolling, as a node with a reason of its own.
  KeyslotOutcome? enrollingAnswers;

  /// Set to lose the connection while an enrollment is on its way.
  bool enrollingLosesTheConnection = false;

  void _b60(String method) {
    if (keyslotsUnknown) throw FeatureNotSupported(method);
  }

  @override
  Future<Enrolled> enrollDevice({required String name, required String share, required KeyslotStorage storage}) async {
    _b60('EnrollDevice');
    sharesSent.add(share);
    if (enrollingLosesTheConnection) throw const VarlinkDisconnected('the forward went away');
    if (enrollingAnswers case final outcome?) {
      return Enrolled(outcome: outcome, slot: null, detail: '');
    }
    if (!storage.recognized) {
      return const Enrolled(outcome: KeyslotOutcome.unknownStorage, slot: null, detail: '');
    }
    final known = keyslotsHeld.where((held) => held.share == share).firstOrNull;
    if (known != null) {
      return Enrolled(outcome: KeyslotOutcome.alreadyEnrolled, slot: known.slot, detail: '');
    }
    final slot = Keyslot(
      id: 'slot-${keyslotsHeld.length}',
      name: name,
      storage: storage,
      enrolled: '2026-09-18T08:00:00Z',
      lastUsed: '',
      self: false,
      recovery: false,
    );
    keyslotsHeld.add((slot: slot, share: share));
    return Enrolled(outcome: KeyslotOutcome.enrolled, slot: slot, detail: '');
  }

  @override
  Future<List<Keyslot>> keyslots() async {
    _b60('Keyslots');
    return <Keyslot>[for (final held in keyslotsHeld) held.slot];
  }

  @override
  Future<Revoked> revokeKeyslot(String id) async {
    _b60('RevokeKeyslot');
    final before = keyslotsHeld.length;
    keyslotsHeld.removeWhere((held) => held.slot.id == id);
    return Revoked(
      outcome: keyslotsHeld.length == before ? KeyslotOutcome.noSuchSlot : KeyslotOutcome.revoked,
      remaining: <Keyslot>[for (final held in keyslotsHeld) held.slot],
      detail: '',
    );
  }

  @override
  Future<UnlockedWithShare> unlockWithShare({required String share, int? minutes}) async {
    _b60('UnlockWithShare');
    sharesSent.add(share);
    unlocksFor.add(minutes);
    final opens = keyslotsHeld.where((held) => held.share.isNotEmpty && held.share == share).firstOrNull;
    if (opens == null) {
      return const UnlockedWithShare(outcome: KeyslotOutcome.shareRejected, until: '', slot: null, detail: '');
    }
    theStoreIs = _whileOpen ?? theStoreIs;
    return UnlockedWithShare(
      outcome: KeyslotOutcome.unlocked,
      until: '2026-09-18T08:30:00Z',
      slot: opens.slot,
      detail: '',
    );
  }

  /// A name this machine refuses, and its words, the way a daemon with a rule of its own would.
  ({String name, String words})? refusedName;

  /// Refuses anything but the name of a project this machine has, as Porelo does since projects are
  /// named rather than pointed at. Loud rather than a refusal a screen could render: a path sent
  /// here is this interface being wrong, never the machine answering.
  void mustBeAProject(String project) {
    if (!theProjectsItHas.any((each) => each.name == project)) {
      throw StateError('"$project" is not the name of a project this machine has');
    }
  }

  /// Every name `CanStart` was asked about, null where none was sent.
  final List<String?> askedAboutNames = <String?>[];

  /// What each repository adds to what the project may reach, by repository name.
  final Map<String, List<EgressHost>> theRepositoryAdds = <String, List<EgressHost>>{};

  /// Every repository `Egress` was asked about, null where none was sent.
  final List<String?> egressAskedIn = <String?>[];

  /// Every repository `SetEgress` was asked to write into, null where none was sent.
  final List<String?> egressChangedIn = <String?>[];

  /// The entry nobody has granted yet, which `CanStart` answers `AUTHORIZATION_NEEDED` for, or null.
  String? grantNeededFor;

  /// How many more times `CanStart` answers that the agent asked for is not installed, naming no
  /// agent, while `Agents` lists it: as `vm` answered once.
  int refusesTheAgent = 0;

  /// Every set of credentials `CanStart` was asked about, empty where none was sent.
  final List<Map<String, String>> askedAboutCredentials = <Map<String, String>>[];

  /// The destinations and providers a credential can be for here, as the machine checks them.
  Set<String> get declaredPlaces => <String>{
    for (final each in destinationsHere)
      if (each.inForce) each.name,
    for (final each in theProvidersItHas.providers) each.name,
  };

  /// Every repository `CanStart` was asked about, null where none was sent.
  final List<String?> askedAboutRepositories = <String?>[];

  @override
  Future<Readiness> canStart({
    String? project,
    String? agent,
    String? task,
    String? repository,
    Map<String, String>? credentials,
  }) async {
    canStartAsked++;
    askedAboutCredentials.add(credentials ?? const <String, String>{});
    final failing = canStartFails;
    if (failing != null) throw VarlinkException('org.fuin.porelo.Tasks1.Failed', <String, dynamic>{'message': failing});
    if (project != null) mustBeAProject(project);
    askedAboutNames.add(task);
    askedAboutRepositories.add(repository);
    if (refusesTheAgent > 0 && agent != null) {
      refusesTheAgent--;
      return Readiness(
        ready: false,
        outcome: StartOutcome('UNKNOWN_AGENT'),
        agent: '',
        provider: '',
        credential: '',
        detail: "No agent named '$agent' is installed. Found: none",
      );
    }
    // As a Porelo with repositories per project answers: a project that names repositories needs one chosen.
    final named = theProjectsItHas.where((each) => each.name == project).firstOrNull?.repositories;
    if (repository == null && named != null && named.isNotEmpty) {
      return Readiness(
        ready: false,
        outcome: StartOutcome.noRepositoryChosen,
        agent: agent ?? '',
        provider: '',
        credential: '',
        detail: 'choose one of: ${named.join(', ')}',
      );
    }
    final ungranted = grantNeededFor;
    if (ungranted != null) {
      return Readiness(
        ready: false,
        outcome: StartOutcome.authorizationNeeded,
        agent: agent ?? '',
        provider: '',
        credential: ungranted,
        detail: 'porelo vault authorize $ungranted',
      );
    }
    // As Porelo answers it: a credential for a destination nobody declared refuses every mode.
    for (final given in (credentials ?? const <String, String>{}).entries) {
      if (!declaredPlaces.contains(given.value)) {
        return Readiness(
          ready: false,
          outcome: StartOutcome.unknownDestination,
          agent: agent ?? '',
          provider: '',
          credential: given.key,
          detail:
              "the run names credential '${given.key}' for '${given.value}', and no destination or "
              'provider of that name is declared here',
        );
      }
    }
    final refused = refusedName;
    if (refused != null && task == refused.name) {
      return Readiness(
        ready: false,
        outcome: StartOutcome.badTaskName,
        agent: agent ?? '',
        provider: '',
        credential: '',
        detail: refused.words,
      );
    }
    return nextReadiness ??
        const Readiness(
          ready: true,
          outcome: StartOutcome.ready,
          agent: 'an-agent',
          provider: 'a-provider',
          credential: 'a-provider',
          detail: '',
        );
  }

  /// Set to lose the machine part way through stopping it.
  bool refusePanic = false;

  /// What backups a project has. Set by the scenario.
  ///
  /// **One that was moved is in here on purpose**: a record is not the bundle, and an absent file
  /// is shown rather than dropped — dropping it would say the backup was never taken.
  List<Backup> theBackupsItHas = <Backup>[
    const Backup(
      taken: '2026-09-08T09:15:00Z',
      bundle: '/srv/checkout/backups/before-sync.bundle',
      refs: 2,
      present: true,
      bytes: 4 * 1024 * 1024,
    ),
    const Backup(
      taken: '2026-09-07T18:02:00Z',
      bundle: '/srv/checkout/backups/moved-away.bundle',
      refs: 5,
      present: false,
      bytes: 0,
    ),
  ];

  @override
  Future<List<Backup>> backups(String project, {String? repository}) async {
    backupsAskedIn.add(repository);
    return theBackupsItHas;
  }

  /// Every repository the backups were asked for, null where none was sent.
  final List<String?> backupsAskedIn = <String?>[];

  /// Every repository a sync was asked for, null where none was sent.
  final List<String?> syncedIn = <String?>[];

  /// Every repository a restore was asked to write into, null where none was sent.
  final List<String?> restoredIn = <String?>[];

  /// What a task holds. Set by the scenario.
  ///
  /// **Readable with two zeros by default**, which is *holds nothing* — a scenario that wants
  /// *nobody could look* says so, because those are the two the screen must not merge.
  HeldWork theWorkItHolds = const HeldWork(readable: true, changedFiles: 0, unpushedCommits: 0);

  /// Whether the next ask is for a name that is no task at all.
  bool workHeldIsNoSuchTask = false;

  /// Every task asked about.
  final List<String> held = <String>[];

  @override
  Future<HeldWork> workHeld(String task) async {
    held.add(task);
    // A wrong name is a refusal, never an unreadable answer: collapsing them would make a
    // client's mistake arrive as a legitimate reading.
    if (workHeldIsNoSuchTask) {
      throw const VarlinkException('org.fuin.porelo.Tasks1.NoSuchTask');
    }
    return theWorkItHolds;
  }

  /// What the next sync answers. Set by the scenario.
  Synced theSyncAnswers = const Synced(outcome: 'MEASURED', behind: 3, measured: true, reason: 'MEASURED', detail: '');

  /// Every project a sync was asked for.
  final List<String> syncs = <String>[];

  @override
  Future<Synced> syncUpstream(String project, {String? repository}) async {
    syncs.add(project);
    syncedIn.add(repository);
    return theSyncAnswers;
  }

  /// Every task a refresh from its source was asked for.
  final List<String> taskRefreshes = <String>[];

  /// What the next refresh of a task answers. Set by the scenario.
  TaskRefreshed taskRefreshAnswers = const TaskRefreshed(outcome: 'UNCHANGED');

  @override
  Future<TaskRefreshed> refreshTask(String task) async {
    taskRefreshes.add(task);
    return taskRefreshAnswers;
  }

  /// Every project a refresh was asked for, null for all of them.
  final List<String?> refreshes = <String?>[];

  /// Held open by a scenario so a refresh is seen under way; completed when the machine answers.
  Completer<void>? refreshHeld;

  /// What the next refresh finds instead of the commit in force, by outcome. Set by the scenario.
  String? nextRefreshFinds;

  /// Projects this account no longer follows, so a refresh of one is refused.
  final Set<String> noLongerFollowed = <String>{};

  /// Acts like Porelo: fetches now and answers the records as they are afterwards.
  @override
  Future<List<Followed>> refreshProjects({String? project}) async {
    refreshes.add(project);
    if (project != null && noLongerFollowed.contains(project)) {
      throw VarlinkException('org.fuin.porelo.Tasks1.NoSuchProject', {'project': project});
    }
    await refreshHeld?.future;
    return <Followed>[
      for (final each in theProjectsItHas)
        if (each.following case final followed? when project == null || each.name == project)
          Followed(
            name: each.name,
            url: followed.url,
            commit: 'c0ffee1d2e3f',
            outcome: nextRefreshFinds ?? 'UNCHANGED',
            needsAPerson: nextRefreshFinds != null,
          ),
    ];
  }

  /// Refs a restore would destroy, or empty when it would destroy none. Set by the scenario.
  List<String> theRestoreWouldDestroy = const <String>[];

  /// Every restore asked for.
  final List<({String bundle, bool preview, bool force})> restores = <({String bundle, bool preview, bool force})>[];

  @override
  Future<Restored> restoreBackup(String project, String bundle, {bool? dryRun, bool? force, String? repository}) async {
    restoredIn.add(repository);
    restores.add((bundle: bundle, preview: dryRun == true, force: force == true));
    final refused = theRestoreWouldDestroy.isNotEmpty && force != true;
    return Restored(
      outcome: dryRun == true
          ? 'PREVIEWED'
          : refused
          ? 'HOLDS_WORK'
          : 'RESTORED',
      mirror: '/srv/$project/.porelo/mirror',
      // Filled under force too: it is what force destroyed, and somebody who forced needs it
      // afterwards rather than only in the warning they clicked past.
      unreviewed: theRestoreWouldDestroy,
      detail: '',
    );
  }

  /// Whether the next deletion finds the file there. Set by the scenario.
  bool theBundleIsThere = true;

  /// Every backup deletion asked for.
  final List<({String bundle, bool preview})> backupDeletions = <({String bundle, bool preview})>[];

  @override
  Future<BackupDeleted> deleteBackup(String project, String bundle, {bool? dryRun}) async {
    backupDeletions.add((bundle: bundle, preview: dryRun == true));
    final known = theBackupsItHas.where((each) => each.bundle == bundle);
    if (known.isEmpty) {
      return const BackupDeleted(
        outcome: 'NO_SUCH_BACKUP',
        fileRemoved: false,
        refs: 0,
        detail: 'no record names that path',
      );
    }
    return BackupDeleted(
      outcome: dryRun == true ? 'PREVIEWED' : 'DELETED',
      fileRemoved: theBundleIsThere,
      refs: known.first.refs,
      detail: '',
    );
  }

  /// What the next creation answers. Set by the scenario.
  ///
  /// **The rendered file is filled even on a refusal**, because seeing what was rejected is most
  /// of understanding why.
  String theCreationAnswers = 'CREATED';

  /// What the machine says is wrong with the answers. Set by the scenario.
  List<Problem> theCreationProblems = const <Problem>[];

  /// Set for a Porelo too old to choose where a project file goes, which a current daemon
  /// does.
  bool choosesNoPlace = false;

  /// Every creation asked for.
  final List<({String file, String name, String securityClass, bool preview})> creations =
      <({String file, String name, String securityClass, bool preview})>[];

  /// What a build prints before it ends. Set by the scenario.
  List<String> theBuildPrints = <String>[
    'STEP 1/6: FROM ubuntu:24.04',
    'STEP 4/6: RUN apt-get install -y git',
    'COMMIT porelo/checkout:latest',
  ];

  /// How the next build ends.
  String theBuildEndsWith = 'PREPARED';

  /// Every build asked for: the project, the depth, and whether it was a preview.
  final List<({String project, String? rebuild, bool preview})> builds =
      <({String project, String? rebuild, bool preview})>[];

  @override
  Stream<PrepareProgress> prepare(String project, {String? agent, String? rebuild, bool? dryRun}) async* {
    mustBeAProject(project);
    builds.add((project: project, rebuild: rebuild, preview: dryRun == true));
    for (final line in theBuildPrints) {
      yield PrepareProgress(line: line);
    }
    yield PrepareProgress(
      outcome: theBuildEndsWith,
      image: theBuildEndsWith == 'PREPARED' ? 'porelo/checkout:latest' : '',
      // Read back rather than echoed: a depth the daemon did not recognize has to be visible.
      rebuild: rebuild ?? 'CACHED',
      detail: theBuildEndsWith == 'FAILED' ? 'STEP 4/6: RUN apt-get install -y git returned 100' : '',
    );
  }

  /// What the machine answers about itself. Set by the scenario.
  ///
  /// **Ready with nothing wrong by default**, because that is the ordinary machine — a scenario
  /// that wants a broken one says which probe broke.
  Health theHealthItReports = const Health(
    probes: <Probe>[
      Probe(name: 'podman', state: 'OK', detail: '5.2.1', action: ''),
      Probe(name: 'nft', state: 'OK', detail: 'v1.0.9', action: ''),
    ],
    ready: true,
  );

  /// Every time the machine was asked whether it can run anything.
  int healthAsked = 0;

  /// Set for a daemon older than `Doctor`.
  bool doctorIsUnsupported = false;

  @override
  Future<Health> doctor() async {
    healthAsked++;
    if (doctorIsUnsupported) {
      throw const FeatureNotSupported('Doctor');
    }
    return theHealthItReports;
  }

  /// What providers the machine has. Set by the scenario.
  Providers theProvidersItHas = const Providers(
    providers: <Provider>[
      Provider(
        name: 'a-provider',
        label: 'A Provider',
        upstream: 'api.example.test',
        dialects: <String>['api-key'],
        authenticated: true,
        credentialType: 'api-key',
        credentialName: 'a-provider',
        storeCommand: 'porelo vault put a-provider',
      ),
      // Not authenticated, and stored under the *agent's* name rather than its own — the fallback
      // key a client could never have worked out.
      Provider(
        name: 'other-provider',
        label: 'Another Provider',
        upstream: 'api.other.test',
        dialects: <String>['api-key', 'oauth'],
        authenticated: false,
        credentialType: '',
        credentialName: 'an-agent',
        storeCommand: 'porelo vault put an-agent --type oauth',
      ),
    ],
    readable: true,
  );

  @override
  Future<Providers> providers() async {
    if (providersRefused) throw const VarlinkException('org.fuin.porelo.Tasks1.Failed');
    return theProvidersItHas;
  }

  /// Whether `Providers` is refused. Set by the scenario.
  bool providersRefused = false;

  /// What the next import answers. Set by the scenario.
  Imported theImportAnswers = const Imported(
    outcome: 'IMPORTED',
    name: 'an-agent',
    type: 'api-key',
    length: 51,
    source: '/home/somebody/.config/an-agent/credentials.json',
    detail: '',
  );

  /// Which agents were asked to be imported.
  final List<String?> imports = <String?>[];

  @override
  Future<Imported> importCredential({String? agent, String? configDirectory}) async {
    imports.add(agent);
    return theImportAnswers;
  }

  /// Which node this backend is. Set by the scenario; empty means a daemon that cannot say.
  ///
  /// **Two different ones by default**, because that is the ordinary case — one machine per node.
  /// A scenario that wants the same node says so, and one that wants a daemon too old to answer
  /// clears it.
  String nodeId = 'node-a';

  @override
  Future<String> node() async => nodeId;

  /// What the next deletion answers. Set by the scenario.
  DeleteOutcome deletionAnswers = DeleteOutcome.deleted;

  /// Every deletion asked for: the project, and whether it was a preview and whether it was
  /// forced. **Read off the socket** — a screen that shows a preview while having removed a
  /// project is exactly the failure this guards.
  final List<({String project, bool preview, bool force})> deletions = <({String project, bool preview, bool force})>[];

  /// What the next [follow] answers, or null for a project taken at once.
  Followed? nextFollow;

  /// Every follow asked for, and how its commits were to be checked.
  final List<({String name, String url, String? signedBy, List<String>? signers, bool unverified, bool acceptRewrite})>
  follows =
      <({String name, String url, String? signedBy, List<String>? signers, bool unverified, bool acceptRewrite})>[];

  /// Acts like Porelo: a follow that is taken makes the project, listed with its follow state.
  @override
  Future<Followed> follow(
    String name,
    String url, {
    String? signedBy,
    List<String>? signers,
    bool? unverified,
    bool? acceptRewrite,
  }) async {
    follows.add((
      name: name,
      url: url,
      signedBy: signedBy,
      signers: signers,
      unverified: unverified == true,
      acceptRewrite: acceptRewrite == true,
    ));
    final unmet = hostsOffer.keys.where((host) => url.contains(host) && !trustedHostKeys.containsKey(host));
    // A host never met is refused until a person trusts one of its keys, as the machine does.
    final answer = unmet.isNotEmpty
        ? Followed(
            name: name,
            url: url,
            outcome: changedHost == unmet.first ? 'HOST_KEY_CHANGED' : 'UNKNOWN_HOST_KEY',
            host: unmet.first,
            hostKeys: hostsOffer[unmet.first]!,
            needsAPerson: true,
          )
        : acceptRewrite == true || nextFollow == null
        ? Followed(
            name: name,
            url: url,
            commit: 'c0ffee1d2e3f',
            outcome: 'APPLIED',
            // Pinned to the key it was given, as the machine answers it: by fingerprint.
            signer: signedBy == null ? '' : pinsInstead ?? 'SHA256:person',
            // Several keys are all pinned, each by its fingerprint, in the order given.
            pinned: <String>[for (final each in signers ?? const <String>[]) 'SHA256:${each.split(' ').last}'],
          )
        : nextFollow!;
    if (answer.inForce && !theProjectsItHas.any((each) => each.name == name)) {
      theProjectsItHas = <Project>[
        ...theProjectsItHas,
        Project(
          name: name,
          securityClass: 'guarded',
          file: '/srv/$name/project.yml',
          mirror: '/srv/$name/.porelo/mirror',
          pending: 0,
          tasks: 0,
          running: 0,
          following: answer,
        ),
      ];
    }
    return answer;
  }

  @override
  Future<List<Followed>> following() async => [for (final project in theProjectsItHas) ?project.following];

  /// Set to refuse the next [unfollow] the way the daemon refuses one.
  VarlinkException? refuseToUnfollow;

  /// What `Clear` was asked, in order.
  final List<({String? project, bool dryRun, bool force})> clears = <({String? project, bool dryRun, bool force})>[];

  /// Whether `Clear` stops before removing anything, as with unreviewed work, until forced.
  bool clearRefusesUnforced = false;

  @override
  Future<Cleared> clear({String? project, bool? dryRun, bool? force}) async {
    clears.add((project: project, dryRun: dryRun == true, force: force == true));
    final refused = clearRefusesUnforced && force != true;
    final status = dryRun == true || refused ? 'WOULD_REMOVE' : 'REMOVED';
    final projects = <String>[
      for (final each in theProjectsItHas)
        if (project == null || each.name == project) each.name,
    ];
    final cleared = Cleared(
      refused: refused && dryRun != true,
      items: <ClearedItem>[
        for (final name in projects) ...<ClearedItem>[
          ClearedItem(kind: 'task', what: 'porelo-$name-shell', status: status),
          ClearedItem(kind: 'follow', what: name, status: status),
        ],
        if (project == null)
          ClearedItem(
            kind: 'transport',
            what: 'what the matrix transport and this machine keep for this account',
            status: status,
          ),
        for (final key in deployKeysMade)
          ClearedItem(
            kind: 'deploy key',
            what: key.title,
            status: 'FOR_A_PERSON',
            why: 'removed with your forge sign-in',
          ),
      ],
      keys: List<MachineDeployKey>.of(deployKeysMade),
      signer: theMessageKey.line,
    );
    if (dryRun != true && !cleared.refused) {
      theProjectsItHas = <Project>[
        for (final each in theProjectsItHas)
          if (!projects.contains(each.name)) each,
      ];
    }
    return cleared;
  }

  @override
  Future<Deletion> unfollow(String project, {bool? dryRun, bool? force}) async {
    final refusal = refuseToUnfollow;
    if (refusal != null) throw refusal;
    deletions.add((project: project, preview: dryRun == true, force: force == true));
    final refused = deletionAnswers.canBeForced && force != true;
    return Deletion(
      outcome: dryRun == true
          ? DeleteOutcome.previewed
          : refused
          ? deletionAnswers
          : DeleteOutcome.deleted,
      // Filled for a refusal too, so the cost can be shown beside the reason it was stopped.
      removes: const <Removal>[
        Removal(kind: 'MIRROR', what: '/srv/checkout/.porelo/mirror'),
        Removal(kind: 'IMAGE', what: 'porelo/checkout:latest'),
        Removal(kind: 'TASK', what: 'porelo-checkout-shell'),
        Removal(kind: 'TASK', what: 'porelo-checkout-migrate'),
      ],
      keeps: const <String>['/srv/checkout/project.yml'],
      unreviewed: deletionAnswers == DeleteOutcome.holdsWork ? const <String>['migrate'] : const <String>[],
      running: deletionAnswers == DeleteOutcome.tasksRunning
          ? const <String>['porelo-checkout-shell']
          : const <String>[],
      detail: refused ? 'nothing was removed' : '',
      // What it forgot with the project, as Unfollow answers: its deploy keys and its signer.
      keys: dryRun == true || refused ? const <MachineDeployKey>[] : List<MachineDeployKey>.of(deployKeysMade),
      signer: dryRun == true || refused ? null : theMessageKey,
    );
  }

  @override
  Future<Panicked> panic({bool? dryRun}) async {
    panics.add(dryRun == true);
    if (refusePanic && dryRun != true) {
      throw const VarlinkDisconnected('the tunnel went away');
    }
    return Panicked.from(<String, dynamic>{
      'tasks': <Map<String, dynamic>>[
        for (final task in _tasks)
          if (task.running)
            <String, dynamic>{
              'name': task.name,
              'helpers': task.helpers,
              'surviving': dryRun == true || nextPanic == null ? const <String>[] : nextPanic!.surviving,
            },
      ],
      'surviving': dryRun == true ? const <String>[] : nextPanic?.surviving ?? const <String>[],
      'previewed': dryRun == true,
    });
  }

  @override
  Stream<Prompt> prompts() => asking.stream;

  /// What waits for a person on this machine, as `Held` lists it. Set by the scenario.
  final List<HeldMessage> heldForAPerson = <HeldMessage>[];

  /// What `ReadHeld` answers, by the message's file name.
  final Map<String, HeldMessageRead> readable = <String, HeldMessageRead>{};

  /// Every decision sent with `Release`, in order.
  final List<({String task, String id, bool refuse})> released = <({String task, String id, bool refuse})>[];

  /// Set to be a daemon older than `Held`.
  bool withoutHeld = false;

  /// What happens to messages, as `Talk` streams it.
  final talking = StreamController<TalkEvent>.broadcast();

  @override
  Future<List<HeldMessage>> messagesHeld({String? task}) async {
    if (withoutHeld) throw const FeatureNotSupported('Held');
    return <HeldMessage>[
      for (final each in heldForAPerson)
        if (task == null || each.task == task) each,
    ];
  }

  @override
  Future<HeldMessageRead> readHeld(String task, String id) async =>
      readable[id] ?? HeldMessageRead.from(const <String, dynamic>{'outcome': 'NO_SUCH_MESSAGE'});

  @override
  Future<MessageRelease> release(String task, String id, {bool refuse = false, String? reason}) async {
    released.add((task: task, id: id, refuse: refuse));
    if (reason != null && reason.isNotEmpty) refusalReasons.add(reason);
    final index = heldForAPerson.indexWhere((each) => each.task == task && each.handle == id);
    if (index < 0) {
      return MessageRelease.from(const <String, dynamic>{'outcome': 'NO_SUCH_MESSAGE'});
    }
    final message = heldForAPerson[index];
    final outcome = switch ((message.standing, refuse)) {
      ('held', false) => 'RELEASED',
      ('refused-by-filter', false) => 'DELIVERED_DESPITE_FILTER',
      (_, true) => 'REFUSED',
      _ => 'NOT_DELIVERABLE',
    };
    if (outcome != 'NOT_DELIVERABLE') heldForAPerson.removeAt(index);
    return MessageRelease.from(<String, dynamic>{
      'outcome': outcome,
      'message': message.message,
      'id': message.id,
      // As Porelo 347f122 words it: an incoming one released is checked again, never trusted.
      'detail': switch (outcome) {
        'NOT_DELIVERABLE' => 'the filter could not check it at all',
        'RELEASED' when message.direction == 'in' =>
          'it goes to this task at the next pass, which checks it as it checks every arrival - one held '
              "for its signature is held again unless its sender's key is trusted",
        _ => '',
      },
    });
  }

  @override
  Stream<TalkEvent> talk() => talking.stream;

  /// Who has joined each project's conversation, by project.
  final Map<String, List<MessageMember>> membersOf = <String, List<MessageMember>>{};

  /// Every join asked for, in order.
  final List<({String project, String person, bool reset})> joins = <({String project, String person, bool reset})>[];

  /// Whether the account's own homeserver answers the join, on loopback, or a central one.
  bool joinsOnLoopback = true;

  @override
  Future<MessagesJoined> joinMessages(String project, String person, {bool reset = false}) async {
    joins.add((project: project, person: person, reset: reset));
    final messages = theProjectsItHas.where((each) => each.name == project).firstOrNull?.messages;
    if (messages == null) {
      throw VarlinkException('org.fuin.porelo.Tasks1.NoConversation', <String, dynamic>{'project': project});
    }
    final members = membersOf.putIfAbsent(project, () => <MessageMember>[]);
    final user = '@$person:localhost';
    if (members.any((each) => each.person == person) && !reset) {
      throw VarlinkException('org.fuin.porelo.Tasks1.MemberExists', <String, dynamic>{'person': person, 'user': user});
    }
    if (!members.any((each) => each.person == person)) members.add(MessageMember(person: person, user: user));
    return MessagesJoined(
      transport: 'matrix',
      shown: 'shown on a terminal',
      login: <String, String>{
        'homeserver': joinsOnLoopback ? 'http://127.0.0.1:8008' : 'https://matrix.example.org',
        'user': user,
        'room': '#porelo-$project:localhost',
        'password': 'pw-${joins.length}-once',
        if (joinsOnLoopback) 'loopback': 'true',
        if (joinsOnLoopback) 'port': '8008',
      },
    );
  }

  @override
  Future<List<MessageMember>> messageMembers(String project) async =>
      List<MessageMember>.of(membersOf[project] ?? const <MessageMember>[]);

  /// A fingerprint the machine answers as pinned instead of the one it was given, or null.
  String? pinsInstead;

  /// The deploy keys this machine made, in order, as it answers them.
  final List<MachineDeployKey> deployKeysMade = <MachineDeployKey>[];

  /// Where each work repository's upstream is, by repository, as the project file says.
  final Map<String, String> workUpstreams = <String, String>{};

  Future<MachineDeployKey> deployKey(
    String project, {
    String? repository,
    String? upstream,
    bool? readOnly,
    bool renew = false,
  }) async {
    final own = repository == null;
    final made = MachineDeployKey(
      entry: 'deploy/$project/${repository ?? project}',
      repository: repository ?? project,
      upstream: upstream ?? workUpstreams[repository] ?? '',
      publicKey: 'ssh-ed25519 AAAAmachine-${repository ?? project} porelo@vm',
      fingerprint: 'SHA256:machine-${repository ?? project}',
      title: 'porelo vm $project/${repository ?? project}',
      // Read-only for the project's own repository, write access for a work repository.
      writeAccess: readOnly == null ? !own : !readOnly,
      made: true,
    );
    deployKeysMade.add(made);
    return made;
  }

  /// This machine's message key.
  MachineKey theMessageKey = const MachineKey(
    principal: 'porelo@vm',
    key: 'ssh-ed25519 AAAAmsg',
    line: 'porelo@vm ssh-ed25519 AAAAmsg',
    fingerprint: 'SHA256:msg',
  );

  @override
  Future<MachineKey> messageKey() async => theMessageKey;

  /// The repositories worked on without a project, as `DefaultRepositories` answers them.
  List<DefaultRepository> inDefault = <DefaultRepository>[];

  /// Every address the interface asked to put into default, in order.
  final List<String> addedToDefault = <String>[];

  @override
  Future<List<DefaultRepository>> defaultRepositories() async => List<DefaultRepository>.of(inDefault);

  @override
  Future<DefaultRepository> addToDefault(String upstream, {String? name}) async {
    addedToDefault.add(upstream);
    for (final each in inDefault) {
      if (each.upstream == upstream) return each;
    }
    final added = DefaultRepository(
      name: name ?? upstream.split(RegExp(r'[/:]')).last.replaceAll(RegExp(r'\.git$'), ''),
      upstream: upstream,
      checkout: '',
      claimedBy: '',
    );
    inDefault = <DefaultRepository>[...inDefault, added];
    return added;
  }

  @override
  Future<({bool removed, List<MachineDeployKey> keys})> removeFromDefault(String name) async {
    final before = inDefault.length;
    inDefault = <DefaultRepository>[
      for (final each in inDefault)
        if (each.name != name) each,
    ];
    // The key the machine made for it, as Porelo b08d211 answers it once it is forgotten.
    final forgotten = <MachineDeployKey>[
      for (final each in deployKeysMade)
        if (each.entry == 'deploy/$defaultProject/$name') each,
    ];
    return (removed: inDefault.length != before, keys: forgotten);
  }

  /// What the machine's contract says of binding: a Porelo that can, unless a scenario says it is older.
  bool canBind = true;

  @override
  Future<String> contract() async => canBind
      ? 'method Follow(name: string, url: string, signedBy: ?string, signers: ?[]string) -> ()\n'
            'method Approve(project: string, name: string, branch: string, repository: ?string, commit: ?string) -> ()\n'
      : 'method Follow(name: string, url: string) -> ()\n';

  /// Pending work handed out as a bundle, and what was asked whether it landed.
  final List<String> bundlesTaken = <String>[];
  final List<({String name, String branch})> landedAsked = <({String name, String branch})>[];

  /// Whether the upstream holds what was merged: false says it did not land yet.
  bool itLands = true;

  @override
  Future<({List<int> bundle, int bytes})> pendingBundle(
    String project,
    String name, {
    String? repository,
    String? branch,
  }) async {
    bundlesTaken.add(name);
    return (bundle: <int>[1, 2, 3], bytes: 3);
  }

  @override
  Future<({bool landed, String commit, String detail})> landed(
    String project,
    String name, {
    String? repository,
    required String branch,
  }) async {
    landedAsked.add((name: name, branch: branch));
    return itLands
        ? (landed: true, commit: 'c0ffee9', detail: '')
        : (landed: false, commit: '', detail: "it is not on the upstream's $branch yet: push the merge first");
  }

  @override
  Future<ProjectFileSchema> projectFileSchema() async => const ProjectFileSchema(
    sections: <String, List<String>>{
      '': <String>['credentials', 'egress', 'image', 'limits', 'mail', 'project', 'repositories'],
      'project': <String>['name', 'security_class'],
    },
    open: <String>['credentials', 'repositories', 'mail.transports.<scheme>'],
    keys: <ProjectFileKey>[
      // As Porelo describes them (measured on 244), the ones a first project's form shows.
      ProjectFileKey(
        section: '',
        name: 'project',
        describe: 'Who the project is and how far its agents are trusted.',
        type: 'map',
        values: <String>[],
        defaultValue: '',
        required: true,
      ),
      ProjectFileKey(
        section: '',
        name: 'image',
        describe: 'What a task\'s container is built from.',
        type: 'map',
        values: <String>[],
        defaultValue: '',
        required: true,
      ),
      ProjectFileKey(
        section: 'project',
        name: 'name',
        describe: 'The project\'s name.',
        type: 'string',
        values: <String>[],
        defaultValue: '',
        required: true,
      ),
      ProjectFileKey(
        section: 'project',
        name: 'description',
        describe: 'For people: shown wherever the project is listed.',
        type: 'string',
        values: <String>[],
        defaultValue: '',
        required: false,
      ),
      ProjectFileKey(
        section: 'project',
        name: 'security_class',
        describe: 'How far the agent is trusted.',
        type: 'string',
        values: <String>['offline', 'guarded', 'online'],
        defaultValue: '',
        required: true,
      ),
      ProjectFileKey(
        section: 'image',
        name: 'base_image',
        describe: 'The image a task\'s container is built from.',
        type: 'string',
        values: <String>[],
        defaultValue: '',
        required: true,
      ),
      ProjectFileKey(
        section: 'image',
        name: 'package_sources',
        describe: 'Where apt fetches from.',
        type: 'list',
        values: <String>[],
        defaultValue: '[]',
        required: false,
      ),
    ],
  );

  /// Every draft a project file check was asked about, in order.
  final List<String> checkedDrafts = <String>[];

  @override
  Future<ProjectFileCheck> checkProjectFile(String text) async {
    checkedDrafts.add(text);
    // As Porelo answers it: a misspelt key is refused anywhere; an egress set this machine lacks only here.
    return ProjectFileCheck(
      refused: <String>[
        if (text.contains('secruity_class'))
          "project.yml: 'secruity_class' is not a setting; did you mean 'security_class'?",
      ],
      refusedHere: <String>[
        if (text.contains('internal-mirror')) "egress set 'internal-mirror' is not defined on this machine",
      ],
      warnings: const <String>[],
    );
  }

  /// What the machine streams about authorizations a person has to grant; a scenario adds to it.
  final StreamController<AuthorizationNeeded> needing = StreamController<AuthorizationNeeded>.broadcast();

  /// What is open when the stream is asked for, streamed first, as the machine does.
  final List<AuthorizationNeeded> openAuthorizations = <AuthorizationNeeded>[];

  @override
  Stream<AuthorizationNeeded> authorizations() async* {
    for (final each in openAuthorizations) {
      yield each;
    }
    yield* needing.stream;
  }

  /// The entries a grant was asked for, in order.
  final List<String> authorizing = <String>[];

  /// Where the grant asked for last stands; a scenario adds what the machine answers.
  StreamController<AuthorizeProgress> granting = StreamController<AuthorizeProgress>();

  @override
  Stream<AuthorizeProgress> authorize(String name) {
    authorizing.add(name);
    granting = StreamController<AuthorizeProgress>();
    return granting.stream;
  }

  /// The credentials each start was given, beyond the project's own, in order.
  final List<Map<String, String>> startedWith = <Map<String, String>>[];

  /// Destinations on the machine, the one in force for each name first. Set by the scenario.
  final List<Destination> destinationsHere = <Destination>[];

  /// Every destination written, dry runs included, in order.
  final List<({String name, String upstream, String? authPrefix, bool dryRun})> destinationWrites =
      <({String name, String upstream, String? authPrefix, bool dryRun})>[];

  @override
  Future<List<Destination>> destinations() async => List<Destination>.of(destinationsHere);

  @override
  Future<({Destination destination, bool written})> writeDestination({
    required String name,
    required String upstream,
    String? label,
    String? authHeader,
    String? authPrefix,
    String? authQuery,
    bool dryRun = false,
  }) async {
    destinationWrites.add((name: name, upstream: upstream, authPrefix: authPrefix, dryRun: dryRun));
    // As the machine refuses it: a destination is reached over https only.
    if (!upstream.startsWith('https://')) {
      throw VarlinkException('org.fuin.porelo.Tasks1.DestinationRefused', <String, dynamic>{
        'message': "Destination '$name' must be reached over https, not '$upstream'",
      });
    }
    final written = Destination(
      name: name,
      label: label ?? name,
      upstream: upstream,
      authHeader: authHeader ?? 'Authorization',
      authPrefix: authPrefix ?? '',
      authQuery: authQuery ?? '',
      file: '/home/you/.local/share/porelo/destinations/$name.yaml',
      packaged: false,
      inForce: true,
    );
    if (!dryRun) {
      destinationsHere
        ..removeWhere((each) => each.name == name && !each.packaged)
        ..insert(0, written);
      for (var i = 0; i < destinationsHere.length; i++) {
        final each = destinationsHere[i];
        if (each.name == name && each.packaged) {
          destinationsHere[i] = Destination(
            name: each.name,
            label: each.label,
            upstream: each.upstream,
            authHeader: each.authHeader,
            authPrefix: each.authPrefix,
            authQuery: each.authQuery,
            file: each.file,
            packaged: true,
            inForce: false,
          );
        }
      }
    }
    return (destination: written, written: !dryRun);
  }

  @override
  Future<({bool removed, String file})> removeDestination(String name) async {
    final own = destinationsHere.where((each) => each.name == name && !each.packaged).firstOrNull;
    if (own == null) return (removed: false, file: '');
    destinationsHere.remove(own);
    // The package's own comes back into force once nothing of the person's is in its place.
    for (var i = 0; i < destinationsHere.length; i++) {
      final each = destinationsHere[i];
      if (each.name == name && each.packaged) {
        destinationsHere[i] = Destination(
          name: each.name,
          label: each.label,
          upstream: each.upstream,
          authHeader: each.authHeader,
          authPrefix: each.authPrefix,
          authQuery: each.authQuery,
          file: each.file,
          packaged: true,
          inForce: true,
        );
      }
    }
    return (removed: true, file: own.file);
  }

  /// Whom each task may address, by task. Set by the scenario.
  final Map<String, List<TalkPeer>> peersOf = <String, List<TalkPeer>>{};

  /// Every `Moderate` sent, in order, with the project it named.
  final List<({String task, String project, String name, bool? held, String? mode})> moderated =
      <({String task, String project, String name, bool? held, String? mode})>[];

  /// Every `Say`, in order.
  final List<({String task, String peer, String text, String kind})> saidByAPerson =
      <({String task, String peer, String text, String kind})>[];

  @override
  Future<List<TalkPeer>> peers(String task, String project) async =>
      List<TalkPeer>.of(peersOf[task] ?? const <TalkPeer>[]);

  @override
  Future<TalkPeer> moderate(String task, String project, String name, {bool? held, String? mode}) async {
    moderated.add((task: task, project: project, name: name, held: held, mode: mode));
    final peers = peersOf[task] ?? <TalkPeer>[];
    final at = peers.indexWhere((each) => each.name == name);
    final before = peers[at];
    final after = TalkPeer(
      name: before.name,
      address: before.address,
      trust: before.trust,
      perDay: before.perDay,
      mode: mode ?? before.mode,
      held: held ?? before.held,
    );
    peers[at] = after;
    return after;
  }

  @override
  Future<Said> say(String task, String peer, String text, {String kind = 'question'}) async {
    saidByAPerson.add((task: task, peer: peer, text: text, kind: kind));
    return const Said(message: 'said-1.json', outcome: 'WRITTEN');
  }

  @override
  Future<void> decide(Prompt prompt, {required bool allow}) async {
    final refusal = refuseTheAnswer;
    if (refusal != null) throw refusal;
    decisions.add((key: prompt.key, allow: allow));
  }

  /// What is waiting at the gate. Set by the scenario.
  GateState theGate = GateState.from(const <String, dynamic>{
    'mirror': '/srv/checkout/.porelo/mirror',
    'mode': 'gatekeeping',
    'seededFrom': '',
    'pending': <Map<String, dynamic>>[
      <String, dynamic>{
        // The ref *under* `refs/porelo/incoming/`, which is what the contract answers and what
        // `Review`, `Approve` and `Reject` take. It was once the whole ref here —
        // a fixture describing something the daemon cannot produce.
        'name': 'migrate',
        'commit': '9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d',
        'subject': 'Round to the nearest penny, not away from zero',
        'waiting': '4 minutes',
        'at': '2026-09-07T14:12:00Z',
        'fetch':
            'git fetch ssh://porelo@build-01/srv/checkout/.porelo/mirror '
            'refs/porelo/incoming/migrate:refs/remotes/porelo/migrate',
      },
    ],
  });

  /// What `Review` answers.
  String theDiff = '''
diff --git a/lib/money.dart b/lib/money.dart
--- a/lib/money.dart
+++ b/lib/money.dart
@@ -1,3 +1,3 @@
 class Money {
-  int get pennies => (value * 100).ceil();
+  int get pennies => (value * 100).round();
 }
''';

  /// How `Review` ranks the push's files, in the order to show them. Empty is a Porelo older than
  /// the ranked review.
  List<ReviewFile> theRanking = const <ReviewFile>[];

  /// What the task that pushed was asked, as `Review` answers it: null where the machine does not
  /// say, empty where the task was started without an instruction.
  String? theInstruction;

  /// What was approved, onto which branch, and from which repository — null where none was named.
  /// The commit each forward named as reviewed, in order; null where it named none.
  final List<String?> approvedCommits = <String?>[];

  final List<({String name, String branch, String? repository})> approvals =
      <({String name, String branch, String? repository})>[];

  /// What each repository's gate holds, where the project names repositories. One that is not here
  /// answers [theGate] for the project's own and nothing for any other.
  final Map<String, GateState> theGatesIn = <String, GateState>{};

  /// Repositories whose gate refuses to be read.
  final Map<String, VarlinkException> refuseTheGateIn = <String, VarlinkException>{};

  /// Every repository the gate was asked about, null where none was sent.
  final List<String?> gateAskedIn = <String?>[];

  /// Every repository `Review` was asked about, null where none was sent.
  final List<String?> reviewedIn = <String?>[];

  /// What was rejected.
  final List<String> rejections = <String>[];

  /// Set to refuse the next gate call the way the daemon refuses one.
  VarlinkException? refuseTheGate;

  /// What `Egress` answers, in the order the sources granted them.
  List<EgressHost> theHostsItMayReach = <EgressHost>[
    EgressHost.from(const <String, dynamic>{'host': 'api.anthropic.com', 'origin': 'agent an-agent'}),
    EgressHost.from(const <String, dynamic>{'host': 'github.com', 'origin': 'upstream'}),
    EgressHost.from(const <String, dynamic>{'host': 'pub.dev', 'origin': 'set dart-packages'}),
  ];

  /// What an agent asks for and is deliberately not given.
  List<String> theHostsItIsRefused = <String>['telemetry.example.test'];

  /// The sets installed on this machine.
  List<EgressSet> theSetsItHas = <EgressSet>[
    EgressSet.from(const <String, dynamic>{
      'name': 'dart-packages',
      'label': 'Dart packages',
      'domains': <String>['pub.dev', 'storage.googleapis.com'],
    }),
    EgressSet.from(const <String, dynamic>{
      'name': 'containers',
      'label': 'Container registries',
      'domains': <String>['registry.fedoraproject.org', 'quay.io', 'docker.io'],
    }),
  ];

  /// What the next change answers. The scenario sets it, including every refusal.
  EgressChange? nextChange;

  /// Every change asked for, and whether it was only a preview.
  final List<({List<String> addSets, bool preview})> changes = <({List<String> addSets, bool preview})>[];

  @override
  Future<(List<EgressHost>, List<String>)> egressOf(String projectFile, {String? repository}) async {
    mustBeAProject(projectFile);
    egressAskedIn.add(repository);
    final adds = theRepositoryAdds[repository];
    if (adds != null) {
      return (<EgressHost>[...theHostsItMayReach, ...adds], theHostsItIsRefused);
    }
    return (theHostsItMayReach, theHostsItIsRefused);
  }

  @override
  Future<(List<EgressSet>, List<String>)> egressSets() async =>
      (theSetsItHas, <String>['/etc/porelo/egress.d', '/usr/share/porelo/egress.d']);

  @override
  Future<EgressChange> changeEgress(
    String projectFile, {
    List<String>? addSets,
    List<String>? removeSets,
    List<String>? addDomains,
    List<String>? removeDomains,
    bool? dryRun,
    String? repository,
  }) async {
    mustBeAProject(projectFile);
    egressChangedIn.add(repository);
    changes.add((addSets: addSets ?? <String>[], preview: dryRun == true));
    return nextChange ??
        EgressChange.from(<String, dynamic>{
          'outcome': dryRun == true ? 'PREVIEWED' : 'CHANGED',
          'opens': <Map<String, dynamic>>[
            for (final name in addSets ?? <String>[])
              for (final host in theSetsItHas.firstWhere((set) => set.name == name).domains)
                <String, dynamic>{'host': host, 'origin': 'set $name'},
          ],
          'closes': <Map<String, dynamic>>[],
          'cost': '',
          'detail': '',
        });
  }

  /// What the next [widenTask] answers, preview or not. A scenario sets it, including every
  /// refusal, so `NOT_RUNNING` and `NO_PROJECT_FILE` can be produced without contriving a
  /// container.
  Widened? nextWidening;

  /// Every widening asked for, and how it was asked.
  final List<({String task, List<String> domains, Scope scope, bool preview})> widenings =
      <({String task, List<String> domains, Scope scope, bool preview})>[];

  @override
  Future<Widened> widenTask(String task, List<String> domains, {required Scope scope, bool? dryRun}) async {
    widenings.add((task: task, domains: domains, scope: scope, preview: dryRun == true));
    return nextWidening ??
        Widened.from(<String, dynamic>{
          'outcome': dryRun == true ? 'PREVIEWED' : 'WIDENED',
          'opens': domains,
          'persisted': dryRun != true && scope == Scope.runAndProject,
          'detail': '',
        });
  }

  /// What the next [setClearance] answers. Set by the scenario.
  ClearanceSet? nextClearance;

  /// Every enforcement change asked for.
  final List<({String task, String mode, bool preview})> clearances = <({String task, String mode, bool preview})>[];

  @override
  Future<ClearanceSet> setClearance(String task, String mode, {bool? dryRun}) async {
    clearances.add((task: task, mode: mode, preview: dryRun == true));
    final was = _tasks.where((each) => each.name == task).map((each) => each.clearance).firstOrNull ?? '';
    if (nextClearance != null) return nextClearance!;
    return ClearanceSet(
      outcome: dryRun == true
          ? 'PREVIEWED'
          : was == mode
          ? 'UNCHANGED'
          : 'CHANGED',
      was: was,
      // Empty when nothing changed, exactly as the contract says.
      now: dryRun == true || was == mode ? '' : mode,
      detail: '',
    );
  }

  /// What the next [narrowTask] answers, preview or not. Set by the scenario.
  Narrowed? nextNarrowing;

  /// Every narrowing asked for, and how it was asked.
  final List<({String task, List<String> domains, Scope scope, bool preview})> narrowings =
      <({String task, List<String> domains, Scope scope, bool preview})>[];

  @override
  Future<Narrowed> narrowTask(String task, List<String> domains, {required Scope scope, bool? dryRun}) async {
    narrowings.add((task: task, domains: domains, scope: scope, preview: dryRun == true));
    return nextNarrowing ??
        Narrowed.from(<String, dynamic>{
          'outcome': dryRun == true ? 'PREVIEWED' : 'NARROWED',
          'closes': domains,
          // Two addresses per name, which is what a resolved host usually has. A scenario that
          // wants the zero case says so.
          'addresses': domains.length * 2,
          'persisted': dryRun != true && scope == Scope.runAndProject,
          'detail': '',
        });
  }

  @override
  Future<GateState> gateOf(String projectFile, {String? repository}) async {
    mustBeAProject(projectFile);
    gateAskedIn.add(repository);
    final refusal = refuseTheGate ?? refuseTheGateIn[repository];
    if (refusal != null) throw refusal;
    final own = theProjectsItHas.where((each) => each.name == projectFile).firstOrNull?.repositories;
    if (repository == null || own == null || own.isEmpty || repository == own.first) {
      return theGatesIn[repository] ?? theGate;
    }
    return theGatesIn[repository] ??
        GateState.from(const <String, dynamic>{'mode': 'gatekeeping', 'pending': <Object>[]});
  }

  @override
  Future<({String diff, String log, List<ReviewFile> files, String? asked})> reviewOf(
    String projectFile,
    String name, {
    String? against,
    String? repository,
  }) async {
    mustBeAProject(projectFile);
    reviewedIn.add(repository);
    return (
      diff: theDiff,
      log: 'commit 9a3c1f2\n\n    Round to the nearest penny',
      files: theRanking,
      asked: theInstruction,
    );
  }

  @override
  Future<void> approve(String projectFile, String name, String branch, {String? repository, String? commit}) async {
    mustBeAProject(projectFile);
    final refusal = refuseTheGate;
    if (refusal != null) throw refusal;
    approvals.add((name: name, branch: branch, repository: repository));
    approvedCommits.add(commit);
    projectsListedAtTheGate = projectsListed;
    theGate = GateState.from(const <String, dynamic>{
      'mirror': '/srv/checkout/.porelo/mirror',
      'mode': 'gatekeeping',
      'seededFrom': '',
      'pending': <Map<String, dynamic>>[],
    });
  }

  @override
  Future<({bool? told})> reject(String projectFile, String name, {String? repository, String? reason}) async {
    mustBeAProject(projectFile);
    rejections.add(repository == null ? name : '$repository:$name');
    if (reason != null && reason.isNotEmpty) rejectionReasons.add(reason);
    theGate = GateState.from(const <String, dynamic>{
      'mirror': '/srv/checkout/.porelo/mirror',
      'mode': 'gatekeeping',
      'seededFrom': '',
      'pending': <Map<String, dynamic>>[],
    });
    return (told: !pushersTaskGone);
  }

  /// Why a person dropped a push, in their words, as the machine was given them.
  final List<String> rejectionReasons = <String>[];

  /// Whether the task a waiting push came from is gone, so nobody can be told.
  bool pushersTaskGone = false;

  /// Why a person refused a message, in their words.
  final List<String> refusalReasons = <String>[];

  /// What a person wrote straight into a task's inbox.
  final List<({String task, String text})> toldByAPerson = <({String task, String text})>[];

  @override
  Future<String> tell(String task, String text) async {
    if (!_tasks.any((each) => each.name == task)) {
      throw VarlinkException('org.fuin.porelo.Tasks1.NoSuchTask', <String, dynamic>{'task': task});
    }
    toldByAPerson.add((task: task, text: text));
    return '/inbox/told-1.json';
  }

  @override
  Future<List<Log>> logsOf(String task) async => <Log>[
    for (final name in theLogsItHas)
      Log.from(<String, dynamic>{
        'name': name,
        'bytes': 2048,
        'at': '2026-09-07T14:12:00Z',
        if (whatTheLogsHold[name] != null) 'what': whatTheLogsHold[name],
      }),
  ];

  /// What each task's terminal session shows, by task; none where the machine has no `Screen`.
  final Map<String, Screen> screens = <String, Screen>{};

  /// How many times a session's screen was asked for, by task.
  final Map<String, int> screensAsked = <String, int>{};

  @override
  Future<Screen> screen(String task, {required int last, bool escapes = false}) async {
    screensAsked[task] = (screensAsked[task] ?? 0) + 1;
    final shown = screens[task];
    if (shown == null) throw const FeatureNotSupported('Screen');
    return shown;
  }

  /// Every tail asked for, with how much of its end and whether formatted.
  final List<({String task, String log, int? last, bool formatted})> tailsAsked =
      <({String task, String log, int? last, bool formatted})>[];

  /// Each formatted tail by its task: what a tile's console reads, separate from [tailing].
  final Map<String, StreamController<List<String>>> formattedTails = <String, StreamController<List<String>>>{};

  @override
  Stream<List<String>> tailLog(String task, String log, {int? last, bool formatted = false}) {
    tailsAsked.add((task: task, log: log, last: last, formatted: formatted));
    if (formatted) {
      final tail = StreamController<List<String>>.broadcast();
      formattedTails[task] = tail;
      return tail.stream;
    }
    tailing = StreamController<List<String>>();
    if (!theLogsItHas.contains(log)) {
      tailing.addError(const VarlinkException('org.fuin.porelo.Tasks1.NoSuchLog', <String, dynamic>{}));
      tailing.close();
    }
    return tailing.stream;
  }

  /// What the machine has on it right now.
  List<Task> get tasksNow => _tasks;

  /// Changes what is on the machine, as a backend does when something elsewhere moves.
  void publish(List<Task> tasks) {
    _tasks = tasks;
    _changes.add(tasks);
  }

  /// Stops answering, as a tunnel does.
  void lose() => _changes.addError(const VarlinkDisconnected('the tunnel went away'));

  /// Closes the change stream.
  Future<void> stop() async {
    await _changes.close();
    await asking.close();
    await talking.close();
  }
}

/// Records what would have been raised, so the rules can be judged without a notification daemon.
///
/// What is being tested is *when* something is said, what it says and what it stays quiet about.
/// The desktop's own machinery is not the requirement.
class RecordingNotifier implements Notifier {
  /// Everything raised, in order.
  final List<Announcement> raised = <Announcement>[];

  /// What acting on each one would do.
  final Map<String, VoidCallback> opening = <String, VoidCallback>{};

  @override
  String? problem;

  @override
  Future<void> raise(Announcement note, {required VoidCallback onOpened}) async {
    raised.add(note);
    opening[note.id] = onOpened;
  }

  /// Acts on the last one, as somebody clicking it would.
  void act() => opening[raised.last.id]?.call();
}

/// What one scenario's steps share.
class World {
  /// The backend under test.
  static late FakeBackend backend;

  /// What the window answered when it was asked to close, once it has.
  static Future<Object?>? closing;

  /// Where the appearance is remembered. It survives a restart within a scenario, which is what
  /// makes "still dark after a restart" a real check rather than a re-read of a field.
  static late MemorySettingsStore store;

  /// The interface's own preferences.
  static late Settings settings;

  /// Every machine being watched, and which one is being acted on.
  static late Machines machines;

  /// What is on the machine being acted on.
  static FleetModel get fleet => machines.fleet;

  /// Another machine, for the scenarios about reaching several.
  static late FakeBackend elsewhere;

  /// What is open and where the keyboard is.
  static late ShellModel shell;

  /// What this session has run.
  static late Operations operations;

  /// Where what was run is kept, so it survives a restart within a scenario.
  static late MemoryOperationsStore operationsStore;

  /// Every file the window asked the desktop to open.
  static final List<String> filesOpened = <String>[];

  /// What this session is reading.
  static late Logs logs;

  /// What is waiting at the gate.
  static late Gate gate;

  /// What the project being looked at may reach.
  static late Egress egress;

  /// What is being let through to work that is already running.
  static late Widening widening;

  /// What is being started.
  static late StartWork starting;

  /// Every forward the interface asked for, as it asked for it.
  ///
  /// Recorded rather than run. A widget test's clock does not carry process input and output —
  /// the same reason [FleetBackend] exists as a seam — so what the *frame* does is proven here
  /// and what `ssh` does is proven in `test/app/tunnel_test.dart`, against real sockets.
  static final List<List<String>> forwardsAsked = <List<String>>[];

  /// Forwards this interface still owns, by machine name.
  static final Set<String> forwardsHeld = <String>{};

  /// What the next forward does. A scenario sets it to make one fail the way `ssh` fails.
  static String? forwardsFailWith;

  /// Forwards raised for a trial and not yet taken down, by machine name.
  static final Set<String> trialForwards = <String>{};

  /// Every line the interface asked a machine to run, in order. Recorded, never run.
  static final List<List<String>> startsAsked = <List<String>>[];

  /// What a start does. A scenario sets it to make one come back the way a failure comes back.
  static String? startFailsWith;

  /// Every stop line the interface ran on a machine, in order.
  static final List<List<String>> stopsAsked = <List<String>>[];

  /// What a stop answers when it fails; null when it works.
  static String? stopFailsWith;

  /// The uid a machine reports for the account logged in as, or null when it says nothing.
  static int? loginUid;

  /// Whether this computer has a Porelo of its own; it has, unless a scenario says not.
  static bool poreloIsInstalledHere = true;

  /// Every login whose uid the interface asked, by where it is.
  static final List<String> uidsAsked = <String>[];

  /// What agents the machine has.
  static late AgentInventory inventory;

  /// The recurring jobs somebody named.
  static late Templates templates;

  /// Cutting every form of access at once.
  static late EmergencyStop stopping;

  /// What the vault holds.
  static late Vault vault;

  /// Where this device keeps the keys that open a vault.
  static late MemoryDeviceKeyStore keys;

  /// Addresses opened in the browser, in order.
  static final opened = <Uri>[];

  /// Ports a login's reply was forwarded on, and the ones taken down again.
  static final forwards = <int>[];

  /// Why the next forward is refused, or null for raising it.
  static String? forwardRefused;

  /// Whether a held forward answers when it is tried.
  static bool forwardsAnswer = true;
  static final forwardsClosed = <int>[];

  /// What `known_hosts` holds, as the machine dialog sees it.
  static late FakeHostKeys hostKeys;

  /// Where a new machine's key goes, and what logging in to it as root answers.
  static late FakeMachineSetup setup;

  /// Whether a newer build has been installed underneath.
  static late NewerVersion newerVersion;

  /// The shells somebody has open inside running work.
  static late Sessions sessions;

  /// Removing what Porelo built for a project.
  static late ProjectDeletion deleting;

  /// Whether the machine being acted on can run anything.
  static late HostReadiness readiness;

  /// What the machine being acted on can authenticate against.
  static late Authentication authentication;

  /// Following a repository.
  static late ProjectFollowing following;

  /// How a machine connects out.
  static late Connections connections;

  /// The person's forge login, kept in memory, and the forge it reaches.
  static late ForgeConnection forges;
  static late FakeForge forge;

  /// The forges set up on this computer, as the settings would keep them.
  static late MemoryForgeEntries forgeEntries;
  static late MemoryForgeTokens forgeTokens;
  static late FakeWorkspace workspace;

  /// What the desktop's file dialog answers, or null for one put away.
  static String? pickedFile;

  /// What has been backed up of the project being looked at.
  static late Backups backups;

  /// Taking a name back from work that is already running.
  static late Narrowing narrowing;

  /// What the work being looked at holds that never reached the gate.
  static late WorkHeld held;

  /// Every terminal a scenario opened, in the order they were opened.
  ///
  /// **The command is what these hold on to.** A widget test cannot prove that a pty is really a
  /// terminal — `test/app/pty_test.dart` does that against the kernel — so what is proven here is
  /// everything above it: which command was run against which machine, that what comes back
  /// reaches the screen, and what an ending is said to mean.
  static final List<FakeTerminal> terminals = <FakeTerminal>[];

  /// Where somebody was, so a restart can put them back.
  static late WhereYouWere whereYouWere;

  /// What would have been said to somebody not looking at the window.
  static late RecordingNotifier notifier;

  /// The rules about when to say it.
  static late Notifications notifications;

  /// One machine with two projects on it, one of them with work stopped.
  static List<Task> get work => <Task>[
    // Running, unattended, and carrying its prompt: continuing it is refused because it is
    // still going, which is a different refusal from "it was never an unattended run".
    _task('porelo-checkout-shell', 'checkout', mode: 'UNATTENDED', prompt: 'Bring the schema up to date'),
    // A finished unattended run that kept what it was asked to do, which is what continuing
    // it with a new prompt reads back.
    // Its own ref is the one waiting at the gate, which `waiting` says on the task itself.
    // Nothing joins the two: this container's name is not that ref, and never was.
    _task(
      'porelo-checkout-migrate',
      'checkout',
      running: false,
      helpers: 0,
      mode: 'UNATTENDED',
      waiting: 1,
      prompt: 'Fix the rounding in Money.pennies and add a test for it',
    ),
    _task('porelo-billing-shell', 'billing', securityClass: 'offline', helpers: 1),
    // Started with enforcement off: nothing will ever be asked about what it reaches.
    _task('porelo-billing-audit', 'billing', helpers: 0, clearance: 'off'),
  ];

  /// A task as the machine lists it, for a step to put on the machine.
  static Task aTask(String name, String project, {String mode = ''}) => _task(name, project, mode: mode);

  // Built from a wire-shaped map on purpose, so a fixture cannot describe a task the contract
  // could not actually deliver.
  static Task _task(
    String name,
    String project, {
    bool running = true,
    int helpers = 2,
    String securityClass = 'guarded',
    String clearance = 'prompt',
    String mode = '',
    String prompt = '',
    String agent = 'an-agent',
    int waiting = 0,
  }) => Task.from(<String, dynamic>{
    'name': name,
    // The stand-in's own naming rule; the interface never derives this.
    'task': name.replaceFirst('porelo-$project-', ''),
    'project': project,
    'securityClass': securityClass,
    'state': running ? 'Up 4 minutes' : 'Exited (0) 12 minutes ago',
    'running': running,
    'helpers': helpers,
    'clearance': clearance,
    'mode': mode,
    'prompt': prompt,
    'waiting': waiting,
    'agent': agent,
  });

  /// One blocked connection, as the daemon raises it.
  ///
  /// Wire-shaped, and driven by the scenario rather than by a clock: this is the one event with a
  /// deadline, and a flaky test of it is a flaky test of the thing that matters most.
  static Prompt blocked(String destination, {String task = 'porelo-checkout-shell', String? deadline}) {
    final parts = destination.split(':');
    return Prompt.from(<String, dynamic>{
      'task': task,
      'key': 'tcp/$destination',
      'destination': parts.first,
      'protocol': 'tcp',
      'port': int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
      'at': '2026-09-07T15:00:00Z',
      'prefix': 'egress/deny',
      'deadline': ?deadline,
    });
  }

  /// The same question a second time, carrying its answer.
  static Prompt settled(Prompt asked, String verdict) => Prompt.from(<String, dynamic>{
    'task': asked.task,
    'key': asked.key,
    'destination': asked.destination,
    'protocol': asked.protocol,
    'port': asked.port,
    // Two things this field means: the block time on the question, the decision time here.
    'at': '2026-09-07T15:04:00Z',
    // Empty on an answer: nothing decided it a second time.
    'prefix': '',
    'verdict': verdict,
  });

  /// Replaces one task with the same task in a different activity.
  ///
  /// Wire-shaped, so a fixture cannot describe a task the contract could not deliver.
  static void theWorkIs(
    String name, {
    required String activity,
    String waitingFor = '',
    String since = '',
    bool running = true,
    Map<String, dynamic>? agentEnded,
    int waiting = 0,
  }) {
    final was = backend.tasksNow.firstWhere((task) => task.name == name);
    backend.publish(<Task>[
      for (final task in backend.tasksNow)
        if (task.name != name)
          task
        else
          Task.from(<String, dynamic>{
            'name': was.name,
            'task': was.task,
            'project': was.project,
            'securityClass': was.securityClass,
            'state': running ? 'Up 4 minutes' : 'Exited (0) 12 minutes ago',
            'running': running,
            'startAction': running ? 'RUNNING' : 'RESUME',
            'helpers': was.helpers,
            'agent': 'an-agent',
            'mode': 'UNATTENDED',
            'branch': 'refs/porelo/incoming/shell',
            'since': since,
            'activity': activity,
            'waitingFor': waitingFor,
            'repository': was.repository,
            'agentEnded': ?agentEnded,
            'waiting': waiting,
          }),
    ]);
  }

  /// Makes the machine say [action] is what Start would do to [name], and why.
  static void theStartWouldBe(String name, String action, {String detail = ''}) {
    backend.publish(<Task>[
      for (final task in backend.tasksNow)
        if (task.name != name)
          task
        else
          Task.from(<String, dynamic>{...wire(task), 'startAction': action, 'startDetail': detail}),
    ]);
  }

  /// Puts a backend behind the interface, and closes it when the scenario ends.
  static Future<void> startBackend(List<Task> tasks) async {
    backend = FakeBackend(tasks);
    addTearDown(backend.stop);
  }

  /// Builds the interface against that backend and connects it.
  ///
  /// At a desktop size, because that is what this is: the default 800x600 test surface is a
  /// narrow window, and every scenario would have been judging the fallback layout by accident.
  static Future<void> startApp(WidgetTester tester) async {
    // The view rather than the surface, at a pixel ratio of one: the surface is set in *physical*
    // pixels, so a default ratio quietly turns a desktop window into a narrow one and every
    // scenario judges the fallback layout without saying so.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    store = MemorySettingsStore();
    settings = Settings(store);
    shell = ShellModel();
    operationsStore = MemoryOperationsStore(file: File('/home/somebody/.local/state/porelo/operations.json'));
    filesOpened.clear();
    operations = _operationsFrom(operationsStore);
    logs = Logs();
    gate = Gate();
    egress = Egress();
    widening = Widening();
    starting = StartWork();
    inventory = AgentInventory();
    forwardsAsked.clear();
    forwardsHeld.clear();
    forwardsFailWith = null;
    trialForwards.clear();
    startsAsked.clear();
    startFailsWith = null;
    stopsAsked.clear();
    stopFailsWith = null;
    loginUid = null;
    uidsAsked.clear();
    poreloIsInstalledHere = true;
    templates = Templates(settings);
    await templates.load();
    stopping = EmergencyStop();
    vault = Vault(keys: keys = MemoryDeviceKeyStore());
    newerVersion = NewerVersion(what: File('/tmp/porelo-not-a-build'));
    terminals.clear();
    deleting = ProjectDeletion();
    addTearDown(deleting.dispose);
    readiness = HostReadiness();
    addTearDown(readiness.dispose);
    authentication = Authentication();
    addTearDown(authentication.dispose);
    following = ProjectFollowing();
    addTearDown(following.dispose);
    connections = Connections();
    forge = FakeForge();
    forgeTokens = MemoryForgeTokens();
    workspace = FakeWorkspace();
    forgeEntries = MemoryForgeEntries();
    forges = ForgeConnection(
      forgeTokens,
      entries: forgeEntries,
      openTerminal: (executable, arguments, {int columns = 80, int rows = 24}) {
        final terminal = FakeTerminal(<String>[executable, ...arguments]);
        terminals.add(terminal);
        return terminal;
      },
      forgeFor: (token, address) {
        forge.tokensTried.add(token);
        // Each token its own forge, as GitHub(token) is: a dialog that kept the old one is caught.
        return forge.keysOnlyWith == null ? forge : _ForgeWithToken(forge, token);
      },
      workspaceFor: (repository, token) {
        workspace.repository = repository;
        // Each token its own clone, as ProjectWorkspace(repository, token) is: a dialog that kept the
        // old one is caught.
        return workspace.pushesOnlyWith == null ? workspace : _WorkspaceWithToken(workspace, token);
      },
    );
    pickedFile = null;
    opened.clear();
    forwards.clear();
    forwardsClosed.clear();
    forwardRefused = null;
    forwardsAnswer = true;
    raiseLoginForward = (machine, port) async {
      if (forwardRefused case final words?) throw ForwardRefused(words);
      forwards.add(port);
      return _RecordedForward(() => forwardsClosed.add(port));
    };
    HomeserverForwards.answering = (port) async => forwardsAnswer;
    // What a press would have opened in the browser, recorded rather than opened.
    openLink = (address) async => opened.add(address);
    addTearDown(connections.dispose);
    backups = Backups();
    addTearDown(backups.dispose);
    narrowing = Narrowing();
    addTearDown(narrowing.dispose);
    held = WorkHeld();
    addTearDown(held.dispose);
    sessions = Sessions(
      openTerminal: (executable, arguments, {int columns = 80, int rows = 24}) {
        final terminal = FakeTerminal(<String>[executable, ...arguments]);
        terminals.add(terminal);
        return terminal;
      },
    );
    addTearDown(sessions.dispose);
    notifier = RecordingNotifier();
    notifications = Notifications(notifier, settings)
      ..watchOperations(operations, open: (operation) => shell.openOperation(operation.id));
    addTearDown(notifications.dispose);
    await notifications.load();
    elsewhere = FakeBackend(<Task>[_task('porelo-shared-shell', 'shared')])..nodeId = 'node-b';
    addTearDown(elsewhere.stop);

    // One machine to begin with, and a second only when a scenario asks. Reaching several is
    // only the machine scenarios, and every scenario that does not care must not pay for it.
    hostKeys = FakeHostKeys();
    final setupHome = Directory.systemTemp.createTempSync('world-setup-');
    addTearDown(() => setupHome.deleteSync(recursive: true));
    setup = FakeMachineSetup(setupHome);
    machines = Machines(
      settings,
      reach: (machine) => machine.name == 'elsewhere' ? elsewhere : backend,
      tunnels: FakeTunnels(),
      hostKeys: hostKeys,
      setup: setup,
      poreloIsInstalledHere: () => World.poreloIsInstalledHere,
    );
    await machines.load();
    addTearDown(() => machines.dispose());
    // After the machines exist: it is about where somebody is, and nobody is anywhere yet.
    whereYouWere = WhereYouWere(settings, machines, shell);
    addTearDown(whereYouWere.dispose);
    addTearDown(operations.dispose);
    addTearDown(logs.dispose);

    // As the application does it: every machine, including one added later.
    notifications.watchMachines(machines, open: (_) => shell.goTo(Section.attention));

    await tester.pumpWidget(
      PoreloApp(
        machines: machines,
        shell: shell,
        settings: settings,
        operations: operations,
        logs: logs,
        gate: gate,
        notifications: notifications,
        egress: egress,
        widening: widening,
        starting: starting,
        inventory: inventory,
        templates: templates,
        stopping: stopping,
        vault: vault,
        newerVersion: newerVersion,
        sessions: sessions,
        deleting: deleting,
        readiness: readiness,
        authentication: authentication,
        following: following,
        connections: connections,
        forges: forges,
        pickAFile: ({String? initialDirectory, String? title}) async => pickedFile,
        backups: backups,
        narrowing: narrowing,
        held: held,
      ),
    );
    await settle(tester);
  }

  static Operations _operationsFrom(OperationsStore store) => Operations(
    store: store,
    open: (path) async => filesOpened.add(path),
    // Written at once: a timer still pending when a scenario ends fails it.
    saveDelay: Duration.zero,
  );

  /// Closes the window and opens it again, keeping what was stored.
  static Future<void> restartApp(WidgetTester tester) async {
    await operations.flush();
    operations = _operationsFrom(operationsStore);
    await operations.load();
    notifications.watchOperations(operations, open: (operation) => shell.openOperation(operation.id));
    final reopened = Settings(store);
    await reopened.load();
    settings = reopened;
    shell = ShellModel();

    // A real restart builds everything again, so a test that kept the models would be asserting
    // that nothing was lost rather than that anything was restored. Everything that survives
    // survives because it was written down.
    whereYouWere.dispose();
    machines.dispose();
    machines = Machines(
      settings,
      reach: (machine) => machine.name == 'elsewhere' ? elsewhere : backend,
      tunnels: FakeTunnels(),
      hostKeys: hostKeys,
      poreloIsInstalledHere: () => World.poreloIsInstalledHere,
    );
    await machines.load();
    whereYouWere = WhereYouWere(settings, machines, shell);
    await whereYouWere.restore();

    await tester.pumpWidget(const SizedBox.shrink());
    // As the application does it: every machine, including one added later.
    notifications.watchMachines(machines, open: (_) => shell.goTo(Section.attention));

    await tester.pumpWidget(
      PoreloApp(
        machines: machines,
        shell: shell,
        settings: settings,
        operations: operations,
        logs: logs,
        gate: gate,
        notifications: notifications,
        egress: egress,
        widening: widening,
        starting: starting,
        inventory: inventory,
        templates: templates,
        stopping: stopping,
        vault: vault,
        newerVersion: newerVersion,
        sessions: sessions,
        deleting: deleting,
        readiness: readiness,
        authentication: authentication,
        following: following,
        connections: connections,
        forges: forges,
        pickAFile: ({String? initialDirectory, String? title}) async => pickedFile,
        backups: backups,
        narrowing: narrowing,
        held: held,
      ),
    );
    await settle(tester);
  }

  /// Builds the interface again with whatever the scenario has just replaced.
  static Future<void> rebuild(WidgetTester tester) async {
    await tester.pumpWidget(
      PoreloApp(
        machines: machines,
        shell: shell,
        settings: settings,
        operations: operations,
        logs: logs,
        gate: gate,
        notifications: notifications,
        egress: egress,
        widening: widening,
        starting: starting,
        inventory: inventory,
        templates: templates,
        stopping: stopping,
        vault: vault,
        newerVersion: newerVersion,
        sessions: sessions,
        deleting: deleting,
        readiness: readiness,
        authentication: authentication,
        following: following,
        connections: connections,
        forges: forges,
        pickAFile: ({String? initialDirectory, String? title}) async => pickedFile,
        backups: backups,
        narrowing: narrowing,
        held: held,
      ),
    );
    await settle(tester);
  }

  /// Opens the start form's "More options", where a name, more credentials and keeping it as a job
  /// are, unless it is open already.
  static Future<void> openMoreOptions(WidgetTester tester) async {
    if (find.byKey(const Key('start-credentials')).evaluate().isNotEmpty) return;
    await tester.ensureVisible(find.byKey(const Key('start-more')));
    await tester.pump();
    await tester.tap(find.text('More options'));
    await settle(tester);
  }

  /// The drop-down that offers a choice — by the key its entry carries, [id], or by its [words] — or
  /// null when no field on screen offers it.
  static ChoiceField<dynamic>? fieldOffering(WidgetTester tester, {String? id, String? words}) {
    for (final element in find.byWidgetPredicate((widget) => widget is ChoiceField).evaluate()) {
      final field = element.widget as ChoiceField<dynamic>;
      if (field.choices.any((each) => (id != null && each.id == id) || (words != null && each.label == words))) {
        return field;
      }
    }
    return null;
  }

  /// Chooses [words] — an option of whichever drop-down offers it, or else whatever says it.
  static Future<void> chooseWords(WidgetTester tester, String words) async {
    if (fieldOffering(tester, words: words) == null) await _anAdministratorThere(tester);
    final field = fieldOffering(tester, words: words);
    if (field == null) {
      // Scrolled to first, as a person would: a tap below the fold misses without failing.
      await tester.ensureVisible(find.text(words));
      await tester.pump();
      await tester.tap(find.text(words));
      await settle(tester);
      return;
    }
    final choice = field.choices.firstWhere((each) => each.label == words);
    await choose(tester, field.id, choice.id!);
  }

  /// Chooses the entry whose key is [choice] in whichever drop-down on screen offers it.
  static Future<void> pick(WidgetTester tester, String choice) async {
    if (fieldOffering(tester, id: choice) == null) await _anAdministratorThere(tester);
    final field = fieldOffering(tester, id: choice);
    expect(field, isNotNull, reason: 'nothing on screen offers $choice');
    await World.choose(tester, field!.id, choice);
  }

  /// Answers the wizard's first question, where it asks and nothing answered it yet: an administrator,
  /// to whom every way to reach a machine is offered. A scenario about one who is not says so.
  static Future<void> _anAdministratorThere(WidgetTester tester) async {
    final asked = find.byKey(const Key('machine-admin'));
    if (asked.evaluate().isEmpty) return;
    if (find.byKey(const Key('machine-kind-choice')).evaluate().isNotEmpty) return;
    await choose(tester, 'machine-admin', 'machine-admin-yes');
  }

  /// Chooses the entry [choice] in the drop-down [field]: opened, then the entry pressed. The open
  /// list draws each entry twice — the one shown and the one in the menu — so the last is pressed.
  static Future<void> choose(WidgetTester tester, String field, String choice) async {
    await tester.ensureVisible(find.byKey(Key(field)));
    await tester.pump();
    await tester.tap(find.byKey(Key(field)));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byKey(Key(choice)).last, matching: find.byType(Text)));
    await settle(tester);
    // A tap in an open menu that lands on its neighbor chooses that one, quietly.
    final chosen = tester.widget<ChoiceField<Object?>>(
      find.ancestor(of: find.byKey(Key(field)), matching: find.byWidgetPredicate((each) => each is ChoiceField)),
    );
    expect(chosen.choices.where((each) => each.value == chosen.value).map((each) => each.id), [
      choice,
    ], reason: 'choosing $choice in $field');
  }

  /// Puts a message in [task]'s mailbox that waits for a person, readable in full, and answers it.
  static HeldMessage holdAMessage({
    required String task,
    required String peer,
    required String text,
    required String standing,
    required String reason,
    String direction = 'out',
  }) {
    final number = backend.heldForAPerson.length + 1;
    final fields = <String, dynamic>{
      'task': task,
      'standing': standing,
      'message': 'msg-$number.json',
      'id': 'id-$number',
      'role': 'ROLE_AGENT',
      'peer': peer,
      'kind': 'question',
      'at': '2026-09-29T07:0$number:00Z',
      'reason': reason,
      'direction': direction,
    };
    final message = HeldMessage.from(fields);
    backend.heldForAPerson.add(message);
    backend.readable[message.message] = HeldMessageRead.from(<String, dynamic>{
      ...fields,
      'outcome': 'FOUND',
      'text': <String>[text],
    });
    return message;
  }

  /// Taps what [key] names in a dialog, scrolled into view first: a long answer pushes the
  /// buttons below the fold, and a tap there lands on nothing.
  static Future<void> tapInView(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pump();
    await tester.tap(find.byKey(Key(key)));
    await settle(tester);
  }

  /// Goes on to the machine wizard's second page when its first is still showing, so a step that
  /// fills in where a machine is works whichever page a scenario left open.
  static Future<void> onTheWizardsSecondPage(WidgetTester tester) async {
    final next = find.byKey(const Key('wizard-next'));
    if (next.evaluate().isEmpty) return;
    await tester.tap(next);
    await settle(tester);
  }

  /// Scrolls the last pane from its top until [target] is on screen. A pane's list builds only
  /// what is near the view, so a control scrolled away is not there to be found, let alone tapped.
  static Future<void> reach(WidgetTester tester, Finder target) async {
    final list = find.byType(Scrollable).last;
    final position = tester.state<ScrollableState>(list).position;
    position.jumpTo(position.minScrollExtent);
    await tester.pump();
    await tester.scrollUntilVisible(target, 100, scrollable: list);
    // Into the middle: at the very edge it can sit under the status line and a tap lands there.
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await tester.pump();
  }

  /// Chooses [what] (`sync`, `backups`, `opens`, `reach`, `start-in`) from [repository]'s row menu
  /// on the project's page.
  static Future<void> fromARepositorysMenu(WidgetTester tester, String repository, String what) async {
    await tester.tap(find.byKey(Key('repository-menu $repository')));
    await settle(tester);
    await tester.tap(find.byKey(Key('$what-$repository')));
    await settle(tester);
  }

  /// Redraws until things have stopped moving.
  ///
  /// Not [WidgetTester.pumpAndSettle]: an operation that is still running shows a spinner, and an
  /// animation with no end means pumpAndSettle never returns. Two frames, the second long enough
  /// to carry a dialog transition, is all any of this needs.
  static Future<void> settle(WidgetTester tester) async {
    // Three frames, not two: a theme change animates, and the frame that ends the animation is
    // not the frame that draws its result.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// Whatever has been put on the clipboard since [watchTheClipboard].
  static final List<String> copied = <String>[];

  /// Listens for anything copied, which crosses a platform channel rather than staying in Dart.
  static void watchTheClipboard(WidgetTester tester) {
    copied.clear();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map<Object?, Object?>)['text']! as String);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  }

  /// The theme the interface is actually drawn with.
  static ThemeData themeInUse(WidgetTester tester) => Theme.of(tester.element(find.byType(Scaffold).first));
}

/// Forwards, recorded rather than raised.
///
/// The frame is judged on what it asks for, what it says, and what it lets go of. Starting a real
/// `ssh` here would make every scenario a test of somebody's network; the process itself has its
/// own tests against real sockets.
/// A terminal that never starts anything.
///
/// It is the seam [SessionChannel] exists for: what is above it — which command, against which
/// machine, what reaches the screen, and what an ending says — is the requirement, and none of it
/// needs a process.
class FakeTerminal implements SessionChannel {
  /// Constructor taking the command it stands in for.
  FakeTerminal(this.command);

  /// What would have been run.
  final List<String> command;

  /// What was typed into it, in order.
  final List<String> typed = <String>[];

  /// The sizes it was told about, most recent last.
  final List<String> sizes = <String>[];

  /// Whether this side closed it.
  bool closed = false;

  final StreamController<List<int>> _output = StreamController<List<int>>.broadcast();
  final Completer<int> _ended = Completer<int>();

  @override
  Stream<List<int>> get output => _output.stream;

  @override
  Future<int> get ended => _ended.future;

  @override
  void send(String input) => typed.add(input);

  @override
  void resize({required int columns, required int rows}) => sizes.add('${columns}x$rows');

  @override
  Future<void> close() async {
    closed = true;
    if (!_ended.isCompleted) _ended.complete(129);
  }

  /// Makes the far end print something.
  void prints(String words) => _output.add(utf8.encode(words));

  /// Makes the far end go away with [code].
  void endsWith(int code) {
    if (!_ended.isCompleted) _ended.complete(code);
  }
}

/// A forward raised for a trial, which says when it is taken down.
class _TrialTunnel extends Tunnel {
  _TrialTunnel(super.machine);

  @override
  Future<void> drop() async {
    World.trialForwards.remove(machine.name);
    state = TunnelState.idle;
  }
}

/// Host keys as a person's `known_hosts` would have them: every host known, unless a scenario says
/// one is not.
class FakeHostKeys implements HostKeys {
  /// Destinations whose host key is not known yet.
  final Set<String> unknown = <String>{};

  /// What was written to `known_hosts`, by host.
  final List<String> written = <String>[];

  /// Every destination asked about.
  final List<String> asked = <String>[];

  /// Destinations for which another key than the one shown is known.
  final Set<String> changed = <String>{};

  /// The fingerprint every unknown host shows.
  static const fingerprint = '256 SHA256:uNiQuEfInGeRpRiNtOfThEbUiLdMaChInE0123456789 (ED25519)';

  @override
  Future<HostKeyCheck> check(String destination) async {
    asked.add(destination);
    final host = destination.split('@').last;
    if (!unknown.contains(destination)) {
      return HostKeyCheck(destination: destination, host: host, known: true);
    }
    return HostKeyCheck(
      destination: destination,
      host: host,
      known: false,
      changed: changed.contains(destination),
      knownIn: changed.contains(destination) ? const <String>['~/.ssh/known_hosts'] : const <String>[],
      scanned: const <String>['|1|hashed ssh-ed25519 AAAA'],
      fingerprints: const <String>[fingerprint],
    );
  }

  @override
  Future<void> accept(HostKeyCheck check) async {
    written.add(check.host);
    unknown.remove(check.destination);
  }
}

/// Preparing a new machine with the real `ssh-keygen`, into a home of its own, and a root login
/// that does what the scenario says.
class FakeMachineSetup extends MachineSetup {
  FakeMachineSetup(this.home) : super(home: home.path, run: _atOnce);

  /// The real programs, run synchronously: a widget test's clock never lets an asynchronous process
  /// come back, and a synchronous one needs no clock at all.
  static Future<ProcessResult> _atOnce(List<String> command, {String? input}) async =>
      Process.runSync(command.first, command.sublist(1));

  /// The home whose `~/.ssh` the keys go to.
  final Directory home;

  /// What logging in as root answers, or null for a login that works.
  String? rootLoginFails;

  /// Every root login tried: the host, and the key it used.
  final List<({String host, String key})> rootLogins = <({String host, String key})>[];

  @override
  Future<String?> loginAsRoot(String host, String keyFile) async {
    rootLogins.add((host: host, key: keyFile));
    return rootLoginFails;
  }

  /// Every value stored on a machine: the command, and how long the value was — never the value.
  final List<({List<String> command, int length})> stored = <({List<String> command, int length})>[];

  /// What storing answers, or null for a store that worked.
  String? storingFails;

  @override
  Future<String?> storeOnTheMachine(List<String> command, String value) async {
    stored.add((command: command, length: value.length));
    return storingFails;
  }

  /// Every script run as root, in order.
  final List<String> asRootRan = <String>[];

  /// What allowing the key for the work user says when it fails, or null when it works.
  String? allowFails;

  /// How the setup script's `--show` ends, and how running it ends.
  int showEnds = 0;
  int prepareEnds = 0;

  /// What the setup script's `--list --json` prints.
  String lists =
      '{"packages": ['
      '{"name": "porelo-agent-claude", "kind": "agent", "description": "Claude Code", '
      '"installed": false, "version": "1.0.0~snapshot.12"}, '
      '{"name": "porelo-agent-omp", "kind": "agent", "description": "oh-my-pi", '
      '"installed": false, "version": ""}, '
      '{"name": "porelo-message-transport-matrix", "kind": "transport", '
      '"description": "Matrix transport", "installed": true, "version": "1.0.0"}, '
      '{"name": "porelo-matrix-homeserver", "kind": "homeserver", '
      '"description": "A Matrix homeserver on this machine", "installed": true, "version": "1.0.0"}]}';

  /// What the setup script's `--show` prints.
  String shows =
      "The script shown has the SHA-256 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.\n"
      "useradd --create-home agent\napt-get install -y porelo\nloginctl enable-linger agent";

  @override
  Future<ProcessResult> asRoot(String host, String keyFile, String script) async {
    asRootRan.add(script);
    if (script.contains('--list --json')) {
      if (showEnds == 3) {
        return ProcessResult(0, 3, '', 'This is Arch Linux, which this script does not know.');
      }
      return ProcessResult(0, 0, lists, lists.contains('[]') ? 'nothing yet - no package declares it' : '');
    }
    if (script.contains('--show')) {
      return ProcessResult(
        0,
        showEnds,
        showEnds == 3 ? '' : shows,
        showEnds == 3 ? 'This is Arch Linux, which this script does not know.' : '',
      );
    }
    if (script.contains('\nbash /root/porelo-setup.sh --user')) {
      return ProcessResult(0, prepareEnds, 'agents exists\nporelo installed', '');
    }
    if (script.contains('authorized_keys') && allowFails != null) {
      return ProcessResult(0, 1, '', allowFails!);
    }
    return ProcessResult(0, 0, '', '');
  }

  @override
  Future<ProcessResult> asRootLive(
    String host,
    String keyFile,
    String script,
    void Function(String line) onLine,
  ) async {
    final hold = holdRoot;
    if (hold != null) {
      onLine('Reading package lists...');
      await hold.future;
    }
    final result = await asRoot(host, keyFile, script);
    for (final line in '${result.stdout}'.split('\n')) {
      if (line.isNotEmpty) onLine(line);
    }
    return result;
  }

  /// Set to keep a root script running until it is completed.
  Completer<void>? holdRoot;

  /// What `porelo setup` says when it fails, or null when it works.
  String? registeringFails;

  /// What `porelo doctor` answers when it refuses, or null when it passes.
  ProcessResult? doctorRefuses;

  /// Every command run as the work user.
  final List<String> asUserRan = <String>[];

  /// Whether the package porelo-matrix-homeserver is installed, as its unit answers.
  bool homeserverInstalled = true;

  @override
  Future<ProcessResult> asUser(String alias, String command) async {
    asUserRan.add(command);
    return switch (command) {
      'porelo setup' when registeringFails != null => ProcessResult(0, 1, '', registeringFails!),
      'id -u' => ProcessResult(0, 0, '1001\n', ''),
      'porelo doctor' => doctorRefuses ?? ProcessResult(0, 0, 'transports  OK  matrix\nready', ''),
      'systemctl --user show porelo-matrix-homeserver -p LoadState --value' => ProcessResult(
        0,
        0,
        homeserverInstalled ? 'loaded\n' : 'not-found\n',
        '',
      ),
      _ => ProcessResult(0, 0, '', ''),
    };
  }
}

/// [FakeForge] reached with one token: everything is the forge's, and adding a key is asked with
/// this token, not the last one connected.
class _ForgeWithToken implements Forge {
  _ForgeWithToken(this._forge, this._token);

  final FakeForge _forge;
  final String _token;

  @override
  String get name => _forge.name;
  @override
  Future<ForgeAccount> whoAmI() => _forge.whoAmI();
  @override
  Future<List<ForgeRepository>> repositories() => _forge.repositories();
  @override
  Future<bool> hasProjectFile(ForgeRepository repository) => _forge.hasProjectFile(repository);
  @override
  Future<ForgeRepository> repository(String fullName) => _forge.repository(fullName);
  Future<List<ForgeDeployKey>> deployKeys(String repository) => _forge.deployKeys(repository);
  @override
  Future<List<String>> branches(String repository) => _forge.branches(repository);
  @override
  Future<List<String>> hostKeyFingerprints() => _forge.hostKeyFingerprints();
  @override
  Future<List<ForgeSigningKey>> signingKeys(String login) => _forge.signingKeys(login);
  Future<String?> whyNoKeys(String repository) => _forge.whyNoKeys(repository);
  Future<ForgeDeployKey> addDeployKey(
    String repository, {
    required String title,
    required String key,
    required bool readOnly,
  }) => _forge._addDeployKey(repository, title: title, key: key, readOnly: readOnly, token: _token);
  Future<void> removeDeployKey(String repository, int id) => _forge.removeDeployKey(repository, id);
}

/// [FakeWorkspace] reached with one token: everything is the clone's, and a push goes with this token.
class _WorkspaceWithToken implements ProjectWorkspace {
  _WorkspaceWithToken(this._clone, this._token);

  final FakeWorkspace _clone;
  final String _token;

  @override
  String get sshDirectory => _clone.sshDirectory;
  @override
  ForgeRepository get repository => _clone.repository;
  @override
  String get root => _clone.root;
  @override
  String get folder => _clone.folder;
  @override
  String get projectFile => _clone.projectFile;
  @override
  Future<void> open() => _clone.open();
  @override
  Future<String?> read() => _clone.read();
  @override
  Future<void> write(String text) => _clone.write(text);
  @override
  Future<String> diff() => _clone.diff();
  @override
  Future<List<SigningKey>> signingKeys() => _clone.signingKeys();
  @override
  Future<String> takeBundle(List<int> bundle, String name) => _clone.takeBundle(bundle, name);
  @override
  Future<String> mergeAndPush(String name, String message, SigningKey key, {required String login}) =>
      _clone.mergeAndPush(name, message, key, login: login);
  @override
  Future<String?> readFile(String name) => _clone.readFile(name);
  @override
  Future<void> writeFile(String name, String text) => _clone.writeFile(name, text);
  @override
  Future<String> commitAndPush(
    String message,
    SigningKey key, {
    required String login,
    List<String> files = const <String>['project.yml'],
  }) => _clone._commitAndPush(message, key, login: login, files: files, token: _token);
}

class FakeTunnels extends Tunnels {
  final Map<String, Tunnel> _mine = <String, Tunnel>{};

  String _sshConfigFor(String host) {
    final written = World.machines.setup.entryWrittenFor(host)?.keyFile;
    return written == null ? 'identityfile ~/.ssh/id_ed25519\n' : 'identityfile $written\n';
  }

  @override
  Tunnel? of(Machine machine) => _mine[machine.name];

  @override
  bool manages(Machine machine) => _mine.containsKey(machine.name);

  @override
  Future<bool> raiseFor(Machine machine) async {
    // A machine somebody else forwarded is left alone: nothing started, nothing owned.
    if (!machine.needsATunnel) return true;
    final tunnel = _mine.putIfAbsent(machine.name, () => Tunnel(machine));
    World.forwardsAsked.add(tunnel.command);
    World.forwardsHeld.add(machine.name);
    final failing = World.forwardsFailWith;
    if (failing != null) {
      final explained = whySshRefused(failing, machine.host, sshConfig: _sshConfigFor(machine.host));
      tunnel
        ..state = TunnelState.down
        ..problem = explained ?? failing;
      notifyListeners();
      return false;
    }
    tunnel
      ..state = TunnelState.up
      ..problem = null;
    notifyListeners();
    return true;
  }

  @override
  Future<int?> loginUidAt(String host) async {
    World.uidsAsked.add(host);
    return World.loginUid;
  }

  @override
  Future<Started> startPoreloOn(Machine machine) async {
    // A machine with no host behind it is refused before anything is run, by the real thing.
    if (!machine.canBeStartedHere) return super.startPoreloOn(machine);
    World.startsAsked.add(Tunnels.startCommandFor(machine));
    final failing = World.startFailsWith;
    if (failing != null) return Started(went: false, words: failing);
    // The daemon that was missing is there now, so the try that follows finds it.
    World.backend.absent = null;
    return const Started(went: true, words: 'started porelod itself');
  }

  @override
  Future<Started> stopPoreloOn(Machine machine) async {
    if (!machine.needsATunnel) return super.stopPoreloOn(machine);
    World.stopsAsked.add(Tunnels.stopCommandFor(machine));
    final failing = World.stopFailsWith;
    if (failing != null) return Started(went: false, words: failing);
    // Nothing serves on the forward any more, so the try that follows finds nobody there.
    World.backend.absent = const VarlinkDisconnected('Connection refused');
    return const Started(went: true, words: 'stopped by systemd');
  }

  @override
  Future<Tunnel> trial(Machine machine) async {
    final tunnel = _TrialTunnel(machine);
    World.forwardsAsked.add(tunnel.command);
    World.trialForwards.add(machine.name);
    final failing = World.forwardsFailWith;
    tunnel
      ..state = failing == null ? TunnelState.up : TunnelState.down
      ..problem = failing;
    return tunnel;
  }

  @override
  Future<void> raiseAgainIfItDropped(Machine machine) async {
    if (_mine[machine.name]?.state != TunnelState.down) return;
    await raiseFor(machine);
  }

  @override
  Future<void> dropFor(Machine machine) async {
    if (_mine.remove(machine.name) != null) World.forwardsHeld.remove(machine.name);
    notifyListeners();
  }

  @override
  Future<void> dropEverything() async {
    for (final name in _mine.keys) {
      World.forwardsHeld.remove(name);
    }
    _mine.clear();
    notifyListeners();
  }
}

/// [task] as the machine would send it.
Map<String, dynamic> wire(Task task) => <String, dynamic>{
  'name': task.name,
  'task': task.task,
  'label': task.label,
  'project': task.project,
  'securityClass': task.securityClass,
  'state': task.state,
  'running': task.running,
  'helpers': task.helpers,
  'agent': task.agent,
  'mode': task.mode.name,
  'prompt': task.prompt,
  'branch': task.branch,
  'since': task.since,
  'activity': task.activity.name,
  'waitingFor': task.waitingFor,
  'clearance': task.clearance,
  'waiting': task.waiting,
  'startAction': task.startAction.name,
  'startDetail': task.startDetail,
  'phase': task.phase,
  'repository': task.repository,
  'credentials': task.credentials,
  'grants': <String, dynamic>{
    for (final each in task.grants.entries)
      each.key: <String, dynamic>{'grantedBy': each.value.grantedBy, 'grantedAt': each.value.grantedAt},
  },
};

/// A forward that only records being taken down.
class _RecordedForward implements HeldForward {
  _RecordedForward(this._onClose);

  final void Function() _onClose;

  @override
  Future<void> close() async => _onClose();
}

/// A forge that answers as a scenario says, with nothing on the network.
class FakeForge implements Forge {
  /// Every token a forge was made with, in order.
  final List<String> tokensTried = <String>[];

  /// The token the forge accepts; any other is refused as GitHub refuses one.
  String accepts = 'ghp_accepted';

  /// More tokens it accepts: those of a second entry for the same forge, or a token replaced.
  final Set<String> alsoAccepted = <String>{};

  /// Who the accepted token logs in as.
  String login = 'alice';

  /// What the login reaches.
  List<ForgeRepository> repositoriesHere = <ForgeRepository>[];

  /// The repositories with a `project.yml`, by full name.
  final Set<String> projects = <String>{};

  @override
  String get name => 'GitHub';

  /// Set to make the forge answer who the token is only when the scenario completes it.
  Completer<void>? answersLater;

  @override
  Future<ForgeAccount> whoAmI() async {
    final later = answersLater;
    if (later != null) await later.future;
    if (tokensTried.last != accepts && !alsoAccepted.contains(tokensTried.last)) {
      throw const ForgeRefused(
        'GitHub does not accept this token: it is wrong, expired or revoked. (Bad credentials)',
        status: 401,
      );
    }
    return ForgeAccount(login);
  }

  @override
  Future<List<ForgeRepository>> repositories() async => List<ForgeRepository>.of(repositoriesHere);

  @override
  Future<bool> hasProjectFile(ForgeRepository repository) async => projects.contains(repository.fullName);

  @override
  Future<ForgeRepository> repository(String fullName) async => repositoriesHere.firstWhere(
    (each) => each.fullName == fullName,
    orElse: () => throw const ForgeRefused('GitHub has nothing there this token can see.', status: 404),
  );

  /// Deploy keys by repository, as the forge holds them.
  final List<String> keyCalls = <String>[];

  final Map<String, List<ForgeDeployKey>> keysOf = <String, List<ForgeDeployKey>>{};
  int _nextKey = 100;

  /// The host key fingerprints the forge publishes for itself: GitHub's own, as `/meta` lists them.
  List<String> publishedHostKeys = <String>[
    'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU',
    'SHA256:p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM',
    'SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s',
  ];

  @override
  Future<List<String>> hostKeyFingerprints() async => publishedHostKeys;

  /// Each repository's branches, as the forge lists them.
  Map<String, List<String>> branchesOf = <String, List<String>>{};

  @override
  Future<List<String>> branches(String repository) async => branchesOf[repository] ?? const <String>[];

  /// The keys the person signs with, as the forge lists them.
  List<ForgeSigningKey> signing = <ForgeSigningKey>[];

  @override
  Future<List<ForgeSigningKey>> signingKeys(String login) async => signing;

  Future<List<ForgeDeployKey>> deployKeys(String repository) async {
    keyCalls.add('list $repository');
    return List<ForgeDeployKey>.of(keysOf[repository] ?? const <ForgeDeployKey>[]);
  }

  /// The repositories the token may not manage the keys of, though the account may.
  final Set<String> tokenMayNotManageKeysOf = <String>{};

  Future<String?> whyNoKeys(String repository) async {
    keyCalls.add('check $repository');
    return tokenMayNotManageKeysOf.contains(repository) ? 'Resource not accessible by personal access token' : null;
  }

  /// The one token that may add deploy keys, where only one may: the token in use is the last tried.
  String? keysOnlyWith;

  Future<ForgeDeployKey> addDeployKey(
    String repository, {
    required String title,
    required String key,
    required bool readOnly,
  }) async {
    return _addDeployKey(repository, title: title, key: key, readOnly: readOnly, token: tokensTried.lastOrNull);
  }

  Future<ForgeDeployKey> _addDeployKey(
    String repository, {
    required String title,
    required String key,
    required bool readOnly,
    required String? token,
  }) async {
    keyCalls.add('add $repository');
    if (refusesAddingAt.contains(repository)) {
      throw ForgeRefused('GitHub refused a deploy key at $repository: the key is already in use', status: 422);
    }
    if (keysOnlyWith != null && token != keysOnlyWith) {
      throw const ForgeRefused(
        'GitHub refused it: Resource not accessible by personal access token. The token needs '
        '"Administration: Read and write" on the repository.',
        status: 403,
      );
    }
    final made = ForgeDeployKey(id: _nextKey++, title: title, key: key, readOnly: readOnly);
    keysOf.putIfAbsent(repository, () => <ForgeDeployKey>[]).add(made);
    return made;
  }

  Future<void> removeDeployKey(String repository, int id) async {
    keyCalls.add('remove $repository');
    if (refusesRemovingAt.contains(repository)) {
      throw const ForgeRefused('GitHub refused it: Resource not accessible by personal access token', status: 403);
    }
    keysOf[repository]?.removeWhere((each) => each.id == id);
  }

  /// Repositories whose deploy keys the token may not remove.
  final Set<String> refusesRemovingAt = <String>{};

  /// Repositories where adding a deploy key is refused.
  final Set<String> refusesAddingAt = <String>{};
}

/// A working folder that answers as a scenario says, with no git and no agent.
class FakeWorkspace implements ProjectWorkspace {
  @override
  String sshDirectory = '';

  @override
  ForgeRepository repository = const ForgeRepository(
    fullName: '',
    sshUrl: '',
    httpsUrl: '',
    defaultBranch: 'main',
    admin: true,
    push: true,
    private: true,
  );

  /// What the file holds on the forge, or null for none.
  String? onTheForge;

  /// What was written here last.
  String? written;

  /// The keys the agent holds.
  List<SigningKey> agentKeys = <SigningKey>[
    const SigningKey(
      publicKey: 'ssh-ed25519 AAAAperson person@laptop',
      fingerprint: 'SHA256:person',
      comment: 'person@laptop',
    ),
  ];

  /// Every commit pushed: the file, the message and the key it was signed with.
  final List<({String file, String message, String fingerprint})> pushes =
      <({String file, String message, String fingerprint})>[];

  @override
  String get root => '/home/somebody/.local/share/porelo-frontend/projects';

  @override
  String get folder => '$root/${repository.fullName}';

  @override
  String get projectFile => '$folder/project.yml';

  @override
  Future<void> open() async {}

  @override
  Future<String?> read() async => onTheForge;

  @override
  Future<void> write(String text) async => written = text;

  @override
  Future<String> diff() async => '+${(written ?? '').split('\n').first}';

  @override
  Future<List<SigningKey>> signingKeys() async {
    if (agentKeys.isEmpty) {
      throw const WorkspaceRefused('Your ssh agent holds no key. Add one with ssh-add, and it can sign.');
    }
    return agentKeys;
  }

  /// Other files at the repository's root, by name, as they are here.
  final Map<String, String> files = <String, String>{};

  /// Every commit pushed with the files it named.
  final List<({List<String> names, String message, String fingerprint})> commits =
      <({List<String> names, String message, String fingerprint})>[];

  /// Pending work taken in, and merges pushed, by name.
  final List<String> bundlesIn = <String>[];
  final List<({String name, String fingerprint})> merges = <({String name, String fingerprint})>[];

  @override
  Future<String> takeBundle(List<int> bundle, String name) async {
    bundlesIn.add(name);
    return '+  sets: [internal-mirror]';
  }

  @override
  Future<String> mergeAndPush(String name, String message, SigningKey key, {required String login}) async {
    merges.add((name: name, fingerprint: key.fingerprint));
    return 'c0ffee9';
  }

  @override
  Future<String?> readFile(String name) async => files[name];

  @override
  Future<void> writeFile(String name, String text) async => files[name] = text;

  /// The one token a push goes through with, where only one may: refused as GitHub refuses it.
  String? pushesOnlyWith;

  @override
  Future<String> commitAndPush(
    String message,
    SigningKey key, {
    required String login,
    List<String> files = const <String>['project.yml'],
  }) => _commitAndPush(message, key, login: login, files: files, token: null);

  Future<String> _commitAndPush(
    String message,
    SigningKey key, {
    required String login,
    required List<String> files,
    required String? token,
  }) async {
    if (pushesOnlyWith != null && token != pushesOnlyWith) {
      throw const WorkspaceRefused(
        'The push was refused: the token needs "Contents: Read and write" on the '
        'repository. Give it that right at the forge, or use a token that has it.',
      );
    }
    commits.add((names: files, message: message, fingerprint: key.fingerprint));
    if (files.contains('project.yml')) {
      pushes.add((file: written ?? '', message: message, fingerprint: key.fingerprint));
      onTheForge = written;
    }
    return 'c0ffee${commits.length}';
  }
}
