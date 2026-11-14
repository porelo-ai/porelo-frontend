import 'dart:io' show ProcessException;

import 'package:porelo_host/porelo_host.dart' show HostCheckAnswer, HostPreparationSettings;

import 'host_session.dart' show poreloHost;
import 'run_here.dart';

/// The carried collection's check of a machine, asked of `porelo-host`. The window holds no limit of its own.
class HostCheckRun {
  /// Uses [run] in place of this computer's, in a test.
  HostCheckRun({RunHere? run, this.executable}) : _run = run ?? runHere;

  final RunHere _run;

  /// The command to ask; the one this interface ships with when null.
  final String? executable;

  String get _program => executable ?? poreloHost();

  /// This run where the carried collection holds a check; otherwise null, with in its why what porelo-host said is in the
  /// way: no collection, one this account cannot read, another digest, or one without a check.
  Future<({HostCheckRun? run, String? why})> carried() async {
    final Ran ran;
    try {
      ran = await _run(_program, const ['check', '--available']);
    } on ProcessException {
      return (run: null, why: 'porelo-host could not be run here, so preparing runs without a check.');
    } on WorkspaceRefused catch (refused) {
      return (run: null, why: refused.words);
    }
    if (ran.code == 0) return (run: this, why: null);
    final said = ran.out.trim();
    if (ran.code == 4) {
      return (
        run: null,
        why: said.isEmpty ? 'The collection carried here holds no check, so preparing runs without one.' : said,
      );
    }
    final err = ran.err.trim();
    return (run: null, why: 'porelo-host could not say whether a check is carried${err.isEmpty ? '' : ': $err'}.');
  }

  /// What the machine at [address] answers; anything but the check's own answer reads as no answer, never as a pass.
  Future<HostCheckAnswer> check({
    required String address,
    required String hostKey,
    required String publicKey,
    required HostPreparationSettings settings,
  }) async {
    try {
      final ran = await _run(_program, [
        'check',
        '--given',
        address,
        '--host-key',
        hostKey,
        '--public-key',
        publicKey,
        ...settings.arguments,
      ]);
      final answer = HostCheckAnswer.read(ran.out, exitCode: ran.code);
      if (answer.answered) return answer;
      final said = ran.err.trim().split('\n').where((line) => line.trim().isNotEmpty).lastOrNull?.trim() ?? '';
      return HostCheckAnswer.notAnswered(
        said.isEmpty
            ? '${answer.said} porelo-host ended with exit ${ran.code}.'
            : '${answer.said} porelo-host said: $said (exit ${ran.code})',
      );
    } on ProcessException {
      return const HostCheckAnswer.notAnswered('This computer could not start the check.');
    } on WorkspaceRefused catch (refused) {
      return HostCheckAnswer.notAnswered(refused.words);
    }
  }
}
