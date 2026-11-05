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

  /// This run where the carried collection holds a check; otherwise, or with an older command, null.
  Future<HostCheckRun?> ifCarried() async {
    try {
      return (await _run(_program, const ['check', '--available'])).code == 0 ? this : null;
    } on ProcessException {
      return null;
    } on WorkspaceRefused {
      return null;
    }
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
      return HostCheckAnswer.read(ran.out, exitCode: ran.code);
    } on ProcessException {
      return const HostCheckAnswer.notAnswered('This computer could not start the check.');
    } on WorkspaceRefused catch (refused) {
      return HostCheckAnswer.notAnswered(refused.words);
    }
  }
}
