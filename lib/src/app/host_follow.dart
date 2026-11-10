import 'dart:convert';
import 'dart:io';

import 'connections.dart' show onTheMachine;
import 'machines.dart';
import 'organization_source.dart';
import 'run_here.dart';

/// A host that offers no start of its read of the organization, in the backend's words: the action is greyed for it.
class HostFollowUnavailable extends OrganizationRefused {
  /// Keeps why.
  const HostFollowUnavailable(super.words);
}

/// Asks a host to read the organization now, rather than at its next round within five minutes: `porelo host follow`,
/// in the person's own account there through its login shell, which starts the host's read or joins the one running
/// and waits for it. Porelo's own command does the rest; this window never reaches root for it.
class SshHostFollow {
  /// Runs ssh through [run].
  SshHostFollow({RunHere? run}) : _run = run ?? runHere;

  final RunHere _run;

  /// Asks only whether the host's Porelo knows the start; starts nothing.
  static const offeredCommand = <String>['porelo', 'host', 'follow', '--help'];

  /// Starts the host's read of the organization, or joins the one running, and waits for it.
  static const followCommand = <String>['porelo', 'host', 'follow'];

  /// Status 69: the host offers no start, by Porelo's own contract for `porelo host follow`.
  static const _unavailable = 69;

  /// Why [host], reached as [machine], offers no start of its read, or null where it offers one.
  Future<String?> whyNotOffered(Machine machine, String host) async {
    final Ran ran;
    try {
      ran = await _ask(machine, host, offeredCommand);
    } on OrganizationRefused catch (refused) {
      return refused.words;
    }
    if (ran.code == 0) return null;
    // ssh's own failure says nothing of the host's Porelo.
    if (ran.code == 255) return _said(ran.err) ?? '$host could not be asked whether it offers this.';
    return "$host's Porelo offers no start of its read of the organization: it reads it at its next round, within "
        'five minutes.';
  }

  /// Has [host], reached as [machine], read the organization now, and answers what it said of that read. Throws
  /// [HostFollowUnavailable] where it offers no start, and [OrganizationRefused] in its words where it refused.
  Future<String> follow(Machine machine, String host) async {
    final ran = await _ask(machine, host, followCommand);
    final said = _said(ran.err);
    if (_completed(ran.out) case final status?) {
      if (status == 0 && ran.code == 0) return '$host read the organization.';
      // A read that ended well, its answer then lost on the way, is said by the status that came back.
      final code = status == 0 ? ran.code : status;
      return '$host read the organization, and its read ended with status $code${said == null ? '' : ': $said'}';
    }
    if (ran.code == _unavailable) {
      throw HostFollowUnavailable(said ?? '$host offers no start of its read of the organization.');
    }
    throw OrganizationRefused(said ?? '$host did not read the organization now, and did not say why.');
  }

  Future<Ran> _ask(Machine machine, String host, List<String> command) async {
    // Only ssh to the host's own account: never this computer, its WSL, or another machine's account.
    if (!machine.needsATunnel ||
        machine.relay?.kind == 'wsl' ||
        machine.host != host ||
        machine.whyNotReachableHere != null) {
      throw OrganizationRefused('This computer cannot reach your account on $host.');
    }
    final line = onTheMachine(machine, command, terminal: false);
    if (line == null) throw OrganizationRefused('This computer cannot reach your account on $host.');
    try {
      return await _run(line.first, line.sublist(1), input: '');
    } on ProcessException {
      throw const OrganizationRefused('SSH could not run on this computer.');
    } on WorkspaceRefused catch (refused) {
      throw OrganizationRefused(refused.words);
    }
  }

  /// The pass's status where the host answered a completed one, or null. The answer is its last line: a login shell
  /// may say its own lines before it.
  static int? _completed(String out) {
    final last = _said(out);
    if (last == null) return null;
    try {
      return switch (jsonDecode(last)) {
        {'completed': true, 'exitCode': final int status} => status,
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }

  /// The last line the backend said on its error stream, or null where it said nothing.
  static String? _said(String err) {
    final lines = const LineSplitter().convert(err).map((line) => line.trim()).where((line) => line.isNotEmpty);
    return lines.lastOrNull;
  }
}
