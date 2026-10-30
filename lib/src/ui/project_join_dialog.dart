import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart';

import '../app/access_join.dart';
import '../app/desk.dart';
import '../app/fleet_backend.dart';
import '../app/join_keys.dart';
import '../app/machines.dart';
import '../app/own_host_vpn.dart';
import '../app/project_join.dart';
import '../app/read_public_signing_key.dart';
import '../app/run_here.dart';
import '../app/session.dart';
import '../app/settings.dart';
import 'tokens.dart';
import 'host_forge_password.dart';
import 'own_host_vpn.dart';
import 'unlock_terminal.dart';
import 'wizard.dart';

/// Opens the developer's join without a host-admin file or privileged host account.
Future<void> openProjectJoinDialog(
  BuildContext context, {
  required String project,
  required FleetBackend backend,
  required Machines machines,
  required Settings settings,
  OpenTerminal? openTerminal,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => ProjectJoinDialog(
    project: project,
    backend: backend,
    machines: machines,
    settings: settings,
    openTerminal: openTerminal,
  ),
);

/// Checks signed access before offering this laptop's VPN and the own-account host stop.
class ProjectJoinDialog extends StatefulWidget {
  /// Allows process, store, and terminal replacements for the same join flow in tests.
  const ProjectJoinDialog({
    required this.project,
    required this.backend,
    required this.machines,
    required this.settings,
    this.openTerminal,
    this.store,
    this.files,
    this.run,
    this.remoteFor,
    this.environment,
    this.root,
    this.activateVpn,
    this.setForgePassword,
    this.restoreIdentity,
    this.targetBackend,
    super.key,
  });

  /// The followed project selected in the frame.
  final String project;

  /// The source daemon's verified follow.
  final FleetBackend backend;

  /// The watched accounts, extended only after a confirmed join.
  final Machines machines;

  /// The person's secrets-file choice and host VPN records.
  final Settings settings;

  /// The terminal used for the local sudo prompt and own-account stop.
  final OpenTerminal? openTerminal;

  /// The system store; tests supply their own.
  final SecretStore? store;

  /// The signed bundle builder; tests supply their own.
  final HostFiles? files;

  /// The local Git and Porelo process boundary.
  final RunHere? run;

  /// The pinned SSH transport factory.
  final Remote Function(String, String)? remoteFor;

  /// The runtime paths used by this desktop.
  final Map<String, String>? environment;

  /// The private join-state root.
  final String? root;

  /// The VPN boundary, replaced only in tests.
  final Future<bool> Function(AccessJoin, JoinPublicKeys, String, String)? activateVpn;

  /// The terminal-only lasting forge password boundary, replaced only in tests.
  final Future<bool> Function(Machine, String)? setForgePassword;

  /// The private runtime identity boundary, replaced only in tests.
  final Future<String> Function(String)? restoreIdentity;

  /// The host daemon after the playbook, replaced only in tests.
  final FleetBackend? targetBackend;

  @override
  State<ProjectJoinDialog> createState() => _ProjectJoinDialogState();
}

class _ProjectJoinDialogState extends State<ProjectJoinDialog> {
  late final _signing = TextEditingController(text: '${desk.home}/.ssh/id_ed25519.pub');
  late final _secrets = TextEditingController(text: widget.settings.secretsFile ?? '');
  late final _changes = Listenable.merge([_signing, _secrets]);
  SecretStore? _store;
  ProjectJoin? _join;
  String? _problem;
  bool _feeding = false;

  String? _check(void Function() check) {
    try {
      check();
      return null;
    } on FormatException catch (error) {
      return error.message;
    } on HostFilesRefused catch (error) {
      return error.message;
    } on FileSystemException {
      return 'Choose a readable plain file.';
    }
  }

  Future<void> _start() async {
    setState(() => _problem = null);
    try {
      _store ??= widget.store ?? SecretStore.forThisSystem();
      _join?.removeListener(_changed);
      _join?.dispose();
      _join = ProjectJoin(
        project: widget.project,
        backend: widget.backend,
        targetBackend: widget.targetBackend,
        files: widget.files ?? HostFiles(_store!),
        signingKey: File(desk.expandHome(_signing.text.trim())),
        keys: JoinKeys(_store!),
        root: widget.root ?? '${desk.data}/joins',
        secretsFile: desk.expandHome(_secrets.text.trim()),
        run: widget.run,
        environment: widget.environment,
        remoteFor: widget.remoteFor,
        restoreIdentity: widget.restoreIdentity,
        activateVpn: widget.activateVpn ?? _vpn,
        setForgePassword:
            widget.setForgePassword ??
            (machine, knownHosts) => openHostForgePassword(
              context,
              machine: machine,
              knownHosts: knownHosts,
              secretsFile: desk.expandHome(_secrets.text.trim()),
              openTerminal: widget.openTerminal,
            ),
      )..addListener(_changed);
      setState(() {});
      await _join!.join();
      await _confirmed();
    } on Exception {
      if (mounted) {
        setState(() => _problem = 'The join could not start. Check the system secret store and selected files.');
      }
    }
  }

  Future<bool> _vpn(AccessJoin access, JoinPublicKeys keys, String address, String ca) async {
    await connectOwnHostVpn(
      host: access.host,
      account: access.laptop(keys).account,
      keys: keys,
      address: address,
      ca: ca,
      settings: widget.settings,
      activate: (host, keys, address, ca) => openOwnHostVpn(
        context,
        host: host,
        keys: keys,
        address: address,
        ca: ca,
        settings: widget.settings,
        store: _store!,
        environment: widget.environment,
        openTerminal: widget.openTerminal,
      ),
    );
    return true;
  }

  Future<void> _feed() async {
    final runner = _join?.accountRun;
    final command = runner?.stopCommand;
    if (runner == null || command == null || _feeding) return;
    setState(() => _feeding = true);
    int? code;
    try {
      await runInATerminal(
        context,
        title: 'Give your own-account join its secrets',
        explanation: 'Type your secrets file’s master password in this terminal. Your requested vault passphrase, agent keys, and own forge token go directly to your host account.',
        machine: runner.machine,
        command: command,
        open: widget.openTerminal,
        showCommand: false,
        shownCommand: 'porelo-host-stop --stdin ${runner.needs.join(' ')}',
        onExit: (value) => code = value,
      );
      if (code == 0) {
        runner.stopFed(0);
        await runner.resume();
        await _join!.rememberJoined();
        await _confirmed();
      }
    } finally {
      if (mounted) setState(() => _feeding = false);
    }
  }

  Future<void> _confirmed() async {
    final join = _join;
    if (join == null || !join.joined) return;
    await widget.settings.rememberProjectHost(widget.project, join.access!.hostName);
    await widget.machines.add(join.accountRun!.machine);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _join?.removeListener(_changed);
    _join?.dispose();
    if (widget.store == null) unawaited(_store?.close());
    _signing.dispose();
    _secrets.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Wizard(
    title: 'Join ${widget.project} on its host',
    action: 'Join the project',
    changes: _changes,
    steps: [
      WizardStep(
        title: 'The project',
        words: 'Choose the public key already trusted for this project. Your own Git credentials must read its private access repository; accept its GitHub invitation first. The signed list supplies your account and this laptop’s address.',
        panel: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          spacing: Space.small,
          children: [
            Text(widget.project),
            TextField(
              key: const Key('join-signing-key'),
              controller: _signing,
              decoration: const InputDecoration(labelText: 'Project signing public key file'),
            ),
            TextButton(
              onPressed: () async {
                final file = await openFile();
                if (file != null && mounted) _signing.text = file.path;
              },
              child: const Text('Choose the public key file…'),
            ),
          ],
        ),
        check: () => _check(() => readPublicSigningKey(File(desk.expandHome(_signing.text.trim())))),
        summary: () => [
          widget.project,
          'Signing public key: ${_signing.text}',
          'Your signed access is verified before this laptop is set up.',
        ],
      ),
      WizardStep(
        title: 'Your secrets file',
        words: 'Choose your encrypted secrets file. Its master password is typed only in the terminal. Copy this laptop’s public keys for the host and have the project admin admit them before joining.',
        panel: (_) => TextField(
          key: const Key('join-secrets'),
          controller: _secrets,
          decoration: const InputDecoration(labelText: 'Secrets file path'),
        ),
        check: () => _check(() {
          final file = desk.expandHome(_secrets.text.trim());
          SecretsFile.checkPath(file);
          if (!File(file).existsSync()) throw const FormatException('Choose your existing encrypted secrets file.');
        }),
        summary: () => ['Secrets file: ${_secrets.text}', 'Join in your listed host account.'],
      ),
    ],
    actionSteps: [
      WizardActionStep(
        title: 'Join the project',
        words: 'Verify signed access, connect this laptop, then run the join in your own host account.',
        run: _start,
        state: () => _problem != null || _join?.problem != null || _join?.accountRun?.problem != null
            ? WizardActionState.refused
            : _join?.accountRun?.stopCommand != null
            ? WizardActionState.waiting
            : _join?.busy == true || _join?.accountRun?.busy == true
            ? WizardActionState.running
            : _join?.joined == true
            ? WizardActionState.done
            : WizardActionState.refused,
        panel: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Space.small,
          children: [
            if (_problem ?? _join?.problem ?? _join?.accountRun?.problem case final problem?)
              SelectableText(problem, key: const Key('join-problem')),
            if (_join?.busy == true) const Text('Checking access and joining in your own host account.'),
            if (_join?.joined == true)
              const Text(
                'You joined the project. Your host account is now watched; start its agents from the project menu.',
              ),
            if (_join?.accountRun case final runner? when runner.lastLines.isNotEmpty)
              SelectableText(runner.lastLines.join('\n')),
            if (_join?.accountRun?.stopCommand != null)
              FilledButton(
                key: const Key('join-feed-stop'),
                onPressed: _feeding ? null : _feed,
                child: Text('Open the secrets terminal: ${_join!.accountRun!.needs.join(', ')}'),
              ),
          ],
        ),
      ),
    ],
  );
}

/// Copies this laptop's host-specific public halves after an explicit host choice.
Future<void> openCopyJoinKeysDialog(BuildContext context, {SecretStore? store, CopyToClipboard? copy}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CopyJoinKeysDialog(store: store, copy: copy),
  );
}

class _CopyJoinKeysDialog extends StatefulWidget {
  const _CopyJoinKeysDialog({this.store, this.copy});
  final SecretStore? store;
  final CopyToClipboard? copy;
  @override
  State<_CopyJoinKeysDialog> createState() => _CopyJoinKeysDialogState();
}

class _CopyJoinKeysDialogState extends State<_CopyJoinKeysDialog> {
  final _host = TextEditingController();
  String? _problem;
  String? _copied;
  bool _busy = false;

  Future<void> _copy() async {
    setState(() {
      _busy = true;
      _problem = null;
      _copied = null;
    });
    SecretStore? opened;
    try {
      final host = _host.text.trim();
      checkHostName(host);
      opened = widget.store ?? SecretStore.forThisSystem();
      await (widget.copy ?? copyToClipboard)(await JoinKeys(opened).block(host));
      if (mounted) setState(() => _copied = host);
    } on FormatException catch (error) {
      if (mounted) setState(() => _problem = error.message);
    } on Exception {
      if (mounted) setState(() => _problem = 'The system secret store could not keep or read this laptop’s host keys.');
    } finally {
      if (widget.store == null) await opened?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Copy my public keys for a host'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: Space.small,
      children: [
        const Text(
          'Use the server name the project admin gives you, such as orchard. Send the copied public block to that admin. This computer keeps the private halves in its system secret store.',
        ),
        TextField(
          key: const Key('join-keys-host'),
          controller: _host,
          decoration: const InputDecoration(labelText: 'Host name'),
        ),
        if (_problem != null) Text(_problem!),
        if (_copied != null) Text('Public keys for $_copied copied.'),
      ],
    ),
    actions: [
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Close')),
      FilledButton(
        key: const Key('join-keys-copy'),
        onPressed: _busy ? null : _copy,
        child: const Text('Copy my public keys'),
      ),
    ],
  );
}
