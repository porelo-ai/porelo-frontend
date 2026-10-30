import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:porelo_host/porelo_host.dart';

import 'host_session.dart';
import 'host_access.dart';
import 'registry.dart' show RegistryRefusal;
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
    this.act = HostAct.root,
    this.providerMachine,
    this.interrupted = false,
    this.replacementUnavailable = 'signed-state server setup is not available yet',
  });

  /// The account whose supported provider steps this run may open.
  final HostAct act;

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

  /// Why the replacement setup cannot be started, if it is unavailable.
  final String? replacementUnavailable;

  /// Whether only recovery is allowed for this rental.
  bool get legacy => record.legacy;

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
  bool get needsYou => !legacy && waiting;

  /// A removed stop is never offered as a terminal action.
  List<String>? get asksOnItsOwn => null;
}

/// Owns host setup just as Operations owns other long actions; views only observe it.
class HostRuns extends ChangeNotifier {
  /// Adds successful runs through the ordinary Machines path.
  HostRuns(this.machines, {this.environment, this.setupAgain, this.hostAccess}) {
    for (final entry in machines.settings.hostUps.entries) {
      if (!entry.value.preparing && !entry.value.legacy) continue;
      final session = sessionFor(entry.key, entry.value)..restoreProtocol(entry.value.protocol);
      final run = HostPreparation(
        project: entry.key,
        session: session,
        record: entry.value,
        settings: machines.settings,
        interrupted: false,
        replacementUnavailable: setupAgain == null ? 'signed-state server setup is not available yet' : null,
      );
      _runs[entry.key] = run;
      _listen(run);
      session.state = HostRunState.busy;
      _check(run);
    }
  }

  /// Builds an idle command from the saved identity without starting a process.
  HostSession sessionFor(String project, HostUpRecord record) => HostSession(
    executable: poreloHost(),
    arguments: record.legacy ? record.giveBackArguments(project) : hostArguments(record, project),
  );

  /// Re-enters signed-state setup for the same rental while its rental lock is held.
  /// The adapter prepares the existing rental directly and must not reacquire that lock.
  final Future<HostUpRecord> Function(String project, HostUpRecord existingRental)? setupAgain;

  /// Signed registry lifecycle operations supplied by the app composition.
  final HostAccess? hostAccess;

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
      if (_replacementLocks.contains(file.path)) {
        run.session.state = HostRunState.busy;
        _poll(run);
        return;
      }
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
      run.problem = run.legacy ? HostUpRecord.legacyExplanation : null;
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
      _runs.values.where((run) => !run.givenBack && !run.legacy && (run.needsYou || run.interrupted)).toList();

  /// Why a ready server cannot start another setup attempt now.
  String? againUnavailable(String project) {
    if (_disposed || _leaving) return 'the interface is closing';
    final record = machines.settings.hostUp(project);
    if (_settingUpAgain.contains(project)) return 'server setup is already running';
    if (record?.legacy == true) {
      if (_runs[project]?.lockProblem case final problem?) return problem;
      if (_runs[project]?.running == true) return 'the host command is still running';
      return setupAgain == null ? 'signed-state server setup is not available yet' : null;
    }
    final run = _runs[project];
    if (run?.lockProblem case final problem?) return problem;
    if (run?.running == true) return 'the host command is still running';
    if (run != null && (run.needsYou || run.interrupted)) return 'setup waits for you under Needs you';
    if (run != null && (!run.ready || run.givenBack)) return 'the server is not ready';
    if (record == null) return 'the setup arguments were not kept';
    if (record.preparing || !machines.all.any((machine) => machine.kind == 'host' && machine.hostProject == project)) {
      return 'the server is not ready';
    }
    return null;
  }

  final _settingUpAgain = <String>{};
  static final _replacementLocks = <String>{};
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
    final existing = machines.settings.hostUp(project)!;
    if (existing.legacy) {
      _settingUpAgain.add(project);
      _runs[project]?._upActive = true;
      _changed();
      return _replaceLegacy(project, existing).whenComplete(() {
        _settingUpAgain.remove(project);
        _runs[project]?._upActive = false;
        _changed();
      });
    }
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

  Future<void> _replaceLegacy(String project, HostUpRecord existing) async {
    final file = File(_lockPath(project, existing));
    if (!_replacementLocks.add(file.path)) return;
    try {
      await _serializeLock(file.path, () async {
        RandomAccessFile? handle;
        try {
          await file.parent.create(recursive: true);
          handle = await openProjectLock(file);
          await handle.lock(FileLock.exclusive);
          final access = hostAccess;
          if (access == null) throw const RegistryRefusal('The verified host admins are unavailable.');
          await access.beginPreparation(existing.hostName.isEmpty ? project : existing.hostName);
          final completed = await setupAgain!(project, existing);
          if (_disposed) return;
          if (completed.legacy ||
              completed.preparing ||
              completed.preparedHost == null ||
              completed.scalewayProject != existing.scalewayProject ||
              completed.rentalTag != existing.rentalTagFor(project) ||
              completed.host != project ||
              HostUpRecord.fromStored(completed.stored) == null) {
            throw const FormatException('Replacement setup did not confirm the same rental.');
          }
          await machines.settings.rememberHostUp(project, completed);
          final previous = _runs[project];
          final run = HostPreparation(
            project: project,
            session: sessionFor(project, completed),
            record: completed,
            settings: machines.settings,
          )..phase = HostPreparationPhase.reachable;
          previous?._poll?.cancel();
          if (previous?._listener case final listener?) previous!.session.removeListener(listener);
          previous?.session.dispose();
          _runs[project] = run;
          _listen(run);
          for (final old in machines.all.where((m) => m.kind == 'host' && m.hostProject == project).toList()) {
            await machines.forget(old);
          }
          await machines.add(
            Machine(
              name: run.name,
              socketPath: '',
              kind: 'host',
              host: completed.preparedHost!.address,
              hostProject: project,
            ),
          );
          await _publishReady(run, completed.preparedHost!);
        } finally {
          await handle?.close();
        }
      });
    } on Exception {
      _runs[project]?.problem =
          '${HostUpRecord.legacyExplanation} Setup again could not be confirmed. Its recovery data was kept.';
    } finally {
      _replacementLocks.remove(file.path);
    }
  }

  /// Takes ownership before starting, so no command depends on the setup view's lifetime.
  HostPreparation start({
    required String project,
    required HostSession session,
    required HostUpRecord record,
    Settings? settings,
  }) {
    if (record.legacy) throw StateError('Legacy credentials cannot start setup.');
    if (hostAccess == null) throw const RegistryRefusal('The verified host admins are unavailable.');
    hostAccess!.requireAdmin(record.hostName);
    final previous = _runs[project];
    if (_leaving || previous != null && (previous.running || previous.waiting)) {
      throw StateError('This project already has a host run.');
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
        run.legacy ||
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
        if (hostAccess == null) throw const RegistryRefusal('The verified host admins are unavailable.');
        await hostAccess!.beginPreparation(run.record.hostName);
      }
      final settings = run.settings;
      if (settings != null && !run.ready) {
        final kept = newPreparation ? run.record : settings.hostUp(run.project) ?? run.record;
        await settings.rememberHostUp(run.project, kept.withPreparation(run.record.startedAt));
      }
      if (_disposed || _leaving) return;
      run.interrupted = false;
      if (run.record.hostName.isNotEmpty) {
        if (hostAccess == null) throw const RegistryRefusal('The verified host admins are unavailable.');
        hostAccess!.requireAdmin(run.record.hostName);
      }
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
    final host = run.session.preparedHost;
    if (host == null ||
        host.values['address'] != run.session.address ||
        host.values['name'] != run.record.hostName ||
        !run.session.steps.any((step) => step.step == 'up' && step.state == StepState.done) ||
        run.session.steps.any((step) => step.state == StepState.refused)) {
      run.problem = 'The server did not confirm its SSH completion record.';
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
    await _publishReady(run, host);
  }

  Future<void> _publishReady(HostPreparation run, PreparedHost host) async {
    try {
      final access = hostAccess;
      if (access == null) throw const RegistryRefusal('The verified host admins are unavailable.');
      await access.publishReady(run.record.hostName, host);
    } on Exception {
      run.problem = 'The host is ready; its registry card still needs publication. Retry publication without running setup again.';
    }
  }

  /// Removes recovery only after the provider confirmed give-back and the command succeeded.
  Future<String?> confirmDown(String project, HostSession session) async {
    if (!hostGivenBack(session)) return null;
    final pending = _runs[project];
    await pending?.saved;
    final registryProblem = await confirmHostRegistryGiveBack(
      host: project,
      session: session,
      settings: machines.settings,
      access: hostAccess,
    );
    final kept = machines.settings.hostUp(project);
    if (kept != null) {
      await machines.settings.forgetHostUp(project);
    }
    final run = _runs[project];
    if (run != null) {
      run._poll?.cancel();
      run.givenBack = true;
      run.interrupted = false;
      run.problem = registryProblem;
    }
    _changed();
    return registryProblem;
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
