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
import '../app/project_bring.dart';
import '../app/run_here.dart';
import '../app/session.dart';
import '../app/settings.dart';
import '../app/read_public_signing_key.dart';
import 'tokens.dart';
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

  @override
  State<ProjectBringDialog> createState() => _ProjectBringDialogState();
}

class _ProjectBringDialogState extends State<ProjectBringDialog> {
  late final _signingKey = TextEditingController(text: '${desk.home}/.ssh/id_ed25519.pub');
  late final _secretsFile = TextEditingController(text: widget.settings.secretsFile ?? '');
  final _values = TextEditingController();
  final _account = TextEditingController();
  late final _identity = TextEditingController(text: '${desk.home}/.ssh/id_ed25519');
  late final _inputs = Listenable.merge([_signingKey, _secretsFile, _values, _account, _identity]);
  ProjectBring? _bring;
  SecretStore? _store;
  String? _problem;
  bool _feeding = false;

  PreparedHost _host() {
    try {
      return PreparedHost.read(jsonDecode(_values.text));
    } on FormatException {
      throw const FormatException('Paste the complete public host values from the host admin as a JSON object.');
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
    unawaited(_store?.close());
    for (final controller in [_signingKey, _secretsFile, _values, _account, _identity]) {
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
      final identity = desk.expandHome(_identity.text.trim());
      if (_account.text.trim() == 'root' ||
          !path.isAbsolute(identity) ||
          FileSystemEntity.typeSync(identity, followLinks: false) != FileSystemEntityType.file) {
        throw const FormatException('Choose your own host account and a plain SSH identity file.');
      }
      final hostName = host.values['homeserver']!.split('.')[1];
      final machine = Machine(
        name: '${_account.text.trim()}@${host.vpnAddress}',
        socketPath: '',
        host: '${_account.text.trim()}@${host.vpnAddress}',
        kind: 'host',
        identity: identity,
        hostProject: hostName,
      );
      final knownHosts = '${poreloHostKnownHosts(environment: widget.environment)}.$hostName';
      if (widget.hostFiles == null) _store ??= SecretStore.forThisSystem();
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
        forgeCa: widget.settings.hostUp(host.values['homeserver']!.split('.')[1])?.forgeCa,
        accessRoot: widget.accessRoot ?? '${desk.data}/access',
        remote:
            widget.remote ??
            OpenSsh(
              knownHosts: File(knownHosts),
              identity: machine.identity,
              start: widget.startSsh,
              run: widget.runScp,
            ),
        files: widget.hostFiles ?? HostFiles(_store!),
        runGit: widget.runGit,
      )..addListener(_changed);
      setState(() {});
      await _bring!.bring();
      await _confirmedBring();
    } on FormatException catch (error) {
      if (mounted) setState(() => _problem = error.message);
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
        words: 'Paste the JSON the host admin copies from For the project admins. Give your admitted account name and your own SSH identity file. The connection uses the host’s VPN address and supplied SSH host key.',
        panel: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          spacing: Space.small,
          children: [
            _field(_account, 'Your admitted account name on the host', 'bring-account'),
            _field(_identity, 'Your SSH identity file', 'bring-identity'),
            _field(_values, 'Public host values (JSON)', 'bring-host-values', maxLines: null),
          ],
        ),
        check: () => _check(() {
          _host();
          checkAdminName(_account.text.trim());
          final identity = desk.expandHome(_identity.text.trim());
          if (_account.text.trim() == 'root' ||
              !path.isAbsolute(identity) ||
              FileSystemEntity.typeSync(identity, followLinks: false) != FileSystemEntityType.file) {
            throw const FormatException('Choose your own host account and a plain SSH identity file.');
          }
        }),
        summary: () => [
          'Your account: ${_account.text}',
          'SSH identity: ${_identity.text}',
          'Your pinned SSH host key and own identity; no sudo.',
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
        words: 'Choose your existing encrypted secrets file. Its master password is typed only in the stop’s terminal. Git uses your own configured credentials and commit signing.',
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
        words: 'Sign and push the private access settings, then upload both bundles and run the bring in your own account.',
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
