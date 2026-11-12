import 'dart:async';
import 'dart:io';

/// The signals that end the window without asking and can be watched here: SIGINT, and SIGTERM where it can be
/// watched (not on Windows).
List<Stream<ProcessSignal>> endingSignals() => <Stream<ProcessSignal>>[
  ProcessSignal.sigint.watch(),
  if (!Platform.isWindows) ProcessSignal.sigterm.watch(),
];

/// On the first of [signals], starts each of [letGo] at once and then [exit]s, after all of them or after [within],
/// whichever comes first; one that hangs or throws stops none of the others. A watched signal no longer ends the
/// process by itself.
///
/// This lets go at once of everything a watched signal ends. A SIGKILL or a crash cannot be watched: what they leave
/// is found again by its record at the next start.
void letGoOnSignals(
  Iterable<Stream<ProcessSignal>> signals, {
  required List<Future<void> Function()> letGo,
  required void Function(int code) exit,
  Duration within = const Duration(seconds: 5),
}) {
  var ending = false;
  for (final signal in signals) {
    signal.listen((which) async {
      if (ending) return;
      ending = true;
      await letGoTogether(letGo, within: within);
      exit(128 + which.signalNumber);
    });
  }
}

/// Starts each of [letGo] at once, and completes once all of them are done or after [within], whichever comes first;
/// one that hangs or throws stops none of the others.
Future<void> letGoTogether(List<Future<void> Function()> letGo, {Duration within = const Duration(seconds: 5)}) {
  final all = Future.wait<void>([
    // What could not be let go is found again at the next start; the person asked for the end.
    for (final each in letGo) Future<void>.sync(each).catchError((Object _) {}),
  ]);
  return Future.any(<Future<void>>[all, Future<void>.delayed(within)]);
}
