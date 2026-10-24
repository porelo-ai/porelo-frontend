import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:porelo_host/porelo_host.dart';

import 'host_session.dart';
import 'machines.dart';
import 'settings.dart';

/// One project's setup, retained independently of any dialog watching it.
class HostPreparation {
  /// Keeps only the public setup record, its running command and public tunnel settings.
  HostPreparation({required this.project, required this.session, required this.record, this.tunnel, this.settings});

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

  /// True only after exit zero and a validated destination were added to Machines.
  bool ready = false;

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
  HostRuns(this.machines, {String Function(String)? endpointFor}) : _endpointFor = endpointFor ?? Machine.endpointFor;

  final String Function(String) _endpointFor;

  /// The fleet which receives a host after a successful up.
  final Machines machines;
  final Map<String, HostPreparation> _runs = {};
  bool _disposed = false;

  /// Every run still awaiting successful preparation, including refusals.
  List<HostPreparation> get preparing => _runs.values.where((run) => !run.ready).toList();

  /// The latest setup of a project, including its completed protocol.
  HostPreparation? of(String project) => _runs[project];

  /// Takes ownership before starting, so no command depends on the setup view's lifetime.
  HostPreparation start({
    required String project,
    required HostSession session,
    required HostUpRecord record,
    HostTunnel? tunnel,
    Settings? settings,
  }) {
    final previous = _runs[project];
    if (previous != null && !previous.ready) throw StateError('This project already has a host run.');
    previous?.session.removeListener(_changed);
    previous?.session.dispose();
    final run = HostPreparation(project: project, session: session, record: record, tunnel: tunnel, settings: settings);
    _runs[project] = run;
    session.addListener(_changed);
    run.finished = _up(run);
    _changed();
    return run;
  }

  /// Checks the stop again using exactly the arguments the original command ran with.
  Future<void> resume(HostPreparation run) {
    if (_disposed || run.ready || run.session.state == HostRunState.running) return run.finished;
    return run.finished = _up(run);
  }

  Future<void> _up(HostPreparation run) async {
    run.problem = null;
    try {
      await run.session.up();
      if (_disposed) return;
      if (run.session.state == HostRunState.done) await _addHost(run);
    } on Exception {
      if (!_disposed) {
        run.session.state = HostRunState.refused;
        run.problem = 'The host command could not complete. Your machines have been kept.';
      }
    }
    _changed();
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
      await settings.rememberHostUp(
        run.project,
        kept.withTunnel(hostPublicKey: run.tunnel?.hostPublicKey ?? '', address: address),
      );
    }
    await machines.add(
      Machine(
        name: run.name,
        kind: 'host',
        socketPath: Platform.isWindows ? '' : _endpointFor(run.name),
        host: '$account@$address',
        remoteSocket: socket,
        identity: run.record.identity,
        hostProject: run.project,
      ),
    );
    run.ready = true;
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
