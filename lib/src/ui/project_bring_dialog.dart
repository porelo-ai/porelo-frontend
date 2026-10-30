import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:path/path.dart' as path;

import '../app/desk.dart';
import '../app/fleet_backend.dart';
import '../app/machines.dart';
import '../app/host_matrix_settings.dart';
import '../app/join_keys.dart';
import '../app/own_host_vpn.dart';
import '../app/project_bring.dart';
import '../app/run_here.dart';
import '../app/session.dart';
import '../app/settings.dart';
import '../app/read_public_signing_key.dart';
import 'tokens.dart';
import 'host_forge_password.dart';
import 'own_host_vpn.dart';
import 'unlock_terminal.dart';
import 'wizard.dart';

/// Brings a followed project onto a prepared host through the admitted person's own SSH account.
class ProjectBringDialog extends StatefulWidget {
  /// Accepts transport and Git stand-ins without changing the host's security policy.
  const ProjectBringDialog({
    required this.project,
    required this.machines,
    required this.settings,
    required this.backend,
    this.remote,
    this.startSsh,
    this.runGit,
    this.hostFiles,
    this.accessRoot,
    this.openTerminal,
    this.environment,
    this.runScp,
    this.targetBackend,
    this.store,
    this.restoreIdentity,
    this.activateVpn,
    super.key,
  });

  /// The verified, followed project.
  final String project;

  /// Already watched machines to refresh after a confirmed bring.
  final Machines machines;

  /// The person's secrets-file choice and prepared-host public values.
  final Settings settings;

  /// The daemon that verified the selected project commit.
  final FleetBackend backend;

  /// The SSH boundary; pinned OpenSSH by default.
  final Remote? remote;

  /// Starts the pinned SSH process; defaults to the system transport.
  final Future<Process> Function(String, List<String>)? startSsh;

  /// The person's own Git; replaceable in tests.
  final RunHere? runGit;

  /// The signed bundle builder; replaceable in tests.
  final HostFiles? hostFiles;

  /// The private access root; the person's frontend data directory by default.
  final String? accessRoot;

  /// The terminal carrying the secrets-file feed.
  final OpenTerminal? openTerminal;

  /// Isolates the host-specific SSH state in tests.
  final Map<String, String>? environment;

  /// Replaces only scp's process in transport tests.
  final Future<ProcessResult> Function(String, List<String>)? runScp;

  /// Replaces the post-bring daemon check in widget tests.
  final FleetBackend? targetBackend;

  /// The laptop keys' system store; replaced only in tests.
  final SecretStore? store;

  /// Restores the copied keys' own runtime identity; replaced only in tests.
  final Future<String> Function(String)? restoreIdentity;

  /// The shared VPN terminal boundary; replaced only in tests.
  final ActivateOwnHostVpn? activateVpn;

  @override
  State<ProjectBringDialog> createState() => _ProjectBringDialogState();
}

class _ProjectBringDialogState extends State<ProjectBringDialog> {
  late final _signingKey = TextEditingController(text: '${desk.home}/.ssh/id_ed25519.pub');
  late final _secretsFile = TextEditingController(text: widget.settings.secretsFile ?? '');
  final _values = TextEditingController();
  final _account = TextEditingController();
  late final _identity = TextEditingController(text: '${desk.home}/.ssh/id_ed25519');
  final _vpnAddress = TextEditingController();
  late final _inputs = Listenable.merge([_signingKey, _secretsFile, _values, _account, _identity, _vpnAddress]);
  ProjectBring? _bring;
  SecretStore? _store;
  String? _problem;
  bool _feeding = false;

  PreparedHost _host() {
    final Object? decoded;
    try {
      decoded = jsonDecode(_values.text);
    } on FormatException {
      throw const FormatException('Paste the complete public host values from the host admin as a JSON object.');
    }
    return PreparedHost.read(decoded);
  }

  HostUpRecord? get _record {
    try {
      return widget.settings.hostUp(_host().values['homeserver']!.split('.')[1]);
    } on FormatException {
      return null;
    }
  }

  String? get _roomAlias {
    try {
      return hostProjectRoom(widget.project, _host());
    } on FormatException {
      return null;
    }
  }

  String? _check(void Function() check) {
    try {
      check();
      return null;
    } on FormatException catch (error) {
      return error.message;
    } on HostFilesRefused catch (error) {
      return error.message;
    } on FileSystemException {
      return 'Choose a readable public signing key file.';
    }
  }

  @override
  void dispose() {
    _bring?.removeListener(_changed);
    _bring?.dispose();
    if (widget.store == null) unawaited(_store?.close());
    for (final controller in [_signingKey, _secretsFile, _values, _account, _identity, _vpnAddress]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    setState(() => _problem = null);
    try {
      final host = _host();
      checkAdminName(_account.text.trim());
      final hostName = host.values['homeserver']!.split('.')[1];
      final needsVpn = _record == null;
      if (_account.text.trim() == 'root') throw const FormatException('Use your admitted own account for this host.');
      if (needsVpn) checkBringVpnAddress(_vpnAddress.text.trim(), host.network);
      if (needsVpn || widget.hostFiles == null) _store ??= widget.store ?? SecretStore.forThisSystem();
      final keys = needsVpn ? JoinKeys(_store!) : null;
      final identity = needsVpn
          ? await (widget.restoreIdentity?.call(hostName) ?? keys!.identity(hostName, environment: widget.environment))
          : desk.expandHome(_identity.text.trim());
      if (_account.text.trim() == 'root' ||
          !path.isAbsolute(identity) ||
          FileSystemEntity.typeSync(identity, followLinks: false) != FileSystemEntityType.file) {
        throw const FormatException('Choose your own host account and a plain SSH identity file.');
      }
      if (needsVpn) _identity.text = identity;
      final machine = Machine(
        name: '${_account.text.trim()}@${host.vpnAddress}',
        socketPath: '',
        host: '${_account.text.trim()}@${host.vpnAddress}',
        kind: 'host',
        identity: identity,
        hostProject: hostName,
      );
      final knownHosts = '${poreloHostKnownHosts(environment: widget.environment)}.$hostName';
      final remote =
          widget.remote ??
          OpenSsh(knownHosts: File(knownHosts), identity: machine.identity, start: widget.startSsh, run: widget.runScp);
      _bring?.removeListener(_changed);
      _bring?.dispose();
      _bring = ProjectBring(
        project: widget.project,
        backend: widget.backend,
        targetBackend: widget.targetBackend,
        machine: machine,
        host: host,
        knownHosts: knownHosts,
        secretsFile: desk.expandHome(_secretsFile.text.trim()),
        signingKey: File(desk.expandHome(_signingKey.text.trim())),
        forgeCa: _record?.forgeCa,
        connectVpn: needsVpn
            ? () async => connectOwnHostVpn(
                host: host,
                account: _account.text.trim(),
                keys: await keys!.publicKeys(hostName),
                address: _vpnAddress.text.trim(),
                settings: widget.settings,
                activate:
                    widget.activateVpn ??
                    (host, keys, address, ca) => openOwnHostVpn(
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
                fetchCa: () =>
                    fetchOwnHostCa(host: host, account: _account.text.trim(), knownHosts: knownHosts, remote: remote),
              )
            : null,
        accessRoot: widget.accessRoot ?? '${desk.data}/access',
        remote: remote,
        files: widget.hostFiles ?? HostFiles(_store!),
        setForgePassword: (machine, knownHosts) => openHostForgePassword(
          context,
          machine: machine,
          knownHosts: knownHosts,
          secretsFile: desk.expandHome(_secretsFile.text.trim()),
          openTerminal: widget.openTerminal,
        ),
        runGit: widget.runGit,
      )..addListener(_changed);
      setState(() {});
      await _bring!.bring();
      await _confirmedBring();
    } on FormatException catch (error) {
      if (mounted) setState(() => _problem = error.message);
    } on WorkspaceRefused catch (error) {
      if (mounted) setState(() => _problem = error.words);
    } on Exception {
      if (mounted) setState(() => _problem = 'The bring could not start. Check the public host values and file paths.');
    }
  }

  Future<void> _feed() async {
    final bring = _bring!;
    final command = bring.stopCommand;
    if (command == null || _feeding) return;
    setState(() => _feeding = true);
    int? code;
    try {
      await runInATerminal(
        context,
        title: 'Give the project’s own-account stop its secrets',
        explanation: 'Type the master password of your secrets file in this terminal. The requested vault passphrase, keys, and central forge token go straight to your own host account on standard input.',
        machine: bring.machine,
        command: command,
        open: widget.openTerminal,
        showCommand: false,
        shownCommand: 'porelo-host-stop --stdin ${bring.needs.join(' ')}',
        onExit: (value) => code = value,
      );
      if (code == 0) {
        bring.stopFed(0);
        await bring.resume();
        await _confirmedBring();
      }
    } finally {
      if (mounted) setState(() => _feeding = false);
    }
  }

  Future<void> _confirmedBring() async {
    final bring = _bring;
    if (bring == null || !bring.brought) return;
    final host = bring.host.values['homeserver']!.split('.')[1];
    try {
      await widget.settings.rememberProjectHost(widget.project, host);
    } on Exception {
      if (mounted) {
        setState(() => _problem = 'The project is on the server, but its host association could not be kept.');
      }
      return;
    }
    for (final watched in widget.machines.all.where((machine) => machine.host == bring.machine.host)) {
      await widget.machines.of(watched).refresh(quietly: true);
    }
  }

  Widget _field(TextEditingController controller, String label, String key, {int? maxLines = 1}) => TextField(
    key: Key(key),
    controller: controller,
    maxLines: maxLines,
    decoration: InputDecoration(labelText: label),
  );

  @override
  Widget build(BuildContext context) => Wizard(
    title: 'Put ${widget.project} on a server',
    action: 'Bring the project',
    changes: _inputs,
    steps: [
      WizardStep(
        title: 'The project',
        words: 'The daemon’s verified project revision supplies the repositories and the private access repository. Choose the public key that signed it.',
        panel: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          spacing: Space.small,
          children: [
            Text(widget.project),
            _field(_signingKey, 'Project signing public key file', 'bring-signing-key'),
            TextButton(
              onPressed: () async {
                final selected = await openFile();
                if (selected != null && mounted) _signingKey.text = selected.path;
              },
              child: const Text('Choose the public key file…'),
            ),
          ],
        ),
        check: () => _check(() {
          HostFiles.checkProjectName(widget.project);
          final key = File(desk.expandHome(_signingKey.text.trim()));
          if (FileSystemEntity.typeSync(key.path, followLinks: false) != FileSystemEntityType.file) {
            throw const FormatException('Choose a plain public signing key file.');
          }
          readPublicSigningKey(key);
        }),
        summary: () => [widget.project, 'Signing public key: ${_signingKey.text}'],
      ),
      WizardStep(
        title: 'The server',
        words: 'Paste the JSON the host admin copies from For the project admins. Give your admitted account name. A new connection uses the keys Copy my public keys for a host… made on this machine; an existing connection uses your own SSH identity file.',
        panel: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          spacing: Space.small,
          children: [
            _field(_account, 'Your admitted account name on the host', 'bring-account'),
            if (_record != null) _field(_identity, 'Your SSH identity file', 'bring-identity'),
            _field(_values, 'Public host values (JSON)', 'bring-host-values', maxLines: null),
          ],
        ),
        check: () => _check(() {
          _host();
          checkAdminName(_account.text.trim());
          if (_account.text.trim() == 'root') {
            throw const FormatException('Use your admitted own account for this host.');
          }
          if (_record != null) {
            final identity = desk.expandHome(_identity.text.trim());
            if (!path.isAbsolute(identity) ||
                FileSystemEntity.typeSync(identity, followLinks: false) != FileSystemEntityType.file) {
              throw const FormatException('Choose your own host account and a plain SSH identity file.');
            }
          }
        }),
        summary: () => [
          'Your account: ${_account.text}',
          _record == null ? 'Use this machine’s copied host keys.' : 'SSH identity: ${_identity.text}',
          'Your pinned SSH host key and own identity.',
        ],
      ),
      WizardStep(
        title: 'This machine’s VPN',
        words: 'For a new host, enter the VPN address assigned to this machine, such as 10.73.<network>.<peer>. It must differ from the host’s .1 and the host admin’s .2. Copy this machine’s public keys for the host and have them admitted first. After you start, connect in the sudo terminal, then trust the CA only after its fingerprint matches.',
        panel: (_) => _record == null
            ? _field(_vpnAddress, 'This machine’s address on the host VPN', 'bring-vpn-address')
            : const Text('This host is already recorded. Keep its VPN up to bring the project.'),
        check: () => _check(() {
          final host = _host();
          if (_record == null) checkBringVpnAddress(_vpnAddress.text.trim(), host.network);
        }),
        summary: () => [
          _record == null ? 'This machine’s VPN address: ${_vpnAddress.text}' : 'Use the recorded host’s VPN and CA.',
        ],
      ),
      WizardStep(
        title: 'The project’s room',
        words: 'The bring makes this project’s fixed room alias on the host admin’s Matrix server. Its CA comes from the trusted certificate kept for this host. The admission token stays in your own account on the host.',
        panel: (_) => SelectableText(_roomAlias ?? 'Choose the host first.', key: const Key('bring-room')),
        check: () => _check(_host),
        summary: () => [
          'Room: ${_roomAlias ?? 'Choose the host first.'}',
          'Host and Matrix settings are signed and pushed in access.yml only.',
        ],
      ),
      WizardStep(
        title: 'Your secrets file',
        words: 'Choose your existing encrypted secrets file. Its master password and your lasting forge password are typed only in the terminal. Set your own forge login’s password before the bring; Git uses your own configured credentials and commit signing.',
        panel: (_) => _field(_secretsFile, 'Secrets file path', 'bring-secrets'),
        check: () => _check(() {
          final file = desk.expandHome(_secretsFile.text.trim());
          SecretsFile.checkPath(file);
          if (!File(file).existsSync()) throw const FormatException('Choose your existing encrypted secrets file.');
        }),
        summary: () => ['Secrets file: ${_secretsFile.text}', 'The playbook syncs once and makes the room.'],
      ),
    ],
    actionSteps: [
      WizardActionStep(
        title: 'Bring the project',
        words: 'Set your lasting forge password after connecting and checking the CA, then sign and push the private access settings, upload both bundles, and run the bring in your own account.',
        panel: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          spacing: Space.small,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_problem ?? _bring?.problem case final problem?) SelectableText(problem),
            if (_bring?.brought == true) const Text('The project is on the server.'),
            if (_bring?.busy == true) const Text('The bring is running in your own host account.'),
            if (_bring case final bring? when bring.lastLines.isNotEmpty)
              SelectableText(bring.lastLines.join('\n'), key: const Key('bring-last-lines')),
            if (_bring?.stopCommand != null)
              FilledButton(
                key: const Key('bring-feed-stop'),
                onPressed: _feeding ? null : _feed,
                child: Text('Open the secrets terminal: ${_bring!.needs.join(', ')}'),
              ),
          ],
        ),
        run: _start,
        state: () => _problem != null
            ? WizardActionState.refused
            : _bring?.stopCommand != null
            ? WizardActionState.waiting
            : _bring?.busy == true
            ? WizardActionState.running
            : _bring?.brought == true
            ? WizardActionState.done
            : WizardActionState.refused,
      ),
    ],
  );
}
