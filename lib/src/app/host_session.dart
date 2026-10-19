import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:porelo_host/porelo_host.dart';

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
/// what that says. **The person's answers go only to the command's standard input**, as one JSON
/// object, and are dropped from memory when written; they never stand in its arguments.
class HostSession extends ChangeNotifier {
  /// Constructor taking the command and the arguments that name the project and the host.
  HostSession({required this.executable, required this.arguments, StartHostCommand? start})
    : _start = start ?? ((executable, arguments) => Process.start(executable, arguments));

  /// The shipped `porelo-host`, by its path.
  final String executable;

  /// What names the project and where it goes, without `up` or `down`.
  final List<String> arguments;

  final StartHostCommand _start;

  /// Every step said so far, the last state of each in the order they began.
  final List<Step> steps = <Step>[];

  /// Where it has got to.
  HostRunState state = HostRunState.idle;

  /// At the stop, what the person must give: `drive`, `vault` or `vault-new`.
  List<String> needs = const <String>[];

  /// On a refusal, what fixes it, and what the command said on standard error.
  String? fix;

  /// What the command said for a person, as it came.
  String said = '';

  /// Brings the host up, as far as it goes.
  Future<void> up() => _run(<String>['up', ...arguments]);

  /// Goes on after the stop with what the person gave.
  Future<void> resume(Answers answers) => _run(<String>['up', ...arguments, '--answers-on-stdin'], answers: answers);

  /// Takes the host down.
  Future<void> down() => _run(<String>['down', ...arguments]);

  Future<void> _run(List<String> command, {Answers? answers}) async {
    steps.clear();
    needs = const <String>[];
    fix = null;
    said = '';
    state = HostRunState.running;
    notifyListeners();
    final process = await _start(executable, command);
    if (answers != null) {
      process.stdin.write(
        jsonEncode(<String, String>{
          if (answers.driveEmail != null) 'driveEmail': answers.driveEmail!,
          if (answers.drivePassword != null) 'drivePassword': answers.drivePassword!,
          if (answers.driveCode != null) 'driveCode': answers.driveCode!,
          if (answers.vaultPassphrase != null) 'vaultPassphrase': answers.vaultPassphrase!,
        }),
      );
    }
    await process.stdin.close();
    final lines = process.stdout.transform(utf8.decoder).transform(const LineSplitter()).forEach(_line);
    final words = process.stderr.transform(utf8.decoder).join();
    final code = await process.exitCode;
    await lines;
    said = (await words).trim();
    state = switch (code) {
      Exit.done => HostRunState.done,
      Exit.waiting => HostRunState.waiting,
      Exit.unreachable => HostRunState.unreachable,
      _ => HostRunState.refused,
    };
    if (state != HostRunState.done && state != HostRunState.waiting) {
      fix ??= said.isEmpty ? 'porelo-host ended with $code' : said;
    }
    notifyListeners();
  }

  void _line(String line) {
    final step = Step.fromLine(line);
    if (step == null) return;
    final at = steps.indexWhere((s) => s.step == step.step);
    if (at < 0) {
      steps.add(step);
    } else {
      steps[at] = step;
    }
    if (step.state == StepState.waiting) needs = step.needs;
    if (step.state == StepState.refused) fix = step.fix ?? step.words;
    notifyListeners();
  }
}

/// The `porelo-host` that came with this interface: beside it on Windows, in its library on Linux.
String shippedPoreloHost() {
  if (Platform.isWindows) return '${File(Platform.resolvedExecutable).parent.path}\\porelo-host.exe';
  return '/usr/lib/porelo-frontend/porelo-host';
}
