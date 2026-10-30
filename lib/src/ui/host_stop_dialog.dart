import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart';

import '../app/host_runs.dart';
import '../app/host_stop_feed.dart';
import '../app/machines.dart';
import '../app/session.dart';
import '../app/settings.dart';
import 'tokens.dart';
import 'unlock_terminal.dart';

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
  builder: (_) => HostStopDialog(
    run: run,
    hostRuns: hostRuns,
    machines: machines,
    settings: settings,
    openTerminal: openTerminal,
    needs: needs,
  ),
);

/// The host's public stop with provider input kept in its own terminal.
class HostStopDialog extends StatefulWidget {
  /// Uses the host's named requirements without accepting credential values.
  const HostStopDialog({
    required this.run,
    required this.hostRuns,
    required this.machines,
    this.settings,
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

  /// The recovery settings checked before opening a provider terminal.
  final Settings? settings;

  /// The terminal boundary.
  final OpenTerminal? openTerminal;

  /// Explicit requirements, or the host protocol's needs.
  final List<String>? needs;
  @override
  State<HostStopDialog> createState() => _HostStopDialogState();
}

class _HostStopDialogState extends State<HostStopDialog> {
  String _email = '';
  bool _opening = false;

  Future<void> _open(Machine machine, List<String> command) async {
    setState(() => _opening = true);
    var completed = false;
    await runInATerminal(
      context,
      title: 'Provider sign-in',
      explanation: 'Enter provider credentials only in this terminal or the provider’s own login.',
      machine: machine,
      command: command,
      open: widget.openTerminal,
      onExit: (code) => completed = code == 0,
    );
    if (!mounted) return;
    setState(() => _opening = false);
    if (completed) await widget.hostRuns.resume(widget.run);
  }

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final needs = widget.needs ?? run.session.needs;
    final machine = run.providerMachine;
    String? problem;
    List<String>? command;
    var drive = false;
    try {
      if (run.legacy || run.act != HostAct.ownAccount) {
        throw const FormatException('Server preparation accepts no secret stops.');
      }
      // Validate all requirements before offering even the public email field.
      hostStopCommand(needs, email: 'person@example.org');
      drive = needs.contains('drive');
      if (machine == null ||
          machine.kind != 'host' ||
          machine.identity.isNotEmpty ||
          machine.legacyHost ||
          !machine.needsATunnel ||
          machine.whyNotReachableHere != null ||
          (widget.settings ?? widget.machines.settings).hostUp(machine.hostProject)?.legacy == true) {
        throw const FormatException('The provider terminal needs a verified host account connection.');
      }
      command = hostStopFeedCommand(
        act: run.act,
        project: run.project,
        needs: needs,
        ssh: openSsh('ssh'),
        sshOptions: machine.loginSshOptions,
        host: machine.host,
        email: _email,
      );
    } on FormatException catch (error) {
      problem = error.message;
    }
    return AlertDialog(
      title: const Text('Server setup'),
      content: SizedBox(
        width: Sizes.dialogSmall,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(problem ?? run.session.stepText),
            if (drive)
              TextField(
                key: const Key('host-drive-email'),
                decoration: const InputDecoration(labelText: 'Tresorit email address'),
                onChanged: (value) => setState(() => _email = value),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _opening ? null : () => Navigator.pop(context), child: const Text('Close')),
        if (command != null && machine != null)
          FilledButton(
            key: const Key('host-open-provider-terminal'),
            onPressed: _opening ? null : () => unawaited(_open(machine, command!)),
            child: const Text('Open provider terminal'),
          ),
      ],
    );
  }
}
