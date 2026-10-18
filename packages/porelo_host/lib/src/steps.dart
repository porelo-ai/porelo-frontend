import 'dart:convert';

/// Where a step has got to.
enum StepState { started, done, refused, waiting }

/// One line of what `up` or `down` is doing, as a program reads it.
///
/// **One JSON object per line on standard output**, the words for a person on standard error. The
/// interface reads these and never the words.
class Step {
  /// Constructor taking the step's name and where it is.
  const Step(this.step, this.state, {this.fix, this.needs = const <String>[], this.words});

  /// Which step: `rent`, `ssh`, `copy`, `ansible`, `play`, `person`, `give-back` and the play's own.
  final String step;

  /// Where it is.
  final StepState state;

  /// On a refusal, what fixes it, in words.
  final String? fix;

  /// While waiting for the person, what they must give: `drive`, `vault` or `vault-new`.
  final List<String> needs;

  /// What the play itself said, when it said something.
  final String? words;

  /// The line, as it goes out.
  String toLine() => jsonEncode(<String, Object>{
    'step': step,
    'state': state.name,
    'fix': ?fix,
    if (needs.isNotEmpty) 'needs': needs,
    'words': ?words,
  });

  @override
  String toString() => toLine();
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

  /// Waiting for the person: a second `up`, given what the last line asks for, goes on.
  static const waiting = 75;
}
