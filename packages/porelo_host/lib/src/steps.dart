import 'dart:convert';

/// Where a step has got to.
enum StepState { started, done, refused, waiting }

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
  });

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
    final step = decoded['step'];
    final named = decoded['state'];
    final state = StepState.values.where((s) => s.name == named).firstOrNull;
    if (step is! String || state == null) return null;
    return Step(
      step,
      state,
      fix: decoded['fix'] as String?,
      needs: (decoded['needs'] as List<Object?>? ?? const <Object?>[]).whereType<String>().toList(),
      words: decoded['words'] as String?,
      address: decoded['address'] is String ? decoded['address'] as String : null,
      account: decoded['account'] is String ? decoded['account'] as String : null,
      socket: decoded['socket'] is String ? decoded['socket'] as String : null,
    );
  }

  /// The line, as it goes out.
  String toLine() => jsonEncode(<String, Object>{
    'step': step,
    'state': state.name,
    'fix': ?fix,
    if (needs.isNotEmpty) 'needs': needs,
    'words': ?words,
    'address': ?address,
    'account': ?account,
    'socket': ?socket,
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

  /// Waiting for the person: run `up` again after completing the stop on the host.
  static const waiting = 75;
}
