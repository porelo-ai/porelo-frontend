import 'dart:convert';

import 'desk.dart';
import 'machines.dart';
import 'run_here.dart';
import 'wsl.dart';

/// Runs one program like [runHere], reading its output in [encoding].
typedef RunIn = Future<Ran> Function(
  String program,
  List<String> arguments, {
  String? inDirectory,
  Map<String, String> environment,
  String? input,
  Encoding encoding,
});

/// Runs Porelo's command line where Porelo is: here on Linux, and on Windows in the WSL distribution that is this
/// computer, through `wsl.exe`, since Windows has no `porelo`.
Future<Ran> runPorelo(
  String program,
  List<String> arguments, {
  String? inDirectory,
  Map<String, String> environment = const <String, String>{},
  String? input,
}) => poreloRunner()(program, arguments, inDirectory: inDirectory, environment: environment, input: input);

/// [runPorelo] over [run], for the distribution [distribution] names; the one that is this computer by default.
RunHere poreloRunner({RunIn run = runHere, String? Function()? distribution}) =>
    (
      String program,
      List<String> arguments, {
      String? inDirectory,
      Map<String, String> environment = const <String, String>{},
      String? input,
    }) async {
      if (!desk.isWindows) {
        return run(program, arguments, inDirectory: inDirectory, environment: environment, input: input);
      }
      // Neither reaches the distribution through wsl.exe, so a caller asking for one is refused, not quietly ignored.
      if (inDirectory != null || environment.isNotEmpty) {
        throw ArgumentError('Porelo in WSL is run with no directory and no environment of this computer.');
      }
      final command = await _inTheDistribution(run, distribution, <String>[program, ...arguments]);
      // What Linux prints is UTF-8, whatever this Windows' own code page.
      return run(command.first, command.skip(1).toList(), input: input, encoding: utf8);
    };

/// [command] as it runs Porelo where Porelo is: as it is on Linux, and on Windows in the WSL distribution that is this
/// computer, its Windows paths named as the distribution reaches them, for a terminal the person sees.
Future<List<String>> poreloCommandHere(List<String> command, {RunIn run = runHere, String? Function()? distribution}) =>
    desk.isWindows ? _inTheDistribution(run, distribution, command) : Future<List<String>>.value(command);

Future<List<String>> _inTheDistribution(RunIn run, String? Function()? distribution, List<String> command) async {
  final name = (distribution ?? () => Machine.thisComputersDistribution)();
  if (name == null || name.isEmpty) {
    throw const PoreloNotStarted(
      'Porelo runs in a WSL distribution on Windows, and none is connected. Add it under Add a machine, WSL.',
    );
  }
  return Wsl.runIn(name, <String>[for (final each in command) await _named(run, name, each)]);
}

/// Porelo's command line was not started, so nothing was done: no distribution to run it in, or a path it cannot
/// reach. Said with its words, and never taken for a run whose outcome is unknown.
class PoreloNotStarted extends WorkspaceRefused {
  /// Keeps a sentence that is safe to show.
  const PoreloNotStarted(super.words);
}

/// A Windows path as [distribution] names it, by `wslpath -a` run there; any other argument as it is.
///
/// A path is what Windows' own file dialogs answer: a drive and a backslash, or a share. A forge address such as
/// `g:/owner/repository.git` has a forward slash and stays as it is.
Future<String> _named(RunIn run, String distribution, String argument) async {
  if (!RegExp(r'^([A-Za-z]:\\|\\\\)').hasMatch(argument)) return argument;
  final command = Wsl.runIn(distribution, <String>['wslpath', '-a', argument]);
  final ran = await run(command.first, command.skip(1).toList(), encoding: utf8);
  final named = ran.out.trim();
  if (ran.code != 0 || named.isEmpty) {
    throw PoreloNotStarted('$distribution cannot reach $argument. Choose a file on a drive it reaches.');
  }
  return named;
}
