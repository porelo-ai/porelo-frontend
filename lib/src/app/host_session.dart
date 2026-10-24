import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:porelo_host/porelo_host.dart';

import 'settings.dart';

/// Uses the carried collection in release builds, with explicit overrides only for debug tests.
List<String> hostArguments(HostUpRecord record, String project, {bool debug = kDebugMode}) => [
  ...record.arguments(project),
  if (debug && record.collection.isNotEmpty && record.collectionSha256.isNotEmpty) ...[
    '--collection',
    record.collection,
    '--collection-sha256',
    record.collectionSha256,
  ],
];

/// Where a `porelo-host` run has got to.
enum HostRunState {
  /// Nothing run yet.
  idle,

  /// The command runs.
  running,

  /// Stopped for the person, with [HostSession.needs] saying for what.
  waiting,

  /// Ended done.
  done,

  /// Refused, with [HostSession.fix] saying what fixes it.
  refused,

  /// The provider or the host could not be reached.
  unreachable,
}

/// Starts a program; injectable, so the session is proven without one.
typedef StartHostCommand = Future<Process> Function(String executable, List<String> arguments);

/// One `porelo-host` command the interface runs, read line by line: the steps as they come, the
/// one stop, and how it ended.
///
/// **This does no step of its own.** It starts the shipped command, which does the work, and shows
/// what that says. Nothing is written to its standard input; the person completes stops in a
/// terminal on the host and runs `up` again.
class HostSession extends ChangeNotifier {
  /// Constructor taking the command and the arguments that name the project and the host.
  HostSession({
    required this.executable,
    required List<String> arguments,
    StartHostCommand? start,
    DateTime Function()? now,
  }) : arguments = List.unmodifiable(arguments),
       _now = now ?? DateTime.now,
       _start = start ?? ((executable, arguments) => Process.start(executable, arguments));

  /// The shipped `porelo-host`, by its path.
  final String executable;

  /// What names the project and where it goes, without `up` or `down`.
  final List<String> arguments;

  final StartHostCommand _start;
  final DateTime Function() _now;
  bool _disposed = false;
  DateTime? _stepStarted;
  Step? _currentStep;

  /// Every valid event and stderr line, including earlier attempts, in arrival order.
  final List<String> protocol = [];

  /// The ordered plan supplied by the command, matched by task identity.
  List<PlannedStep> plan = const [];

  /// The latest active step, including its stop or refusal.
  Step? get currentStep => _currentStep;

  /// The step's words, falling back only to its name when no text was supplied.
  String get stepText => _currentStep?.text ?? _plannedCurrent?.text ?? _currentStep?.step ?? '';

  PlannedStep? get _plannedCurrent => plan.where((step) => step.task == _currentStep?.step).firstOrNull;

  /// Estimated time left in this step; elapsed work never makes it negative.
  int? get stepSecondsLeft {
    final seconds = _currentStep?.seconds ?? _plannedCurrent?.seconds;
    if (seconds == null || _stepStarted == null) return null;
    if (_currentStep?.state == StepState.done || state == HostRunState.done) return 0;
    final elapsed = state == HostRunState.running ? _now().difference(_stepStarted!).inSeconds : 0;
    return (seconds - elapsed).clamp(0, seconds);
  }

  /// About the whole run, including conditional tasks until a later task begins.
  int? get secondsLeft {
    if (state == HostRunState.done) return 0;
    final at = plan.indexWhere((step) => step.task == _currentStep?.step);
    final current = stepSecondsLeft;
    if (at < 0 || current == null) return null;
    var total = current;
    for (final step in plan.skip(at + 1)) {
      if (step.seconds == null) return null;
      total += step.seconds!;
    }
    return total;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Every step said so far, the last state of each in the order they began.
  final List<Step> steps = <Step>[];

  /// Where it has got to.
  HostRunState state = HostRunState.idle;

  /// At the stop, what the person must give: `drive`, `vault` or `vault-new`.
  List<String> needs = const <String>[];

  /// Where the stopped or completed host can be reached.
  String? address;

  /// The address actually given back by the completed down command, absent if none was found.
  String? releasedAddress;

  /// The account named by the person or completed up line.
  String? account;

  /// The account daemon socket named by the completed up line.
  String? socket;

  /// On a refusal, what fixes it, and what the command said on standard error.
  String? fix;

  /// What the command said for a person, as it came.
  String said = '';

  /// Brings the host up, as far as it goes.
  Future<void> up() => _run(<String>['up', ...arguments]);

  /// Takes the host down.
  Future<void> down() => _run(<String>['down', ...arguments]);

  Future<void> _run(List<String> command) async {
    if (state == HostRunState.running) return;
    steps.clear();
    plan = const [];
    _currentStep = null;
    _stepStarted = null;
    needs = const <String>[];
    address = null;
    releasedAddress = null;
    account = null;
    socket = null;
    fix = null;
    said = '';
    state = HostRunState.running;
    _changed();
    final process = await _start(executable, command);
    await process.stdin.close();
    final lines = process.stdout.transform(utf8.decoder).transform(const LineSplitter()).forEach(_line);
    final words = process.stderr.transform(utf8.decoder).transform(const LineSplitter()).forEach((line) {
      said = said.isEmpty ? line : '$said\n$line';
      protocol.add(line);
      _changed();
    });
    final code = await process.exitCode;
    await lines;
    await words;
    said = said.trim();
    state = switch (code) {
      Exit.done => HostRunState.done,
      Exit.waiting => HostRunState.waiting,
      Exit.unreachable => HostRunState.unreachable,
      _ => HostRunState.refused,
    };
    if (state != HostRunState.done && state != HostRunState.waiting) {
      fix ??= said.isEmpty ? 'porelo-host ended with $code' : said;
    }
    _changed();
  }

  void _line(String line) {
    final step = Step.fromLine(line);
    if (step == null) return;
    protocol.add(step.toLine());
    if (step.state == StepState.plan) {
      plan = List.unmodifiable(step.steps);
      _changed();
      return;
    }
    if (step.state == StepState.started || step.state == StepState.waiting || step.state == StepState.refused) {
      _currentStep = step;
      _stepStarted = _now();
    } else if (_currentStep?.step == step.step) {
      _currentStep = step;
    }
    final at = steps.indexWhere((s) => s.step == step.step);
    if (at < 0) {
      steps.add(step);
    } else {
      steps[at] = step;
    }
    if (step.state == StepState.waiting) {
      needs = step.needs;
      address = step.address;
      account = step.account;
    }
    if (step.step == 'up' && step.state == StepState.done) {
      address = step.address;
      account = step.account;
      socket = step.socket;
    }
    if (step.step == 'give-back' && step.state == StepState.done) releasedAddress = step.address;
    if (step.state == StepState.refused) fix = step.fix ?? step.words;
    _changed();
  }
}

/// The development stand-in when named, otherwise the host command shipped with this interface.
String poreloHost({Map<String, String>? environment, bool release = kReleaseMode}) {
  final standin = (environment ?? Platform.environment)['PORELO_HOST_STANDIN'];
  if (!release && standin != null && standin.isNotEmpty) return standin;
  if (Platform.isWindows) return '${File(Platform.resolvedExecutable).parent.path}\\porelo-host.exe';
  return '/usr/lib/porelo-frontend/porelo-host';
}
