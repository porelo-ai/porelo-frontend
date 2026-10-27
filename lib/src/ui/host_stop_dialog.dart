import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart';

import '../app/host_stop_feed.dart';
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

/// Public setup answers only; secrets go directly into the host script's terminal.
class HostStopDialog extends StatefulWidget {
  /// Observes the run owned by the frame without taking ownership of it.
  const HostStopDialog({
    required this.run,
    required this.hostRuns,
    required this.machines,
    this.settings,
    this.openTerminal,
    this.needs,
    super.key,
  });

  /// What `up`'s refusal named, given on its own call before `up` runs again; null for the stop's own needs.
  final List<String>? needs;

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
    if (widget.run.waiting || widget.needs != null || !mounted) return;
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
    if (_terminalOpen || (!widget.run.waiting && widget.needs == null)) return;
    final session = widget.run.session;
    final needs = widget.needs ?? session.needs;
    final secrets = widget.settings?.secretsFile;
    final fromTheFile = secrets != null && needs.any(SecretsFile.stopNeeds.contains);
    final String line;
    try {
      line = fromTheFile ? '' : hostStopCommand(needs, email: _email.text);
    } on FormatException catch (error) {
      setState(() => _problem = error.message);
      return;
    }
    final address = session.address ?? '';
    final account = session.account ?? '';
    // The account is the terminal's at the host, as today's stop and the drive's login run; the file's call needs none.
    final needsTheAccount = !fromTheFile || needs.contains('drive');
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9.:-]*$').hasMatch(address) ||
        (needsTheAccount && !RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*$').hasMatch(account))) {
      setState(() => _problem = 'The host stop did not name a valid address and account.');
      return;
    }
    // The `--stdin` call runs as the host's own login user, whose passwordless sudo `up` relies on too.
    final admin = session.admin ?? '';
    if (fromTheFile && !RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*$').hasMatch(admin)) {
      setState(() => _problem = 'The host did not name the user its stop runs as.');
      return;
    }
    final machine = Machine(
      name: widget.run.name,
      socketPath: '',
      kind: 'host',
      host: '${fromTheFile ? admin : account}@$address',
      identity: widget.run.record.identity,
    );
    final List<String> command;
    try {
      command = fromTheFile
          ? hostStopFeedCommand(
              secretsFile: secrets,
              project: widget.run.project,
              needs: needs,
              email: _email.text,
              ssh: openSsh('ssh'),
              sshOptions: machine.loginSshOptions,
              host: machine.host,
              driveHost: '$account@$address',
            )
          : [openSsh('ssh'), ...machine.loginSshOptions, '-t', machine.host, inTheLoginShell(line)];
    } on FormatException catch (error) {
      setState(() => _problem = error.message);
      return;
    } on HostFilesRefused catch (error) {
      setState(() => _problem = error.message);
      return;
    }
    setState(() {
      _terminalOpen = true;
      _problem = null;
    });
    int? code;
    try {
      await runInATerminal(
        context,
        title: 'Complete setup on ${machine.name}',
        explanation: fromTheFile
            ? 'Type the master password of your secrets file here; the host gets what it named from the file, on '
                  'standard input, and nothing is shown.${needs.contains('drive') ? ' The Tresorit login comes first, on the host.' : ''}'
            : 'Type the secrets into the host terminal. The Tresorit login asks again until it succeeds or you cancel, then the vault comes next.',
        machine: machine,
        command: command,
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
    // The settings too: a secrets file named meanwhile makes the file's needs answerable here.
    listenable: Listenable.merge([widget.hostRuns, ?widget.settings]),
    builder: (context, _) {
      final needs = widget.needs ?? widget.run.session.needs;
      final file = widget.settings?.secretsFile != null;
      // With the secrets file the host takes its secrets on standard input; without it only what is typed there.
      final answerable = file
          ? <String>{'drive', ...SecretsFile.stopNeeds}
          : const <String>{'drive', 'vault', 'vault-new'};
      final unknown = needs.where((need) => !answerable.contains(need));
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
                if (needs.contains('wireguard')) const Text('The host needs its VPN key.'),
                if (needs.contains('keys')) const Text('The host needs the files of its vault entries.'),
                if (needs.contains('forge-central-token'))
                  const Text('The host needs the central forge\'s token, to bring a repository over from it.'),
                if (file && needs.any(SecretsFile.stopNeeds.contains))
                  const Text(
                    'They come from your secrets file: type its master password once, in the terminal on this computer.',
                  ),
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
                  onPressed:
                      _terminalOpen ||
                          (!widget.run.waiting && widget.needs == null) ||
                          needs.isEmpty ||
                          unknown.isNotEmpty
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
