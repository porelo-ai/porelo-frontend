import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart';

import '../app/host_stop_feed.dart';
import '../app/machines.dart';
import '../app/session.dart';
import 'unlock_terminal.dart';

/// Sets the person's lasting forge password through the pinned own-account terminal.
Future<bool> openHostForgePassword(
  BuildContext context, {
  required Machine machine,
  required String knownHosts,
  required String secretsFile,
  OpenTerminal? openTerminal,
}) async {
  if (!context.mounted) return false;
  int? code;
  await runInATerminal(
    context,
    title: 'Your lasting forge password',
    explanation: 'Type your secrets file’s master password here. If it has no lasting forge password yet, choose it in this terminal. It goes directly to your own forge login on the host.',
    machine: machine,
    open: openTerminal,
    command: hostForgePasswordFeedCommand(
      secretsFile: secretsFile,
      ssh: '/usr/bin/ssh',
      sshOptions: pinnedHostSshOptions(knownHosts, machine.identity),
      host: machine.host,
    ),
    showCommand: false,
    shownCommand: 'Set your own forge login’s password from your encrypted secrets file.',
    onExit: (value) => code = value,
  );
  return code == 0;
}
