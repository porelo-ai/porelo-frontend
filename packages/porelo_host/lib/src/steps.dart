import 'dart:convert';

/// Where a step has got to.
enum StepState { started, done, refused, waiting, plan }

/// One line of what `up` or `down` is doing, as a program reads it.
///
/// **One JSON object per line on standard output**, the words for a person on standard error. The
/// interface reads these and never the words.
class Step {
  /// Constructor taking the step's name and where it is.
  const Step(
    this.step,
    this.state, {
    this.fix,
    this.needs = const <String>[],
    this.words,
    this.address,
    this.account,
    this.socket,
    this.text,
    this.seconds,
    this.steps = const [],
  });

  /// The step's own words for a person, without interpreting its task name.
  final String? text;

  /// Its usual duration, absent where the step has no estimate.
  final int? seconds;

  /// The run ahead, only on a plan line.
  final List<PlannedStep> steps;

  /// Which step: `rent`, `ssh`, `copy`, `ansible`, `play`, `person`, `up`, `give-back` and the play's own.
  final String step;

  /// Where it is.
  final StepState state;

  /// On a refusal, what fixes it, in words.
  final String? fix;

  /// While waiting for the person, what they must give: `drive`, `vault` or `vault-new`.
  final List<String> needs;

  /// The host at the person stop or completed up, or the address actually given back by down.
  final String? address;

  /// The account at the person stop or after a successful up.
  final String? account;

  /// The account daemon socket after a successful up.
  final String? socket;

  /// What the play itself said, when it said something.
  final String? words;

  /// A line as [toLine] wrote it, or null for one that is not a step's.
  static Step? fromLine(String line) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) return null;
    if (decoded['state'] == 'plan') {
      final steps = PlannedStep.readMany(decoded['steps']);
      if (decoded['v'] != 1 || steps == null) return null;
      return Step('plan', StepState.plan, steps: steps);
    }
    if (!validStepFields(decoded)) return null;
    final step = decoded['step'];
    final named = decoded['state'];
    final state = StepState.values.where((s) => s.name == named).firstOrNull;
    if (step is! String || state == null) return null;
    return Step(
      step,
      state,
      text: decoded['text'] as String?,
      seconds: decoded['seconds'] as int?,
      fix: decoded['fix'] as String?,
      needs: (decoded['needs'] as List<Object?>? ?? const <Object?>[]).whereType<String>().toList(),
      words: decoded['words'] as String?,
      address: decoded['address'] is String ? decoded['address'] as String : null,
      account: decoded['account'] is String ? decoded['account'] as String : null,
      socket: decoded['socket'] is String ? decoded['socket'] as String : null,
    );
  }

  /// The line, as it goes out.
  String toLine() => state == StepState.plan
      ? jsonEncode({
          'v': 1,
          'state': 'plan',
          'steps': [for (final step in steps) step.toJson()],
        })
      : jsonEncode(<String, Object>{
          'step': step,
          'state': state.name,
          'fix': ?fix,
          if (needs.isNotEmpty) 'needs': needs,
          'words': ?words,
          'text': ?text,
          'seconds': ?seconds,
          'address': ?address,
          'account': ?account,
          'socket': ?socket,
        });

  @override
  String toString() => toLine();
}

/// A task's identity, words and usual duration in the collection's ordered plan.
class PlannedStep {
  /// Declares an estimate at the place that defines the work.
  const PlannedStep(this.task, this.text, {this.seconds, this.when = false});

  /// Identity used to match progress, independent of skipped tasks or arrival order.
  final String task;

  /// The words defined by the task's owner.
  final String text;

  /// Usual duration, absent where unknown.
  final int? seconds;

  /// Whether this task may be skipped; its estimate counts until a later task starts.
  final bool when;

  /// The collection's wire representation.
  Map<String, Object> toJson() => {'task': task, 'text': text, 'seconds': ?seconds, if (when) 'when': true};

  /// Validates the whole plan before accepting any of it.
  static List<PlannedStep>? readMany(Object? value) {
    if (value is! List) return null;
    final result = <PlannedStep>[];
    final names = <String>{};
    for (final item in value) {
      if (item is! Map<String, Object?>) return null;
      final task = item['task'];
      final text = item['text'];
      final seconds = item['seconds'];
      final when = item['when'];
      if (task is! String ||
          task.isEmpty ||
          text is! String ||
          item.containsKey('seconds') && (seconds is! int || seconds < 0) ||
          item.containsKey('when') && when is! bool ||
          !names.add(task)) {
        return null;
      }
      result.add(PlannedStep(task, text, seconds: seconds as int?, when: when == true));
    }
    return result;
  }
}

/// Validates optional fields before either a callback or a command line is read.
bool validStepFields(Map<String, Object?> fields) {
  for (final name in ['msg', 'task', 'play', 'text', 'fix', 'words', 'address', 'account', 'socket']) {
    if (fields.containsKey(name) && fields[name] is! String) return false;
  }
  final seconds = fields['seconds'];
  if (fields.containsKey('seconds') && (seconds is! int || seconds < 0)) return false;
  final needs = fields['needs'];
  if (fields.containsKey('needs') && (needs is! List || needs.any((need) => need is! String))) return false;
  if (fields.containsKey('steps') && PlannedStep.readMany(fields['steps']) == null) return false;
  return true;
}

/// How `up` and `down` end.
abstract final class Exit {
  /// Done.
  static const done = 0;

  /// The command line was wrong.
  static const usage = 64;

  /// Refused, with what fixes it in the last line.
  static const refused = 65;

  /// The provider or the host could not be reached.
  static const unreachable = 69;

  /// Waiting for the person: run `up` again after completing the stop on the host.
  static const waiting = 75;
}
