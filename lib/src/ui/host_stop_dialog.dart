import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart';

import '../app/host_runs.dart';
import '../app/host_stop_feed.dart';
import '../app/machines.dart';
import '../app/session.dart';
import '../app/settings.dart';
import 'tokens.dart';

/// Opens only supported provider steps; obsolete needs never start a process.
Future<void> openHostStopDialog(
  BuildContext context, {
  required HostPreparation run,
  required HostRuns hostRuns,
  required Machines machines,
  Settings? settings,
  OpenTerminal? openTerminal,
  List<String>? needs,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      HostStopDialog(run: run, hostRuns: hostRuns, machines: machines, openTerminal: openTerminal, needs: needs),
);

/// The host's public stop with provider input kept in its own terminal.
class HostStopDialog extends StatelessWidget {
  /// Uses the host's named requirements without accepting credential values.
  const HostStopDialog({
    required this.run,
    required this.hostRuns,
    required this.machines,
    this.openTerminal,
    this.needs,
    super.key,
  });

  /// The stopped setup.
  final HostPreparation run;

  /// The setup owner.
  final HostRuns hostRuns;

  /// The selected accounts.
  final Machines machines;

  /// The terminal boundary.
  final OpenTerminal? openTerminal;

  /// Explicit requirements, or the host protocol's needs.
  final List<String>? needs;
  @override
  Widget build(BuildContext context) {
    String? problem;
    try {
      if (run.legacy) throw const FormatException('This rental needs setup again through signed state.');
      hostStopFeedCommand(
        act: HostAct.root,
        project: run.project,
        needs: needs ?? run.session.needs,
        ssh: '/usr/bin/ssh',
        sshOptions: const [],
        host: '',
      );
    } on FormatException catch (error) {
      problem = error.message;
    }
    return AlertDialog(
      title: const Text('Server setup'),
      content: SizedBox(width: Sizes.dialogSmall, child: Text(problem ?? run.session.stepText)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}
