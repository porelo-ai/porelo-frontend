import 'package:porelo_frontend/client.dart';

/// What a `Stop` did, in words.
///
/// Every action reports its outcome and nothing silently appears to succeed — so every value the
/// contract can send has a sentence here, and one it cannot is rendered rather than swallowed.
/// `Outcome` gains entries without that being a breaking change.
String stopWords(String task, Stopped result) {
  final surviving = switch (result.surviving) {
    0 => '',
    1 => ' One helper outlived the stop and has to be killed on the machine by hand.',
    final count => ' $count helpers outlived the stop and have to be killed on the machine by hand.',
  };
  final said = _detail(result.detail);
  return switch (result.outcome) {
    Outcome.stopped => '$task was stopped. It is kept, workspace and all, and can be started again.$surviving$said',
    Outcome.notATask => '$task is not a task Porelo created. Nothing was touched.$said',
    Outcome.nothingToStop => 'There was nothing of $task to stop.$said',
    _ => '$task: ${result.outcome.label}.$surviving$said',
  };
}

/// What a `Remove` did, or why it did not, in words named by the consequence.
String removeWords(String task, Removed result) {
  final rescued = result.rescuedRef.isEmpty ? '' : ' What it held was pushed to ${result.rescuedRef}.';
  // Nothing else records what the container held beyond its image, so a removal that does not say
  // is the last chance to know that anything went. A count of paths, not a size.
  final discarded = switch (result.discarded) {
    0 => '',
    1 => ' One path only it held went with it.',
    final count => ' $count paths only it held went with it.',
  };
  final said = _detail(result.detail);
  return switch (result.outcome) {
    Outcome.removed => '$task was removed.$rescued$discarded$said',
    Outcome.holdsWork => '$task holds work that never reached the gate, so nothing was touched.$said',
    Outcome.nothingKnows => 'Nothing could say whether $task holds work, so it was left as it was.$said',
    Outcome.stillRunning => '$task is still running, so nothing was removed.$said',
    Outcome.notATask => '$task is not a task Porelo created. Nothing was touched.$said',
    Outcome.rescueNeedsItRunning => '$task is already down, so what it holds cannot be read out of it.$said',
    Outcome.rescueFailed => 'Rescuing $task failed, so nothing was removed.$said',
    _ => '$task: ${result.outcome.label}.$rescued$discarded$said',
  };
}

/// What a `Start` did to a listed task, or the refusal it answered with.
///
/// [afterARestart] is what the task said before it was started: a `RESUME` with a reason is one a
/// restart of its machine took down, and bringing it back restores its records, its egress and
/// its tokens. Read from that structured answer, never from the lines the start printed.
String startWords(String task, StartProgress result, {bool afterARestart = false}) {
  final drift = result.imageDrift.isEmpty ? '' : ' The image it was built from has changed since: ${result.imageDrift}';
  final problems = result.problems.isEmpty ? '' : ' ${result.problems.join('; ')}.';
  final started = result.helpersStarted;
  final recorded = result.helpersRecorded;
  final action = result.action;
  final restored =
      '$task is back after the machine restarted: its records, its egress and its '
      'tokens were restored';
  return switch (action) {
    // A start that worked answers with no action at all, measured on Porelo 199.1: what the task
    // said before it was started is what tells a restart's return from any other.
    null when afterARestart && (result.exitCode ?? 0) == 0 => '$restored.$drift',
    null =>
      (result.exitCode ?? 0) == 0
          ? '$task was started.'
          : 'Starting $task failed with exit code ${result.exitCode}.${_reasonIn(result.output)}',
    // Fewer started than recorded is a partial start, and saying "running again" would be a lie.
    StartAction.resume when started != null && recorded != null && started < recorded =>
      '$task is running again, but only $started of $recorded helpers came back.'
          '$problems$drift',
    StartAction.resume when afterARestart => '$restored${started == null ? '' : ', with $started helpers'}.$drift',
    StartAction.resume => '$task is running again${started == null ? '' : ' with $started helpers'}.$drift',
    StartAction.create => '$task was created and started.',
    StartAction.running => '$task is already running. Nothing was started.',
    StartAction.needsVault => '$task was not started: the vault is locked. Unlock it, then start it again.',
    StartAction.supersededName => '$task is from before one container per task, so it cannot be started. Remove it.',
    StartAction.notReady => '$task was not started: its project is not ready.',
    StartAction.predatesRestart =>
      '$task was started before this machine restarted, so it cannot be started again. '
          'Copy its workspace out, then remove it.',
    _ => '$task: ${action.label}.',
  };
}

/// What a failed launch said last, as one sentence: its last unindented line and the indented lines
/// that continue it. What came before is the plan it printed on the way, not why it stopped.
String _reasonIn(List<String> printed) {
  final start = printed.lastIndexWhere((line) => line.trim().isNotEmpty && !line.startsWith(' '));
  if (start < 0) return '';
  final said = printed.sublist(start).map((line) => line.trim()).where((line) => line.isNotEmpty);
  return ' It said: ${said.join(' ')}';
}

/// A byte count as a person reads it.
String size(int bytes) {
  const units = <String>['bytes', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return unit == 0 ? '$bytes bytes' : '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${units[unit]}';
}

/// What the machine added in its own words, as a sentence after the rest, or nothing.
String _detail(String detail) {
  final said = detail.trim();
  if (said.isEmpty) return '';
  return ' ${said.endsWith('.') ? said : '$said.'}';
}
