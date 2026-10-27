import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:porelo_host/porelo_host.dart';

import 'settings.dart';
import 'host_protocol.dart';

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

  /// Another command still holds the project's setup lock.
  busy,

  /// Ended done.
  done,

  /// Refused, with [HostSession.fix] saying what fixes it.
  refused,

  /// The provider or the host could not be reached.
  unreachable,
}

/// Starts a program; injectable, so the session is proven without one.
typedef StartHostCommand = Future<Process> Function(String executable, List<String> arguments);

/// Checks the kept provider key with the same executable used for host setup.
Future<({int code, String message})> checkHostScalewayKey({
  StartHostCommand? start,
  Map<String, String>? environment,
}) async {
  Process? process;
  try {
    process = await (start ?? Process.start)(poreloHost(environment: environment), ['key', 'check', 'scaleway']);
    await process.stdin.close();
    final result = await Future.wait<Object>([
      process.exitCode,
      process.stdout.transform(utf8.decoder).join(),
      process.stderr.transform(utf8.decoder).join(),
    ]).timeout(const Duration(seconds: 35));
    final code = result[0] as int;
    final errors = (result[2] as String).trim();
    return (
      code: code,
      message: code == 0
          ? 'accepted'
          : errors.isEmpty
          ? 'Scaleway key check ended with $code.'
          : errors,
    );
  } on Exception {
    process?.kill();
    return (code: 69, message: 'The Scaleway key check could not complete.');
  }
}

/// One step's progress and emission times within a single attempt.
class HostStepRecord {
  HostStepRecord._(this._step, this.startedAt, this._text, this._seconds);

  Step _step;
  String _text;
  int? _seconds;
  DateTime? _endedAt;

  /// The latest event for this step.
  Step get step => _step;

  /// The first event's instant, or its arrival time for an older host.
  final DateTime startedAt;

  /// The terminal event's instant, or its arrival time for an older host.
  DateTime? get endedAt => _endedAt;

  /// The step's words, retained when a later event omits them.
  String get text => _text;

  /// The usual duration supplied by the step or plan.
  int? get seconds => _seconds;
}

class _ProtocolWords {
  _ProtocolWords(this.line, this.echoes) : public = HostProtocolLine(line);
  final String line;
  final Set<String> echoes;
  final HostProtocolLine public;
  bool get unmatched => !echoes.contains(line);
}

/// One command attempt's timing and ordered public entries.
class HostAttemptRecord {
  HostAttemptRecord._(this.startedAt, [this._endedAt]);

  /// The instant the command started, or the first recorded event for older settings.
  final DateTime startedAt;
  DateTime? _endedAt;
  final List<Object> _entries = [];

  /// The instant the command ended or was confirmed interrupted.
  DateTime? get endedAt => _endedAt;

  /// The steps, unmatched diagnostics, and interruptions in arrival order.
  List<Object> get entries => List.unmodifiable([
    for (final entry in _entries)
      if (entry is _ProtocolWords) ...[if (entry.unmatched) entry.public] else entry,
  ]);

  /// The local bounds shown when this attempt is collapsed.
  String get earlierLabel {
    String time(DateTime instant) {
      final local = instant.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    return 'Earlier attempt, ${time(startedAt)}–${time(endedAt ?? startedAt)}';
  }
}

String _duration(int seconds) => seconds < 60 ? '$seconds s' : '${(seconds / 60).ceil()} min';

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
  Future<Process>? _starting;
  Process? _process;
  bool _upCommand = false;

  /// Whether leaving can still stop setup without interrupting work on the server.
  bool get renting => _upCommand && !steps.any((step) => step.step == 'rent' && step.state == StepState.done);

  /// Stops only an up still before its completed rent step and waits briefly for its exit.
  Future<void> leave() async {
    final starting = _starting;
    if (!renting || starting == null) return;
    final process = await starting;
    if (!renting || !identical(process, _process)) return;
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      throw TimeoutException('Setup did not stop. Keep the interface open and try leaving again.');
    }
  }

  Step? _currentStep;
  final Map<String, HostStepRecord> _history = {};
  final List<HostAttemptRecord> _attempts = [];
  Iterable<Object> get _protocol => _attempts.expand((attempt) => attempt._entries);
  Set<String> _echoes = {};
  List<_ProtocolWords> _words = [];

  /// The attempts in command order, with the latest last.
  List<HostAttemptRecord> get attempts => List.unmodifiable(_attempts);

  /// One line per step and unmatched stderr line, including earlier attempts.
  List<String> get protocol => [
    for (final entry in _protocol)
      if (entry is HostStepRecord)
        stepLine(entry)
      else if (entry is _ProtocolWords && entry.unmatched)
        entry.line
      else if (entry is HostProtocolLine)
        entry.text
      else if (entry is HostProtocolInterruption)
        interruptionLine(entry),
  ];

  /// The whole public protocol for sharing, including collapsed attempts.
  String get protocolText => [
    for (final attempt in _attempts)
      [
        identical(attempt, _attempts.last) ? 'Current attempt' : attempt.earlierLabel,
        for (final entry in attempt.entries)
          if (entry is HostStepRecord)
            stepLine(entry)
          else if (entry is HostProtocolLine)
            entry.text
          else if (entry is HostProtocolInterruption)
            interruptionLine(entry),
      ].join('\n'),
  ].join('\n\n');

  /// The public steps and unmatched diagnostics, frozen before an asynchronous settings write.
  List<HostProtocolEntry> get keptProtocol => List.unmodifiable([
    for (final attempt in _attempts) ...[
      HostProtocolAttempt(attempt.startedAt, endedAt: attempt.endedAt),
      for (final entry in attempt._entries)
        if (entry is HostStepRecord)
          HostProtocolStep(
            name: entry.step.step,
            state: entry.step.state,
            text: entry.text,
            words: entry.step.words,
            fix: entry.step.fix,
            seconds: entry.seconds,
            startedAt: entry.startedAt,
            endedAt: entry.endedAt,
            current: identical(_history[entry.step.step], entry),
          )
        else if (entry is _ProtocolWords && entry.unmatched)
          HostProtocolLine(entry.line)
        else if (entry is HostProtocolEntry)
          entry,
    ],
  ]);

  /// Restores recorded presentation without treating past events as a running command or a destination.
  void restoreProtocol(List<HostProtocolEntry> entries) {
    var explicitAttempts = false;
    bool? legacyCurrent;
    for (final entry in entries) {
      if (entry is HostProtocolAttempt) {
        explicitAttempts = true;
        _attempts.add(HostAttemptRecord._(entry.startedAt, entry.endedAt));
        continue;
      }
      if (!explicitAttempts && entry is HostProtocolStep) {
        final previous = _attempts.lastOrNull;
        // Older settings have no boundaries; repeated steps and current flags identify known retries.
        if (previous == null ||
            legacyCurrent != null && legacyCurrent != entry.current ||
            previous._entries.whereType<HostStepRecord>().any((record) => record.step.step == entry.name)) {
          _attempts.add(HostAttemptRecord._(entry.startedAt));
        }
        legacyCurrent = entry.current;
        _attempts.last._endedAt = entry.endedAt ?? entry.startedAt;
      }
      if (_attempts.isEmpty) {
        final at = entry is HostProtocolInterruption ? entry.at : _now();
        _attempts.add(HostAttemptRecord._(at));
      }
      if (entry is HostProtocolStep) {
        final step = Step(entry.name, entry.state, text: entry.text, words: entry.words, fix: entry.fix);
        final record = HostStepRecord._(step, entry.startedAt, entry.text, entry.seconds).._endedAt = entry.endedAt;
        _attempts.last._entries.add(record);
        if (entry.current) {
          _history[entry.name] = record;
          _currentStep = step;
        }
      } else {
        _attempts.last._entries.add(entry);
      }
    }
  }

  /// Records a confirmed interruption once, preserving its first observed instant across restarts.
  void interrupt() {
    if (_protocol.lastOrNull is HostProtocolInterruption) return;
    final at = _now().toUtc();
    if (_attempts.isEmpty) _attempts.add(HostAttemptRecord._(at));
    _attempts.last._endedAt ??= at;
    _attempts.last._entries.add(HostProtocolInterruption(at));
    _changed();
  }

  /// The latest confirmed interruption, absent while another attempt is being recorded.
  String? get interruptionText => switch (_protocol.lastOrNull) {
    final HostProtocolInterruption entry => interruptionLine(entry),
    _ => null,
  };

  /// The local time a free lock confirmed that the earlier command had ended.
  String interruptionLine(HostProtocolInterruption entry) {
    final local = entry.at.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'Interrupted at ${two(local.hour)}:${two(local.minute)}';
  }

  /// The current attempt's steps in the order they began, with their start and end times.
  List<HostStepRecord> get history => List.unmodifiable(_history.values);

  HostStepRecord? get _currentRecord => _history[_currentStep?.step];

  /// The current step's running time, absent once it has ended.
  int? get stepSecondsRunning {
    final record = _currentRecord;
    if (state != HostRunState.running || record == null || record.endedAt != null) return null;
    final elapsed = _now().difference(record.startedAt).inSeconds;
    return elapsed < 0 ? 0 : elapsed;
  }

  /// The explanation shown once a running step exceeds its usual duration.
  String? get stepOverrun {
    final elapsed = stepSecondsRunning;
    final expected = _currentRecord?.seconds;
    if (elapsed == null || expected == null || elapsed <= expected) return null;
    return 'taking longer than the usual ${_duration(expected)}, running for ${_duration(elapsed)}';
  }

  /// The estimate for all steps still ahead of the current one.
  int? get secondsAfterStep {
    final at = plan.indexWhere((step) => step.task == _currentStep?.step);
    if (at < 0) return null;
    var total = 0;
    for (final step in plan.skip(at + 1)) {
      if (step.seconds == null) return null;
      total += step.seconds!;
    }
    return total;
  }

  /// The overall estimate, with an overrun's remaining work explicitly after the current step.
  String? get timeLeftText {
    final overrun = stepOverrun != null;
    final seconds = overrun ? secondsAfterStep : secondsLeft;
    if (seconds == null) return null;
    return 'about ${_duration(seconds)} left ${overrun ? 'after this step' : 'in all'}';
  }

  /// Renders a step's local start time, words, and its completed duration or current overrun.
  String stepLine(HostStepRecord record) {
    final local = record.startedAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final time = '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
    final details = <String>{
      if (record.step.words?.isNotEmpty == true) record.step.words!,
      if (record.step.fix?.isNotEmpty == true) record.step.fix!,
    };
    final parts = <String>['$time ${record.text}', ...details];
    if (record.endedAt case final ended?) {
      final seconds = ended.difference(record.startedAt).inSeconds;
      parts.add('${record.step.state.name}, took ${_duration(seconds < 0 ? 0 : seconds)}');
    } else if (identical(record, _currentRecord)) {
      if (stepOverrun case final overrun?) parts.add(overrun);
    }
    return parts.join(' — ');
  }

  /// The ordered plan supplied by the command, matched by task identity.
  List<PlannedStep> plan = const [];

  /// The latest active step, including its stop or refusal.
  Step? get currentStep => _currentStep;

  /// The step's words, falling back only to its name when no text was supplied.
  String get stepText => _currentStep?.text ?? _plannedCurrent?.text ?? _currentStep?.step ?? '';

  PlannedStep? get _plannedCurrent => plan.where((step) => step.task == _currentStep?.step).firstOrNull;

  /// Estimated time left in this step; elapsed work never makes it negative.
  int? get stepSecondsLeft {
    final seconds = _currentRecord?.seconds;
    if (seconds == null || _currentRecord == null) return null;
    if (_currentStep?.state == StepState.done || state == HostRunState.done) return 0;
    final elapsed = stepSecondsRunning ?? 0;
    return (seconds - elapsed).clamp(0, seconds);
  }

  /// About the whole run, including conditional tasks until a later task begins.
  int? get secondsLeft {
    if (state == HostRunState.done) return 0;
    final current = stepSecondsLeft;
    final after = secondsAfterStep;
    return current == null || after == null ? null : current + after;
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
  List<Step> get steps => [for (final record in _history.values) record.step];

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

  /// The host's own login user, named at a stop or a refusal, whose passwordless sudo takes the stop's `--stdin` call.
  String? admin;

  /// The account daemon socket named by the completed up line.
  String? socket;

  /// On a refusal, what fixes it, and what the command said on standard error.
  String? fix;

  /// What the command said for a person, as it came.
  String get said => _words.where((words) => words.unmatched).map((words) => words.line).join('\n').trim();

  /// Brings the host up, as far as it goes.
  Future<void> up() => _run(<String>['up', ...arguments]);

  /// Takes the host down.
  Future<void> down() => _run(<String>['down', ...arguments]);

  Future<void> _run(List<String> command) async {
    if (state == HostRunState.running) return;
    final attempt = HostAttemptRecord._(_now());
    _attempts.add(attempt);
    plan = const [];
    _currentStep = null;
    _history.clear();
    _echoes = {};
    _words = [];
    needs = const <String>[];
    address = null;
    releasedAddress = null;
    account = null;
    admin = null;
    socket = null;
    fix = null;
    state = HostRunState.running;
    _changed();
    _upCommand = command.first == 'up';
    try {
      _starting = _start(executable, command);
      final process = _process = await _starting!;
      await process.stdin.close();
      final lines = process.stdout.transform(utf8.decoder).transform(const LineSplitter()).forEach(_line);
      final words = process.stderr.transform(utf8.decoder).transform(const LineSplitter()).forEach((line) {
        final words = _ProtocolWords(line, _echoes);
        _words.add(words);
        attempt._entries.add(words);
        _changed();
      });
      final code = await process.exitCode;
      await lines;
      await words;
      state = switch (code) {
        Exit.done => HostRunState.done,
        Exit.waiting when _currentStep?.step == 'lock' && _currentStep?.state == StepState.refused => HostRunState.busy,
        Exit.waiting => HostRunState.waiting,
        Exit.unreachable => HostRunState.unreachable,
        _ => HostRunState.refused,
      };
      if (state != HostRunState.done && state != HostRunState.waiting) {
        fix ??= said.isEmpty ? 'porelo-host ended with $code' : said;
      }
      attempt._endedAt = _now();
      _changed();
    } finally {
      if (attempt._endedAt == null) {
        attempt._endedAt = _now();
        _changed();
      }
      _process = null;
      _starting = null;
      _upCommand = false;
    }
  }

  void _line(String line) {
    final step = Step.fromLine(line);
    if (step == null) return;
    if (step.state == StepState.plan) {
      plan = List.unmodifiable(step.steps);
      _changed();
      return;
    }
    // Either pipe can arrive first; matching echoes stay filtered even when stdout comes later.
    _echoes.addAll(const LineSplitter().convert(hostStepWords(step)));
    final instant = step.at ?? _now();
    final planned = plan.where((each) => each.task == step.step).firstOrNull;
    final record = _history.putIfAbsent(step.step, () {
      final record = HostStepRecord._(
        step,
        instant,
        step.text ?? planned?.text ?? step.step,
        step.seconds ?? planned?.seconds,
      );
      _attempts.last._entries.add(record);
      return record;
    });
    record._step = step;
    record._text = step.text ?? planned?.text ?? record.text;
    record._seconds = step.seconds ?? planned?.seconds ?? record.seconds;
    if (step.state != StepState.started) record._endedAt = instant;
    if (step.state == StepState.started || step.state == StepState.waiting || step.state == StepState.refused) {
      _currentStep = step;
    } else if (_currentStep?.step == step.step) {
      _currentStep = step;
    }
    if (step.state == StepState.waiting) {
      needs = step.needs;
      address = step.address;
      account = step.account;
      admin = step.admin;
    }
    if (step.state == StepState.refused && step.address != null) {
      address = step.address;
      admin = step.admin;
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
