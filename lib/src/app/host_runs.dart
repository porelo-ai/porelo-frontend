import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:porelo_host/porelo_host.dart';

import 'homeserver_publishing.dart';
import 'host_session.dart';
import 'host_vpn.dart';
import 'machines.dart';
import 'settings.dart';

/// The host command and local VPN must both finish before the machine is ready.
enum HostPreparationPhase {
  /// The host command is running, stopped, or refused.
  preparing,

  /// Remote setup completed and the local VPN is awaiting verification.
  vpn,

  /// The machine was added: after a fresh VPN handshake, or with no VPN when host files were supplied manually.
  reachable,
}

/// One project's setup, retained independently of any dialog watching it.
class HostPreparation {
  /// Keeps only the public setup record, its running command and public tunnel settings.
  HostPreparation({
    required this.project,
    required this.session,
    required this.record,
    this.tunnel,
    this.settings,
    this.interrupted = false,
  });

  /// Project identity, never a path.
  final String project;

  /// The command and its immutable arguments, reused for every resume.
  final HostSession session;

  /// The original nonsecret setup answers.
  final HostUpRecord record;

  /// Public halves of the tunnel prepared before the command started.
  final HostTunnel? tunnel;

  /// Persists public completion settings independently of the setup dialog's lifetime.
  final Settings? settings;

  /// The machine's name even before a daemon exists.
  String get name => '$project server';

  /// True only once the machine was added, which needs a verified VPN unless host files were supplied manually.
  bool get ready => phase == HostPreparationPhase.reachable;

  /// Host setup has supplied a validated destination and now needs the local VPN.
  bool get awaitingVpn => phase == HostPreparationPhase.vpn;

  /// The phase confirmed by completed host and VPN checks.
  HostPreparationPhase phase = HostPreparationPhase.preparing;

  /// Prevents concurrent local terminals for the same setup.
  bool vpnOpen = false;

  /// Automatic bring-up is offered once; a refusal keeps an explicit retry.
  bool vpnOffered = false;

  /// Whether the interface closed before setup could finish.
  bool interrupted;

  /// Whether the provider confirmed that the server was given back.
  bool givenBack = false;

  /// Completes once the latest protocol update has reached settings.
  Future<void> get saved => _saved ?? Future.value();
  Future<void>? _saved;
  String? _lastProtocol;
  VoidCallback? _listener;
  bool _saveFailed = false;

  bool _upActive = false;
  Future<void>? _probe;
  Timer? _poll;
  bool _lockFailed = false;

  /// Why recovery must wait for a fresh lock check on restart.
  String? get lockProblem => _lockFailed ? problem : null;

  /// The pending lock check, completed before recovery can start a command.
  Future<void> get checked => _probe ?? Future.value();

  /// Whether setup owns an active attempt, including persistence and machine confirmation.
  bool get running => _upActive || session.state == HostRunState.running || session.state == HostRunState.busy;

  /// A local refusal, such as an unusable completion destination.
  String? problem;

  /// The current attempt, including its confirmed machine addition.
  Future<void> finished = Future.value();

  /// Whether the command has stopped for the person.
  bool get waiting => session.state == HostRunState.waiting;

  /// What `up`'s refusal asks of the person on a call of its own before `up` runs again, as porelo-host names it
  /// in the refusal's first word (`forge-central-token:`, `keys:`, `matrix-token:`); null for any other ending.
  List<String>? get asksOnItsOwn {
    if (running || waiting) return null;
    final fix = session.fix ?? '';
    for (final need in const ['forge-central-token', 'keys', 'matrix-token']) {
      if (fix.startsWith('$need:')) return [need];
    }
    return null;
  }

  /// Whether the setup needs the person before it can go on: a stop, or a refusal that asks on its own call.
  bool get needsYou => waiting || asksOnItsOwn != null;
}

/// Owns host setup just as Operations owns other long actions; views only observe it.
class HostRuns extends ChangeNotifier {
  /// Adds successful runs through the ordinary Machines path.
  HostRuns(
    this.machines, {
    String Function(String)? endpointFor,
    Future<bool> Function()? ping,
    Future<bool> Function()? probeLink,
    this.environment,
    this.homeserver,
  }) : _endpointFor = endpointFor ?? Machine.endpointFor,
       _ping = ping ?? pingHostVpn,
       _probeLink = probeLink ?? probeHostVpnLink {
    for (final entry in machines.settings.hostUps.entries) {
      if (!entry.value.preparing) continue;
      final session = sessionFor(entry.key, entry.value)..restoreProtocol(entry.value.protocol);
      final run = HostPreparation(
        project: entry.key,
        session: session,
        record: entry.value,
        settings: machines.settings,
        interrupted: false,
      );
      _runs[entry.key] = run;
      _listen(run);
      session.state = HostRunState.busy;
      _check(run);
    }
  }

  /// Builds an idle command from the saved identity without starting a process.
  HostSession sessionFor(String project, HostUpRecord record) =>
      HostSession(executable: poreloHost(), arguments: hostArguments(record, project));

  final String Function(String) _endpointFor;
  final Future<bool> Function() _ping;
  final Future<bool> Function() _probeLink;

  /// Whether the local link exists; null until checked or when the check fails.
  bool? vpnLinkUp;

  /// Whether the last check found both the local link and an answering VPN address.
  bool vpnUp = false;

  /// State directory overrides shared with an explicitly configured host command.
  final Map<String, String>? environment;
  bool _leaving = false;

  void _check(HostPreparation run) {
    final probe = _probe(run);
    run._probe = probe;
    unawaited(
      probe.whenComplete(() {
        if (identical(run._probe, probe)) run._probe = null;
      }),
    );
  }

  Future<void> _probe(HostPreparation run) async {
    if (_disposed || _leaving || run._upActive || run.session.state == HostRunState.running) return;
    try {
      final file = File(poreloHostProjectLock(run.project, environment: environment));
      await file.parent.create(recursive: true);
      final handle = await openProjectLock(file);
      var held = false;
      try {
        try {
          await handle.lock(FileLock.exclusive);
        } on FileSystemException catch (error) {
          // Only contention proves another command is running; other failures need a refusal.
          if (![11, 13, 32, 33].contains(error.osError?.errorCode)) rethrow;
          held = true;
        }
      } finally {
        // Closing any descriptor can release this process's fcntl lock, so close before any action.
        await handle.close();
      }
      if (_disposed || _leaving || run.givenBack) return;
      run.session.state = held ? HostRunState.busy : HostRunState.idle;
      run.interrupted = !held;
      run.problem = null;
      run._lockFailed = false;
      if (held) {
        _poll(run);
      } else {
        run.session.interrupt();
        await run.saved;
      }
    } on Exception {
      if (_disposed || _leaving) return;
      run._lockFailed = true;
      run.session.state = HostRunState.refused;
      run.problem = 'The setup lock could not be checked. Close and reopen the interface to try again.';
    }
    _changed();
  }

  /// Opens the single probe descriptor; tests can delay its lock to exercise a concurrent resume.
  @visibleForTesting
  Future<RandomAccessFile> openProjectLock(File file) => file.open(mode: FileMode.append);

  void _poll(HostPreparation run) {
    run._poll?.cancel();
    run._poll = Timer(const Duration(seconds: 1), () {
      if (_disposed || _leaving || run.givenBack || run._upActive || run.session.state != HostRunState.busy) return;
      _check(run);
    });
  }

  /// Ends only setup attempts that have not finished renting; later work survives the window.
  Future<void> leave() async {
    _leaving = true;
    try {
      await Future.wait([for (final run in preparing) run.session.leave()]);
      await Future.wait([for (final run in preparing) run.saved]);
      if (preparing.any((run) => run._saveFailed)) {
        throw const FileSystemException('The setup protocol could not be kept. Keep the interface open.');
      }
    } on Exception {
      _leaving = false;
      rethrow;
    }
  }

  /// Existing hosts whose last unprivileged VPN probe failed.
  final Set<String> vpnDown = {};

  final Map<String, Machine> _vpnsToTakeDown = {};

  /// Given-back servers whose local tunnel has not yet been confirmed absent.
  List<Machine> get vpnsToTakeDown => List.unmodifiable(_vpnsToTakeDown.values);

  /// Keeps cleanup reachable after the server has left Machines.
  void rememberVpnToTakeDown(Machine machine) {
    ++_vpnProbe;
    vpnLinkUp = null;
    _vpnsToTakeDown[machine.hostProject] = machine;
    _changed();
  }

  /// Uses the same unprivileged link probe for actions and refreshes.
  Future<bool> probeVpnLink() => _probeLink();

  /// Checks existing hosts at startup and on refresh; setup itself needs a handshake.
  Future<void> refreshVpns() async {
    final generation = ++_vpnProbe;
    final hosts = machines.all.where((machine) => machine.kind == 'host').toList();
    // The local VPN is brought up only on Linux; elsewhere a failed ping says nothing about it.
    if (hosts.isEmpty && _vpnsToTakeDown.isEmpty || !Platform.isLinux) {
      vpnLinkUp = false;
      vpnUp = false;
      vpnDown.clear();
      _changed();
      return;
    }
    bool? link;
    var answers = false;
    try {
      final probes = await Future.wait([_probeLink(), hosts.isEmpty ? Future.value(false) : _ping()]);
      link = probes[0];
      answers = link && probes[1];
    } on HostFilesRefused {
      // An unreadable link must not offer a root action based on a guessed state.
      link = null;
    }
    // A slower earlier probe must not overwrite a later answer.
    if (_disposed || generation != _vpnProbe) return;
    vpnLinkUp = link;
    vpnUp = answers;
    if (link == false) _vpnsToTakeDown.clear();
    final present = machines.all.where((machine) => machine.kind == 'host').map((machine) => machine.name).toSet();
    vpnDown
      ..clear()
      ..addAll(answers ? <String>[] : hosts.map((machine) => machine.name).where(present.contains));
    _changed();
  }

  int _vpnProbe = 0;

  /// The fleet which receives a host after a successful up.
  final Machines machines;
  final Map<String, HostPreparation> _runs = {};
  bool _disposed = false;

  /// Every run still awaiting successful preparation, including refusals.
  List<HostPreparation> get preparing => _runs.values.where((run) => !run.ready && !run.givenBack).toList();

  /// The latest setup of a project, including its completed protocol.
  HostPreparation? of(String project) => _runs[project];

  /// Stops and interruptions needing a person, including setup run again on a ready server.
  List<HostPreparation> get needingYou =>
      _runs.values.where((run) => !run.givenBack && (run.needsYou || run.interrupted)).toList();

  /// Why a ready server cannot start another setup attempt now.
  String? againUnavailable(String project) {
    if (_disposed || _leaving) return 'the interface is closing';
    final run = _runs[project];
    if (run?.lockProblem case final problem?) return problem;
    if (run?.running == true) return 'the host command is still running';
    if (run?.waiting == true) return 'setup waits for you under Needs you';
    if (run != null && (!run.ready || run.givenBack)) return 'the server is not ready';
    final record = machines.settings.hostUp(project);
    if (record == null) return 'the setup arguments were not kept';
    if (record.preparing || !machines.all.any((machine) => machine.kind == 'host' && machine.hostProject == project)) {
      return 'the server is not ready';
    }
    return null;
  }

  /// Runs a ready server's kept setup as a new attempt without taking it out of Machines.
  Future<void> again(String project) {
    if (againUnavailable(project) != null) return _runs[project]?.finished ?? Future.value();
    var run = _runs[project];
    if (run == null) {
      final record = machines.settings.hostUp(project)!;
      run = HostPreparation(
        project: project,
        session: sessionFor(project, record)..restoreProtocol(record.protocol),
        record: record,
        settings: machines.settings,
      )..phase = HostPreparationPhase.reachable;
      _runs[project] = run;
      _listen(run);
    }
    return run.finished = _up(run);
  }

  /// Keeps retry availability in sync when a local terminal opens or closes.
  void vpnTerminalChanged(HostPreparation run, {required bool open}) {
    run.vpnOpen = open;
    _changed();
  }

  /// Takes ownership before starting, so no command depends on the setup view's lifetime.
  HostPreparation start({
    required String project,
    required HostSession session,
    required HostUpRecord record,
    HostTunnel? tunnel,
    Settings? settings,
  }) {
    final previous = _runs[project];
    if (_leaving || previous != null && (previous.running || previous.waiting || previous.awaitingVpn)) {
      throw StateError('This project already has a host run.');
    }
    previous?._poll?.cancel();
    if (previous?._listener case final listener?) previous!.session.removeListener(listener);
    previous?.session.dispose();
    final run = HostPreparation(
      project: project,
      session: session,
      record: record.withPreparation(record.startedAt ?? DateTime.now().toUtc()),
      tunnel: tunnel,
      settings: settings ?? machines.settings,
    );
    _runs[project] = run;
    _listen(run);
    run.finished = _up(run, newPreparation: true);
    _changed();
    return run;
  }

  /// Checks the stop again using exactly the arguments the original command ran with.
  Future<void> resume(HostPreparation run) {
    if (_disposed ||
        _leaving ||
        run.ready && !run.needsYou && !run.interrupted ||
        run.givenBack ||
        run.awaitingVpn ||
        run._upActive ||
        run.session.state == HostRunState.running ||
        run._lockFailed) {
      return run.finished;
    }
    return run.finished = _up(run);
  }

  Future<void> _up(HostPreparation run, {bool newPreparation = false}) async {
    final probe = run._probe;
    run._upActive = true;
    run._poll?.cancel();
    run.problem = null;
    _changed();
    try {
      await probe;
      if (_disposed || _leaving) return;
      if (run.session.state == HostRunState.busy) {
        _poll(run);
        return;
      }
      if (run.problem != null) return;
      final settings = run.settings;
      if (settings != null && !run.ready) {
        final kept = newPreparation ? run.record : settings.hostUp(run.project) ?? run.record;
        await settings.rememberHostUp(run.project, kept.withPreparation(run.record.startedAt));
      }
      if (_disposed || _leaving) return;
      run.interrupted = false;
      await run.session.up();
      await run.saved;
      if (run._saveFailed) throw const FileSystemException('The setup protocol could not be kept.');
      if (_disposed) return;
      if (run.session.state == HostRunState.done && !run.ready) await _addHost(run);
      if (run.session.state == HostRunState.busy) _poll(run);
    } on Exception {
      if (!_disposed) {
        run.session.state = HostRunState.refused;
        run.problem ??= 'The host command could not complete. Your machines have been kept.';
      }
    } finally {
      run._upActive = false;
      _changed();
    }
  }

  Future<void> _addHost(HostPreparation run) async {
    final session = run.session;
    final address = session.address ?? '';
    final account = session.account ?? '';
    final socket = session.socket ?? '';
    if (session.steps.any((step) => step.state == StepState.refused)) {
      run.problem = session.fix ?? 'The host refused setup.';
      return;
    }
    if (!session.steps.any((step) => step.step == 'up' && step.state == StepState.done) ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9.:-]*$').hasMatch(address) ||
        !RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*$').hasMatch(account) ||
        !RegExp(r'^/run/user/[0-9]+/porelo/porelod\.sock$').hasMatch(socket)) {
      run.problem = 'The completed host did not name a valid address, account and daemon socket.';
      return;
    }
    if (machines.all.any((machine) => machine.name == run.name && machine.kind != 'host')) {
      run.problem = 'A machine named ${run.name} already exists and is not a host.';
      return;
    }
    final settings = run.settings;
    if (settings != null) {
      final kept = settings.hostUp(run.project) ?? run.record;
      final tunnel = kept.withTunnel(
        hostPublicKey: run.tunnel?.hostPublicKey ?? kept.vpnHostPublicKey,
        address: address,
      );
      // Recovery stays until the machine is added, which waits for the VPN.
      await settings.rememberHostUp(run.project, tunnel);
      // Host files supplied by hand leave no host key, and the VPN step refuses to run without one.
      if (tunnel.vpnHostPublicKey.isEmpty) {
        await _addMachine(run);
        await settings.rememberHostUp(run.project, tunnel.withPreparation(null));
        run.phase = HostPreparationPhase.reachable;
        run.problem = 'The VPN was not set up because the host files were supplied manually.';
        return;
      }
    }
    run.phase = HostPreparationPhase.vpn;
  }

  Future<void> _addMachine(HostPreparation run) {
    final session = run.session;
    return machines.add(
      Machine(
        name: run.name,
        kind: 'host',
        socketPath: Platform.isWindows ? '' : _endpointFor(run.name),
        host: '${session.account}@${session.address}',
        remoteSocket: session.socket!,
        identity: run.record.identity,
        hostProject: run.project,
      ),
    );
  }

  /// Promotes only a terminal whose root check confirmed the expected fresh handshake.
  Future<void> vpnChecked(HostPreparation run, {required bool verified}) async {
    if (_disposed || !run.awaitingVpn || !verified || run.ready) return;
    try {
      await _addMachine(run);
      final settings = run.settings;
      final kept = settings?.hostUp(run.project);
      if (kept != null) await settings!.rememberHostUp(run.project, kept.withPreparation(null));
      run.phase = HostPreparationPhase.reachable;
      run.problem = null;
    } on Exception {
      run.problem = 'The VPN answered, but this server could not be kept in Machines. Your setup has been kept.';
    }
    _changed();
  }

  /// This account's homeserver, published for a host's tasks once its VPN is up and closed at its give-back;
  /// null where nothing here publishes it.
  final HomeserverPublishing? homeserver;

  /// Closes this computer's homeserver published for [project]'s host, once that host was given back: its tasks
  /// are gone, so nothing may reach the homeserver on that address any more. Answers why it is still published
  /// where closing failed, and null otherwise; run after [confirmDown], which waits on nothing of it.
  Future<String?> closeHomeserver(String project) async {
    final kept = machines.settings.hostUp(project);
    final closed = kept == null ? null : await homeserver?.unpublish(kept.vpnPeerAddress);
    if (closed == null || !closed.published) return null;
    if (_runs[project] case final run?) {
      run.problem = closed.words;
      _changed();
    }
    return closed.words;
  }

  /// Removes recovery only after the provider confirmed give-back and the command succeeded.
  Future<void> confirmDown(String project, HostSession session) async {
    if (!hostGivenBack(session)) return;
    final pending = _runs[project];
    await pending?.saved;
    final kept = machines.settings.hostUp(project);
    if (kept != null) {
      await machines.settings.rememberHostUp(project, kept.withPreparation(null).withProtocol(const []));
    }
    final run = _runs[project];
    if (run != null) {
      run._poll?.cancel();
      run.givenBack = true;
      run.interrupted = false;
    }
    _changed();
  }

  void _listen(HostPreparation run) {
    run._lastProtocol = jsonEncode([for (final entry in run.session.keptProtocol) entry.stored]);
    void changed() {
      final protocol = run.session.keptProtocol;
      final encoded = jsonEncode([for (final entry in protocol) entry.stored]);
      if (!run.givenBack && run._lastProtocol != encoded) {
        run._lastProtocol = encoded;
        Future<void> keep() async {
          final settings = run.settings;
          if (settings == null || run.givenBack) return;
          final kept = settings.hostUp(run.project) ?? run.record;
          await settings.rememberHostUp(run.project, kept.withProtocol(protocol));
          run._saveFailed = false;
        }

        late final Future<void> saving;
        saving = (run._saved?.then((_) => keep()) ?? keep()).then(
          (_) {
            if (identical(run._saved, saving)) run._saved = null;
          },
          onError: (Object _, StackTrace _) {
            if (identical(run._saved, saving)) run._saved = null;
            run._saveFailed = true;
            run.problem = 'The setup protocol could not be kept. Keep the interface open and check the settings file.';
            _changed();
          },
        );
        run._saved = saving;
      }
      _changed();
    }

    run._listener = changed;
    run.session.addListener(changed);
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final run in _runs.values) {
      run._poll?.cancel();
      if (run._listener case final listener?) run.session.removeListener(listener);
      run.session.dispose();
    }
    super.dispose();
  }
}

/// The facts shown for a stop, frozen so Recently resolved does not change on resume.
@immutable
class HostStop {
  /// Captures a run's stop and its source text without deriving new step words.
  HostStop(HostPreparation run)
    : project = run.project,
      interrupted = run.interrupted,
      text = run.interrupted
          ? 'Setup of ${run.name} was interrupted — the server is rented and billed'
          : run.asksOnItsOwn != null
          ? run.session.fix!
          : run.session.stepText,
      needs = List.unmodifiable(run.asksOnItsOwn ?? run.session.needs);

  /// Project to find when the stop's action is opened.
  final String project;

  /// Whether this row offers recovery rather than a terminal for a host stop.
  final bool interrupted;

  /// Words sent on the stop line, or its task name if none were sent.
  final String text;

  /// Requirements named by the host.
  final List<String> needs;
}

/// Whether teardown confirmed give-back or the absence of a rented project host.
bool hostGivenBack(HostSession session) =>
    session.state == HostRunState.done &&
    !session.steps.any((step) => step.state == StepState.refused) &&
    session.steps.any((step) => step.step == 'give-back' && step.state == StepState.done);
