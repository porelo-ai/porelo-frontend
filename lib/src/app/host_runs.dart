import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:porelo_host/porelo_host.dart';

import 'host_session.dart';
import 'host_access.dart';
import 'machines.dart';
import 'settings.dart';

/// The confirmed stages of signed-state server setup.
enum HostPreparationPhase {
  /// The host command is running, stopped, or refused.
  preparing,

  /// The server supplied its checked SSH completion record.
  reachable,
}

/// One project's setup, retained independently of any dialog watching it.
class HostPreparation {
  /// Keeps only the public setup record, its running command and public tunnel settings.
  HostPreparation({
    required this.project,
    required this.session,
    required this.record,
    this.settings,
    this.providerMachine,
    this.interrupted = false,
  });

  /// The verified account connection used only for supported provider sign-ins.
  final Machine? providerMachine;

  /// Project identity, never a path.
  final String project;

  /// The command and its immutable arguments, reused for every resume.
  final HostSession session;

  /// The original nonsecret setup answers.
  final HostUpRecord record;

  /// Persists public completion settings independently of the setup dialog's lifetime.
  final Settings? settings;

  /// The machine's name even before a daemon exists.
  String get name => record.hostName.isEmpty ? '$project server' : record.hostName;

  /// Whether the server completion was checked and kept.
  bool get ready => phase == HostPreparationPhase.reachable;

  /// The phase confirmed by the server completion.
  HostPreparationPhase phase = HostPreparationPhase.preparing;

  /// Whether only recovery is allowed for this rental.

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

  /// Whether a supported provider sign-in still needs a person.
  bool get needsYou => waiting;
}

/// Owns host setup just as Operations owns other long actions; views only observe it.
class HostRuns extends ChangeNotifier {
  /// Adds successful runs through the ordinary Machines path.
  HostRuns(this.machines, {this.environment, this.hostAccess, this.onReady, this.say}) {
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

  /// Who may prepare a host, and what goes to the organization, supplied by the app composition.
  final HostAccess? hostAccess;

  /// Called once a host stands on its card, to give it the host admin's central token.
  final Future<void> Function(String host)? onReady;

  /// Says what the person must hear with no dialog open: a rental given back after a stop.
  final void Function(String words)? say;

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
      final file = File(_lockPath(run.project, run.record));
      final held = await _serializeLock(file.path, () async {
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
        return held;
      });
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
    final record = machines.settings.hostUp(project);
    final run = _runs[project];
    if (run?.lockProblem case final problem?) return problem;
    if (run?.running == true) return 'the machine setup command is still running';
    if (run != null && (run.needsYou || run.interrupted)) return 'setup waits for you under Needs you';
    if (run != null && (!run.ready || run.givenBack)) return 'the server is not ready';
    if (record == null) return 'the setup arguments were not kept';
    if (record.preparing || !machines.all.any((machine) => machine.kind == 'host' && machine.hostProject == project)) {
      return 'the server is not ready';
    }
    return null;
  }

  static final _localLockOwners = <String, Future<void>>{};

  static Future<T> _serializeLock<T>(String path, Future<T> Function() action) async {
    final previous = _localLockOwners[path];
    final released = Completer<void>();
    _localLockOwners[path] = released.future;
    try {
      await previous;
      return await action();
    } finally {
      released.complete();
      if (identical(_localLockOwners[path], released.future)) _localLockOwners.remove(path);
    }
  }

  String _lockPath(String project, HostUpRecord record) =>
      poreloHostProjectLock(HostPlan.lockNameForTag(record.rentalTagFor(project)), environment: environment);

  /// Re-enters the verified setup flow for this same rental.
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

  /// Takes ownership before starting, so no command depends on the setup view's lifetime.
  HostPreparation start({
    required String project,
    required HostSession session,
    required HostUpRecord record,
    Settings? settings,
  }) {
    if (hostAccess == null) throw const HostAccessRefused('The verified Machine Admins are unavailable.');
    hostAccess!.requireAdmin(record.hostName);
    final previous = _runs[project];
    if (_leaving || previous != null && (previous.running || previous.waiting)) {
      throw StateError('This project already has a machine setup run.');
    }
    previous?._poll?.cancel();
    if (previous?._listener case final listener?) previous!.session.removeListener(listener);
    previous?.session.dispose();
    final run = HostPreparation(
      project: project,
      session: session,
      record: record.withPreparation(record.startedAt ?? DateTime.now().toUtc()),
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
      if (run.record.hostName.isNotEmpty) {
        if (hostAccess == null) throw const HostAccessRefused('The verified Machine Admins are unavailable.');
        await hostAccess!.check(run.record.hostName);
        // A run taken up again must not hand on the pin of its first start.
        if (run.record.machineFile.isNotEmpty) await hostAccess!.machineFile(run.record.hostName);
      }
      final settings = run.settings;
      if (settings != null && !run.ready) {
        final kept = newPreparation ? run.record : settings.hostUp(run.project) ?? run.record;
        await settings.rememberHostUp(run.project, kept.withPreparation(run.record.startedAt));
      }
      if (_disposed || _leaving) return;
      run.interrupted = false;
      if (run.record.hostName.isNotEmpty) {
        if (hostAccess == null) throw const HostAccessRefused('The verified Machine Admins are unavailable.');
        hostAccess!.requireAdmin(run.record.hostName);
      }
      await run.session.up();
      await run.saved;
      if (run._saveFailed) throw const FileSystemException('The setup protocol could not be kept.');
      if (_disposed) return;
      if (run.session.state == HostRunState.done && !run.ready) {
        await _addHost(run);
      } else if (!run.ready && const [HostRunState.refused, HostRunState.unreachable].contains(run.session.state)) {
        final said = run.session.fix ?? run.session.stepText;
        final stop = 'Setup of ${run.name} stopped: ${said.endsWith('.') ? said : '$said.'}';
        // Nothing of a run refused at its first login stands on the machine, so there is no setup to remove.
        run.problem = stop;
        if (_stoppedAtItsFirstLogin(run)) {
          say?.call(stop);
        } else {
          _stopped(run, stop);
        }
      }
      if (run.session.state == HostRunState.busy) _poll(run);
    } on Exception {
      if (!_disposed) {
        run.session.state = HostRunState.refused;
        run.problem ??= 'The machine setup command could not complete. Your machines have been kept.';
      }
    } finally {
      run._upActive = false;
      _changed();
    }
  }

  Future<void> _addHost(HostPreparation run) async {
    final host = run.session.preparedHost;
    if (host == null ||
        host.values['address'] != run.session.address ||
        host.values['name'] != run.record.hostName ||
        !run.session.steps.any((step) => step.step == 'up' && step.state == StepState.done) ||
        run.session.steps.any((step) => step.state == StepState.refused)) {
      _stopped(run, 'The server did not confirm its SSH completion record.');
      return;
    }
    final access = hostAccess;
    final refused = access == null ? 'The verified Machine Admins are unavailable.' : await access.writeCard(host);
    if (refused != null) {
      _stopped(run, "${run.name}'s card could not be written to the organization: $refused");
      return;
    }
    final settings = run.settings ?? machines.settings;
    await settings.rememberHostUp(
      run.project,
      (settings.hostUp(run.project) ?? run.record).withPreparedHost(host).withPreparation(null),
    );
    await machines.add(
      Machine(
        name: run.name,
        kind: 'host',
        socketPath: '',
        host: '${host.values['address']}',
        hostProject: run.project,
      ),
    );
    run.phase = HostPreparationPhase.reachable;
    await onReady?.call(run.record.hostName);
  }

  /// Says a stop. Nothing is given back unasked: this attempt rented nothing, since `up` only takes a server given to it.
  void _stopped(HostPreparation run, String why) {
    final action = run.record.isRental ? 'Return this rental…' : 'Take Porelo off this machine…';
    final words = '$why The machine stays as it is: "$action" on its row removes its setup.';
    run.problem = words;
    say?.call(words);
  }

  /// Whether [run] stopped at its first login on a machine one already has, with no try ever past it, so
  /// nothing of it stands on the machine and its answers can be given again.
  bool mayStartOver(HostPreparation run) => !run.running && _stoppedAtItsFirstLogin(run);

  bool _stoppedAtItsFirstLogin(HostPreparation run) =>
      !run.record.isRental &&
      run.record.preparedHost == null &&
      (run.problem ?? '').contains(hostKeyNotFiled) &&
      !run.session.attempts.any((attempt) => attempt.entries.any(_passedTheLogin));

  static bool _passedTheLogin(Object entry) =>
      entry is HostStepRecord && entry.step.step == 'ssh' && entry.step.state == StepState.done;

  /// Lets go of such a run: its saved answers would only be refused the same way.
  Future<void> startOver(HostPreparation run) async {
    if (!mayStartOver(run)) return;
    await run.saved;
    run._poll?.cancel();
    if (run._listener case final listener?) run.session.removeListener(listener);
    run._listener = null;
    _runs.remove(run.project);
    await (run.settings ?? machines.settings).forgetHostUp(run.project);
    _changed();
  }

  /// Removes recovery only after the provider confirmed give-back and the command succeeded.
  Future<String?> confirmDown(String project, HostSession session) async {
    if (!hostGivenBack(session)) return null;
    final pending = _runs[project];
    await pending?.saved;
    final left = hostAccess?.cardLeftBehind(project);
    final kept = machines.settings.hostUp(project);
    if (kept != null) {
      await machines.settings.forgetHostUp(project);
    }
    final run = _runs[project];
    if (run != null) {
      run._poll?.cancel();
      run.givenBack = true;
      run.interrupted = false;
      run.problem = left;
    }
    _changed();
    return left;
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
          : run.session.stepText,
      needs = List.unmodifiable(run.session.needs);

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
