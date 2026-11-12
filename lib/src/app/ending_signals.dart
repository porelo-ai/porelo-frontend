import 'dart:async';
import 'dart:io';

/// The signals that end the window without asking and can be watched here: SIGINT, and SIGTERM where it can be
/// watched (not on Windows).
List<Stream<ProcessSignal>> endingSignals() => <Stream<ProcessSignal>>[
  ProcessSignal.sigint.watch(),
  if (!Platform.isWindows) ProcessSignal.sigterm.watch(),
];

/// On the first of [signals], lets go of what this interface raised and then [exit]s, after [letGo] or after [within],
/// whichever comes first; a watched signal no longer ends the process by itself.
///
/// This lets go at once of everything a watched signal ends. A SIGKILL or a crash cannot be watched: what they leave
/// is found again by its record at the next start.
void letGoOnSignals(
  Iterable<Stream<ProcessSignal>> signals, {
  required Future<void> Function() letGo,
  required void Function(int code) exit,
  Duration within = const Duration(seconds: 5),
}) {
  var ending = false;
  for (final signal in signals) {
    signal.listen((which) async {
      if (ending) return;
      ending = true;
      try {
        await Future.any(<Future<void>>[letGo(), Future<void>.delayed(within)]);
      } catch (_) {
        // Ending all the same: the person asked for it, and what could not be let go is found again at the next start.
      }
      exit(128 + which.signalNumber);
    });
  }
}
