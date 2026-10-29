import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:porelo_host/porelo_host.dart';

import '../app/commands.dart';
import '../app/machines.dart';
import '../app/session.dart';
import '../app/settings.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';
import 'unlock_terminal.dart';
import 'wizard.dart';

/// Opens a checked root helper call using the rental's pinned SSH identity; [environment] isolates its state in tests.
Future<void> openHostAdminDialog(
  BuildContext context, {
  required HostUpRecord record,
  required String action,
  String? project,
  OpenTerminal? openTerminal,
  String? secretsFile,
  Map<String, String>? environment,
}) {
  final host = record.preparedHost!;
  final (:remote, :trust) = hostAdminRemote(record, environment: environment);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => HostAdminDialog(
      host: host,
      action: action,
      project: project,
      openTerminal: openTerminal,
      remote: remote,
      secretsFile: secretsFile,
      identity: record.identity,
      knownHosts: remote.knownHosts.path,
      prepareRemote: trust,
    ),
  );
}

/// Builds the rental's SSH remote for [record]'s host helpers with a trust file of this host alone, and the step
/// that pins the host's key there at its VPN address, the only address the helpers are reached on.
({OpenSsh remote, Future<void> Function() trust}) hostAdminRemote(
  HostUpRecord record, {
  Map<String, String>? environment,
}) {
  final host = record.preparedHost!;
  final remote = OpenSsh(
    knownHosts: File('${poreloHostKnownHosts(environment: environment)}.${record.hostName}'),
    identity: record.identity,
  );
  return (remote: remote, trust: () => remote.trust(host.vpnAddress, host.values['ssh_host_key']!));
}

/// Public completion values, each with its own copy action.
class PreparedHostPanel extends StatelessWidget {
  /// Shows only values validated from the host's completion record.
  const PreparedHostPanel({required this.host, super.key});

  /// The checked values the host returned.
  final PreparedHost host;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: Space.small,
    children: [
      Text('For the project admins', style: Theme.of(context).textTheme.titleMedium),
      const Text(
        'Share these public values for the project access file. They also live on the server in /etc/porelo-host/host.json.',
      ),
      for (final entry in {...host.values, 'SSH fingerprint': host.fingerprint}.entries)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: SelectableText('${entry.key}: ${entry.value}')),
            Builder(
              builder: (_) {
                final command = copyHostValueCommand(
                  entry.key,
                  () => unawaited(Clipboard.setData(ClipboardData(text: entry.value))),
                );
                return IconButton(
                  key: ValueKey('host-copy ${entry.key}'),
                  tooltip: command.label,
                  onPressed: command.run,
                  icon: const Icon(Icons.copy_outlined),
                );
              },
            ),
          ],
        ),
    ],
  );
}

/// Opens the retained public values without repeating preparation.
Future<void> showPreparedHost(BuildContext context, PreparedHost host) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('For the project admins'),
    content: SizedBox(
      width: Sizes.dialogSmall,
      child: DialogScroll(child: PreparedHostPanel(host: host)),
    ),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
  ),
);

/// A reviewable host helper operation; only public key halves enter its fields.
class HostAdminDialog extends StatefulWidget {
  /// Uses an injected remote for tests and the rental identity in the app.
  const HostAdminDialog({
    required this.host,
    required this.action,
    required this.remote,
    this.project,
    this.prepareRemote,
    this.secretsFile,
    this.identity = '',
    this.knownHosts = '',
    this.openTerminal,
    super.key,
  });

  /// The prepared host's checked connection values.
  final PreparedHost host;

  /// Register, remove, admit, lock, or purge.
  final String action;

  /// The project fixed by its menu action, absent for the host's general helper panel.
  final String? project;

  /// Carries a checked helper command without a terminal or a login shell.
  final Remote remote;

  /// Pins this server's checked public host key separately from other rentals.
  final Future<void> Function()? prepareRemote;

  /// The public path of the secrets file chosen during preparation.
  final String? secretsFile;

  /// The rental key used by the removal terminal's root SSH connection.
  final String identity;

  /// The host's pinned SSH trust file used by the removal terminal.
  final String knownHosts;

  /// Replaces the removal terminal in widget tests.
  final OpenTerminal? openTerminal;

  @override
  State<HostAdminDialog> createState() => _HostAdminDialogState();
}

class _HostAdminDialogState extends State<HostAdminDialog> {
  late final _name = TextEditingController(text: widget.project ?? '');
  final _admin = TextEditingController();
  final _key = TextEditingController();
  final _block = TextEditingController();
  WizardActionState _state = WizardActionState.refused;
  String? _answer;
  String? _refusal;

  String get _title => switch (widget.action) {
    'register' => 'Register a project',
    'remove' => 'Take the project off',
    'admit' => 'Admit a project admin',
    'lock' => 'Lock a project admin',
    'purge' => 'Purge a project admin',
    _ => throw ArgumentError.value(widget.action),
  };
  bool get _project => widget.action == 'register' || widget.action == 'remove';
  // Only these two take public keys; the others take a name alone.
  bool get _keys => widget.action == 'register' || widget.action == 'admit';

  @override
  void dispose() {
    for (final field in [_name, _admin, _key, _block]) {
      field.dispose();
    }
    super.dispose();
  }

  String? _check(void Function() check) {
    try {
      check();
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  WizardStep _step(
    String title,
    String words,
    TextEditingController field,
    String key,
    void Function() check, {
    bool multiline = false,
  }) => WizardStep(
    title: title,
    words: words,
    panel: (_) => TextField(
      key: Key(key),
      controller: field,
      readOnly: identical(field, _name) && widget.project != null,
      minLines: multiline ? 3 : 1,
      maxLines: multiline ? null : 1,
      decoration: InputDecoration(labelText: title),
    ),
    check: () => _check(check),
    summary: () => ['$title: ${field.text}'],
  );

  HostAdminRequest _request() => switch (widget.action) {
    'register' => HostAdminRequest.register(_name.text, _admin.text, _key.text),
    'admit' => HostAdminRequest.admit(_name.text, _block.text, widget.host.network),
    'remove' => HostAdminRequest.remove('project', 'remove', _name.text),
    'lock' || 'purge' => HostAdminRequest.remove('person', widget.action, _name.text),
    _ => throw ArgumentError.value(widget.action),
  };

  Future<String> _removeProject(HostAdminRequest request) async {
    final secrets = widget.secretsFile;
    if (secrets == null) throw const FormatException('No secrets file was kept from server preparation.');
    if (widget.openTerminal == null) {
      if (keepassxcCliMissing() case final missing?) throw FormatException(missing);
    }
    final reply = await Directory.systemTemp.createTemp('porelo-project-removal-');
    try {
      final command = projectRemovalFeedCommand(
        project: _name.text,
        secretsFile: SecretsFile(secrets),
        host: widget.host,
        identity: widget.identity,
        knownHosts: widget.knownHosts,
        replyDirectory: reply.path,
      );
      if (!mounted) throw const FormatException('The project removal dialog was closed.');
      int? exitCode;
      await runInATerminal(
        context,
        title: 'Take ${_name.text} off the server',
        explanation: 'Type the master password of your secrets file here. Its shared/forge-central-token entry goes to the host on standard input. If the entry is missing, nothing is sent; the host decides whether it needs the token. The host refuses a repository with no central home.',
        machine: Machine(name: widget.host.vpnAddress, socketPath: ''),
        command: command,
        open: widget.openTerminal,
        showCommand: false,
        shownCommand: 'ssh root@${widget.host.vpnAddress} ${request.command}',
        onExit: (code) => exitCode = code,
        completed: 'The helper has answered. Close this terminal to read its answer.',
      );
      if (exitCode == null) {
        throw const FormatException('The terminal was closed before the host confirmed project removal.');
      }
      // Two small files the terminal wrote; read at once, so no further event is waited for.
      final output = File('${reply.path}/answer').readAsStringSync();
      final errors = File('${reply.path}/refusal').readAsStringSync();
      return request.answer(RemoteResult(exitCode!, errors), const LineSplitter().convert(output), widget.host);
    } finally {
      reply.deleteSync(recursive: true);
    }
  }

  Future<void> _run() async {
    if (_state == WizardActionState.running || _state == WizardActionState.done) return;
    if (widget.action == 'purge') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Purge ${_name.text} after locking?'),
          content: const Text(
            'Lock first to stop access while keeping the person’s records. Purge is a second decision: it permanently removes the person and their laptops. The host may refuse it. Continue with purge?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep the records')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Purge permanently')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _state = WizardActionState.running;
      _answer = null;
      _refusal = null;
    });
    try {
      final request = _request();
      await widget.prepareRemote?.call();
      final answer = widget.action == 'remove'
          ? await _removeProject(request)
          : await request.run(widget.remote, widget.host);
      if (mounted) {
        setState(() {
          _answer = answer;
          _state = WizardActionState.done;
        });
      }
    } on HostAdminRefused catch (error) {
      if (mounted) {
        setState(() {
          _refusal = error.words;
          _state = WizardActionState.refused;
        });
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _refusal = error.message;
          _state = WizardActionState.refused;
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _refusal = 'The host helper could not be reached: $error';
          _state = WizardActionState.refused;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Wizard(
    title: _title,
    changes: Listenable.merge([_name, _admin, _key, _block]),
    reviewWords:
        '${widget.host.vpnAddress}: ${_keys ? 'check the name and public keys' : 'check the name'} before continuing.${widget.action == 'remove' ? ' The next step opens your terminal and asks the master password of your secrets file. The host refuses a repository with no central home or with unpushed work.' : ''}',
    steps: [
      _step(
        _project ? 'Project name' : 'Project admin account',
        _project
            ? 'Copy the project name from its project.yml; this is a name, not a folder.'
            : widget.action == 'admit'
            ? 'Ask the person for the account name they want on this server.'
            : 'Type the account name of the project admin to ${widget.action}.',
        _name,
        'host-admin-name',
        () => checkAdminName(_name.text),
      ),
      if (widget.action == 'register') ...[
        _step(
          'Project admin account',
          'Ask the project admin for their account name on this server.',
          _admin,
          'host-admin-account',
          () => checkAdminName(_admin.text),
        ),
        _step(
          'Project signing public key',
          'Copy the ssh-ed25519 public line used to sign the project commits, from its .pub file. Remove its comment. Never paste a private key.',
          _key,
          'host-admin-signing-key',
          () => checkedEd25519(_key.text.trim()),
        ),
      ],
      if (widget.action == 'admit')
        _step(
          'Laptop public keys',
          'Ask the person for their public key block, one laptop per line: laptop ssh-ed25519 BASE64 WireGuard-public-key, optionally followed by an address in ${widget.host.values['network']}. Use one space between fields and no comments. Never paste a private key.',
          _block,
          'host-admin-key-block',
          () => checkAdminKeyBlock(_block.text, widget.host.network),
          multiline: true,
        ),
    ],
    action: _title,
    actionSteps: [
      WizardActionStep(
        title: _title,
        words: 'The server alone confirms this change.',
        run: _run,
        state: () => _state,
        panel: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Space.small,
          children: [
            if (_state == WizardActionState.running) const LinearProgressIndicator(),
            if (_answer case final answer?) SelectableText(answer, key: const Key('host-admin-answer')),
            if (_refusal case final refusal?) SelectableText(refusal, key: const Key('host-admin-refusal')),
          ],
        ),
      ),
    ],
  );
}
