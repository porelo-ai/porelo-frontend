import 'dart:async';
import 'dart:io';

import 'window_log.dart';

/// Ends the window on the first of [signals]: [end] first, then [exit] with 0, also where [end] failed; nothing else
/// the window raised is taken down here. Watching SIGTERM or SIGINT takes its default end away, so the window must end
/// itself; a later signal while it ends changes nothing.
void endOnSignals(
  Iterable<Stream<ProcessSignal>> signals, {
  required Future<void> Function() end,
  required void Function(int code) exit,
}) {
  var ending = false;
  for (final signal in signals) {
    signal.listen((received) async {
      if (ending) return;
      ending = true;
      windowLog.info('The window ends on $received.');
      try {
        await end();
      } on Object catch (error) {
        windowLog.error('The window ends on $received, but what it started could not be ended: $error');
      }
      exit(0);
    });
  }
}
