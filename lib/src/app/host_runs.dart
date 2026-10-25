import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:porelo_host/porelo_host.dart';

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

  bool _upActive = false;

  /// Whether setup owns an active attempt, including persistence and machine confirmation.
  bool get running => _upActive || session.state == HostRunState.running;

  /// A local refusal, such as an unusable completion destination.
  String? problem;

  /// The current attempt, including its confirmed machine addition.
  Future<void> finished = Future.value();

  /// Whether the command has stopped for the person.
  bool get waiting => session.state == HostRunState.waiting;
}

/// Owns host setup just as Operations owns other long actions; views only observe it.
class HostRuns extends ChangeNotifier {
  /// Adds successful runs through the ordinary Machines path.
  HostRuns(
    this.machines, {
    String Function(String)? endpointFor,
    Future<bool> Function()? ping,
    Future<bool> Function()? probeLink,
  }) : _endpointFor = endpointFor ?? Machine.endpointFor,
       _ping = ping ?? pingHostVpn,
       _probeLink = probeLink ?? probeHostVpnLink {
    for (final entry in machines.settings.hostUps.entries) {
      if (!entry.value.preparing) continue;
      final session = sessionFor(entry.key, entry.value);
      final run = HostPreparation(
        project: entry.key,
        session: session,
        record: entry.value,
        settings: machines.settings,
        interrupted: true,
      );
      _runs[entry.key] = run;
      session.addListener(_changed);
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

  /// Existing hosts whose last unprivileged VPN probe failed.
  final Set<String> vpnDown = {};

  /// Checks existing hosts at startup and on refresh; setup itself needs a handshake.
  Future<void> refreshVpns() async {
    final generation = ++_vpnProbe;
    final hosts = machines.all.where((machine) => machine.kind == 'host').toList();
    // The local VPN is brought up only on Linux; elsewhere a failed ping says nothing about it.
    if (hosts.isEmpty || !Platform.isLinux) {
      vpnLinkUp = false;
      vpnUp = false;
      vpnDown.clear();
      _changed();
      return;
    }
    bool? link;
    var answers = false;
    try {
      final probes = await Future.wait([_probeLink(), _ping()]);
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
    if (previous != null && (previous.running || previous.waiting || previous.awaitingVpn)) {
      throw StateError('This project already has a host run.');
    }
    previous?.session.removeListener(_changed);
    previous?.session.dispose();
    final run = HostPreparation(
      project: project,
      session: session,
      record: record.withPreparation(record.startedAt ?? DateTime.now().toUtc()),
      tunnel: tunnel,
      settings: settings ?? machines.settings,
    );
    _runs[project] = run;
    session.addListener(_changed);
    run.finished = _up(run, newPreparation: true);
    _changed();
    return run;
  }

  /// Checks the stop again using exactly the arguments the original command ran with.
  Future<void> resume(HostPreparation run) {
    if (_disposed || run.ready || run.givenBack || run.awaitingVpn || run.running) return run.finished;
    return run.finished = _up(run);
  }

  Future<void> _up(HostPreparation run, {bool newPreparation = false}) async {
    run._upActive = true;
    run.problem = null;
    _changed();
    try {
      final settings = run.settings;
      if (settings != null) {
        final kept = newPreparation ? run.record : settings.hostUp(run.project) ?? run.record;
        await settings.rememberHostUp(run.project, kept.withPreparation(run.record.startedAt));
      }
      if (_disposed) return;
      run.interrupted = false;
      await run.session.up();
      if (_disposed) return;
      if (run.session.state == HostRunState.done) await _addHost(run);
    } on Exception {
      if (!_disposed) {
        run.session.state = HostRunState.refused;
        run.problem = 'The host command could not complete. Your machines have been kept.';
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

  /// Removes recovery only after the provider confirmed give-back and the command succeeded.
  Future<void> confirmDown(String project, HostSession session) async {
    if (!hostGivenBack(session)) return;
    final kept = machines.settings.hostUp(project);
    if (kept != null) await machines.settings.rememberHostUp(project, kept.withPreparation(null));
    final run = _runs[project];
    if (run != null) {
      run.givenBack = true;
      run.interrupted = false;
    }
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final run in _runs.values) {
      run.session.removeListener(_changed);
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
      text = run.session.stepText,
      needs = List.unmodifiable(run.session.needs);

  /// Project to find when the stop's action is opened.
  final String project;

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
