import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart';

import '../app/host_stop_feed.dart';
import '../app/host_runs.dart';
import '../app/machines.dart';
import '../app/session.dart';
import '../app/host_vpn.dart';
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
    // The host's matrix token comes from this computer's own Porelo, by the same feed, with or without the file.
    final fromTheFile =
        (secrets != null && needs.any(SecretsFile.stopNeeds.contains)) || needs.contains('matrix-token');
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
    // The lasting CA's certificate comes back public, beside the forge's own: kept for this desktop to trust.
    final forgeCa = fromTheFile && needs.contains('forge-certificate')
        ? Directory.systemTemp.createTempSync('porelo-forge-ca-')
        : null;
    final List<String> command;
    try {
      command = fromTheFile
          ? hostStopFeedCommand(
              secretsFile: secrets ?? '',
              project: widget.run.project,
              needs: needs,
              keys: widget.run.record.vaultKeys,
              email: _email.text,
              // The program that gets every secret on its standard input, by its path: the feed runs on Linux only.
              ssh: '/usr/bin/ssh',
              sshOptions: machine.loginSshOptions,
              host: machine.host,
              driveHost: '$account@$address',
              caOut: forgeCa == null ? null : '${forgeCa.path}/ca.pem',
            )
          : [openSsh('ssh'), ...machine.loginSshOptions, '-t', machine.host, inTheLoginShell(line)];
    } on FormatException catch (error) {
      forgeCa?.deleteSync(recursive: true);
      setState(() => _problem = error.message);
      return;
    } on HostFilesRefused catch (error) {
      forgeCa?.deleteSync(recursive: true);
      setState(() => _problem = error.message);
      return;
    } catch (_) {
      forgeCa?.deleteSync(recursive: true);
      rethrow;
    }
    setState(() {
      _terminalOpen = true;
      _problem = null;
    });
    // Said where this stop signs with the lasting CA, which is where a new one is made.
    final caWarning = needs.contains('forge-certificate')
        ? forgeCaWarning(widget.settings?.forgeCa, DateTime.now(), atTheStop: true)
        : null;
    int? code;
    try {
      await runInATerminal(
        context,
        title: 'Complete setup on ${machine.name}',
        explanation: fromTheFile
            ? 'Type the master password of your secrets file here; the host gets what it named from the file, on '
                  'standard input, and nothing is shown.${needs.contains('drive') ? ' The Tresorit login comes first, on the host.' : ''}'
                  '${caWarning == null ? '' : ' $caWarning'}'
            : 'Type the secrets into the host terminal. The Tresorit login asks again until it succeeds or you cancel, then the vault comes next.',
        machine: machine,
        command: command,
        open: widget.openTerminal,
        showCommand: false,
        onExit: (value) => code = value,
        whatCameOfIt: () async => _outcome(code),
      );
      final ca = forgeCa == null ? null : File('${forgeCa.path}/ca.pem');
      if (code == 0 && ca != null && ca.existsSync()) {
        final pem = ca.readAsStringSync();
        if (Settings.isCertificate(pem)) await widget.settings?.rememberForgeCa(pem);
      }
      if (!mounted) return;
      if (code == 0) {
        unawaited(widget.hostRuns.resume(widget.run));
        if (ModalRoute.of(context)?.isActive ?? false) Navigator.pop(context);
      } else {
        setState(() => _problem = _outcome(code));
      }
    } finally {
      if (forgeCa?.existsSync() ?? false) forgeCa!.deleteSync(recursive: true);
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
      // Host files given by hand, in a setup from before the interface wrote them, carry the person's own VPN key,
      // which the file does not keep.
      final byHand = widget.run.record.folder == null && widget.run.record.setupFolder == null;
      // The host's matrix token comes from this computer's own Porelo, with the file or without it.
      final answerable = file
          ? <String>{'drive', 'matrix-token', ...SecretsFile.stopNeeds}.difference({if (byHand) 'wireguard'})
          : const <String>{'drive', 'vault', 'vault-new', 'matrix-token'};
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
                if (needs.contains('forge-certificate'))
                  const Text(
                    'The host\'s forge needs its certificate: signed on this computer by your lasting CA, whose key '
                    'stays in your secrets file. The first time, the CA is made there.',
                  ),
                if (needs.contains('matrix-token'))
                  const Text(
                    'The host needs its token for this computer\'s homeserver: this computer lets it into the '
                    'project\'s conversation, and the token goes to the host on standard input, never shown.',
                  ),
                if (needs.contains('forge-central-token'))
                  const Text(
                    'The host needs the central forge\'s token, to bring a repository over from it. Your secrets file '
                    'keeps it in the entry shared/forge-central-token: add it there in KeePassXC first.',
                  ),
                if (file && needs.any(SecretsFile.stopNeeds.contains))
                  const Text(
                    'They come from your secrets file: type its master password once, in the terminal on this computer.',
                  ),
                for (final need in unknown)
                  Text(
                    SecretsFile.stopNeeds.contains(need)
                        ? 'porelo-host waits for $need, which comes from your secrets file; this computer has none '
                              'named yet. Take the server down and put it on a server again, naming it.'
                        : 'porelo-host waits for $need; this interface cannot answer it yet.',
                  ),
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
