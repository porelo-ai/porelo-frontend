/// Whether a commit's trailer says an agent assisted it, and in the one way asked for: exactly one
/// `Assisted-by` line and no `Co-Authored-By` line.
///
/// **Judged here from the lines the machine reports, never from their absence**: where it reports
/// none, the check is one that cannot be made, never one that passed.
final class TrailerCheck {
  const TrailerCheck._(this.state, this.words);

  /// Judges [trailers], the commit's trailer lines as git reads them; null where the machine does not
  /// report them. [message], the commit's whole message, is read for a `Co-Authored-By` line outside
  /// git's trailer block, which is in no trailer line; null where the machine does not report it.
  static TrailerCheck of(List<String>? trailers, {required String? message}) {
    // Without the whole message a co-author outside the trailer block cannot be ruled out.
    if (trailers == null || message == null) {
      return const TrailerCheck._(TrailerState.unknown, 'Assisted-by and Co-Authored-By cannot be checked here');
    }
    // git reads a trailer's key without regard to case, so this does too.
    String keyOf(String line) {
      final colon = line.indexOf(':');
      return (colon < 0 ? line : line.substring(0, colon)).trim().toLowerCase();
    }

    final keys = trailers.map(keyOf).toList();
    final assisted = keys.where((key) => key == 'assisted-by').length;
    final inTrailers = keys.where((key) => key == 'co-authored-by').length;
    final inMessage = message.split('\n').where((line) => line.contains(':') && keyOf(line) == 'co-authored-by').length;
    final coAuthors = inMessage > inTrailers ? inMessage : inTrailers;
    if (assisted == 1 && coAuthors == 0) {
      return const TrailerCheck._(TrailerState.passed, 'One Assisted-by, no Co-Authored-By');
    }
    final wrong = <String>[
      if (assisted == 0) 'no Assisted-by',
      if (assisted > 1) '$assisted Assisted-by lines, not one',
      if (coAuthors == 1) 'a Co-Authored-By',
      if (coAuthors > 1) '$coAuthors Co-Authored-By lines',
    ];
    final said = wrong.join(' and ');
    return TrailerCheck._(TrailerState.wrong, '${said[0].toUpperCase()}${said.substring(1)}');
  }

  /// Passed, wrong, or not checkable here.
  final TrailerState state;

  /// What it says, in a few words.
  final String words;

  /// Whether the check was made and passed.
  bool get passed => state == TrailerState.passed;
}

/// What a trailer check came to.
enum TrailerState {
  /// Exactly one Assisted-by and no Co-Authored-By.
  passed,

  /// Read, and not as asked for.
  wrong,

  /// The machine does not report the trailer, so nothing can be checked.
  unknown,
}
