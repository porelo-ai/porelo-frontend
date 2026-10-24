import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart';

import '../app/host_runs.dart';
import '../app/machines.dart';
import '../app/session.dart';
import '../app/settings.dart';
import 'dialog_scroll.dart';
import 'host_dialog.dart';
import 'tokens.dart';
import 'unlock_terminal.dart';

/// Opens only what the host needs from the person, retaining the stop on dismissal.
Future<void> openHostStopDialog(
  BuildContext context, {
  required HostPreparation run,
  required HostRuns hostRuns,
  required Machines machines,
  Settings? settings,
  OpenTerminal? openTerminal,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      HostStopDialog(run: run, hostRuns: hostRuns, machines: machines, settings: settings, openTerminal: openTerminal),
);

/// Public setup answers only; secrets go directly into the host script's terminal.
class HostStopDialog extends StatefulWidget {
  /// Observes the run owned by the frame without taking ownership of it.
  const HostStopDialog({
    required this.run,
    required this.hostRuns,
    required this.machines,
    this.settings,
    this.openTerminal,
    super.key,
  });

  /// The setup stopped for the person.
  final HostPreparation run;

  /// Owns setup and resumes it only after the host script succeeds.
  final HostRuns hostRuns;

  /// The fleet shown by the setup protocol.
  final Machines machines;

  /// Public setup settings used by the existing protocol dialog.
  final Settings? settings;

  /// Replaces SSH with a controlled terminal in tests.
  final OpenTerminal? openTerminal;

  @override
  State<HostStopDialog> createState() => _HostStopDialogState();
}

class _HostStopDialogState extends State<HostStopDialog> {
  final _email = TextEditingController();
  bool _terminalOpen = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    widget.hostRuns.addListener(_closeWhenNotWaiting);
  }

  @override
  void dispose() {
    widget.hostRuns.removeListener(_closeWhenNotWaiting);
    _email.dispose();
    super.dispose();
  }

  /// A stop that no longer waits has nothing left to ask; the route goes even under a terminal.
  void _closeWhenNotWaiting() {
    if (widget.run.waiting || !mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && route.isActive) Navigator.of(context).removeRoute(route);
  }

  /// Replaces this dialog, so the protocol's own stop never stacks on a stale one.
  void _showTheProtocol() {
    Navigator.pop(context);
    unawaited(
      openHostRunDialog(
        context,
        run: widget.run,
        hostRuns: widget.hostRuns,
        machines: widget.machines,
        settings: widget.settings,
        openTerminal: widget.openTerminal,
      ),
    );
  }

  String _outcome(int? code) => switch (code) {
    0 => 'The host has what it needs; setup goes on.',
    75 => 'Cancelled; the stop stays under Needs you.',
    64 => 'Host setup ended with code 64: a wrong call. The stop is kept.',
    69 => 'Host setup ended with code 69: a client is missing on the host. The stop is kept.',
    null => 'The terminal was closed without completing setup. The stop stays under Needs you.',
    _ => 'Host setup ended with code $code. The stop is kept.',
  };

  Future<void> _openTerminal() async {
    if (_terminalOpen || !widget.run.waiting) return;
    final session = widget.run.session;
    final String line;
    try {
      line = hostStopCommand(session.needs, email: _email.text);
    } on FormatException catch (error) {
      setState(() => _problem = error.message);
      return;
    }
    final address = session.address ?? '';
    final account = session.account ?? '';
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9.:-]*$').hasMatch(address) ||
        !RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*$').hasMatch(account)) {
      setState(() => _problem = 'The host stop did not name a valid address and account.');
      return;
    }
    final machine = Machine(
      name: widget.run.name,
      socketPath: '',
      kind: 'host',
      host: '$account@$address',
      identity: widget.run.record.identity,
    );
    setState(() {
      _terminalOpen = true;
      _problem = null;
    });
    int? code;
    try {
      await runInATerminal(
        context,
        title: 'Complete setup on ${machine.name}',
        explanation: 'Type the secrets into the host terminal. The Tresorit login asks again until it succeeds or you cancel, then the vault comes next.',
        machine: machine,
        command: [openSsh('ssh'), ...machine.loginSshOptions, '-t', machine.host, inTheLoginShell(line)],
        open: widget.openTerminal,
        showCommand: false,
        onExit: (value) => code = value,
        whatCameOfIt: () async => _outcome(code),
      );
      if (!mounted) return;
      if (code == 0) {
        unawaited(widget.hostRuns.resume(widget.run));
        if (ModalRoute.of(context)?.isActive ?? false) Navigator.pop(context);
      } else {
        setState(() => _problem = _outcome(code));
      }
    } finally {
      if (mounted) setState(() => _terminalOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.hostRuns,
    builder: (context, _) {
      final needs = widget.run.session.needs;
      final unknown = needs.where((need) => !const {'drive', 'vault', 'vault-new'}.contains(need));
      return AlertDialog(
        title: Text('Complete setup on ${widget.run.name}'),
        content: SizedBox(
          width: Sizes.dialogSmall,
          child: DialogScroll(
            child: Column(
              key: const Key('host-stop-fields'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (needs.isEmpty) const Text('The host waits without saying for what.'),
                if (needs.contains('drive')) const Text('The host needs a Tresorit login.'),
                if (needs.contains('vault-new')) const Text('The host needs a passphrase for its new vault.'),
                if (needs.contains('vault')) const Text('The host needs its vault unlocked.'),
                for (final need in unknown) Text('porelo-host waits for $need; this interface cannot answer it yet.'),
                if (needs.contains('drive')) ...[
                  const SizedBox(height: Space.small),
                  TextField(
                    key: const Key('host-drive-email'),
                    controller: _email,
                    enabled: !_terminalOpen,
                    decoration: const InputDecoration(labelText: 'Tresorit e-mail'),
                  ),
                ],
                if (_problem case final problem?) ...[const SizedBox(height: Space.small), Text(problem)],
                const SizedBox(height: Space.small),
                FilledButton(
                  key: const Key('host-open-terminal'),
                  onPressed: _terminalOpen || !widget.run.waiting || needs.isEmpty || unknown.isNotEmpty
                      ? null
                      : _openTerminal,
                  child: const Text('Open the terminal'),
                ),
                TextButton(
                  onPressed: _terminalOpen ? null : _showTheProtocol,
                  child: const Text('Show the setup protocol'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('host-stop-close'),
            onPressed: _terminalOpen ? null : () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
