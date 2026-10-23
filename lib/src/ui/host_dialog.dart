import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:porelo_host/porelo_host.dart';

import '../app/host_session.dart';
import '../app/machines.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';

/// Puts [project] on a server, or takes it off again, by the `porelo-host` shipped beside this
/// interface, showing each step as it says it and asking at its one stop.
Future<void> openHostDialog(
  BuildContext context, {
  required String project,
  required Machines machines,
  StartHostCommand? start,
}) => showDialog<void>(
  context: context,
  builder: (context) => HostDialog(project: project, machines: machines, start: start),
);

/// The page: where it goes, the steps, and at the stop what only the person can give.
///
/// **Nothing typed here is kept.** The answers go to the command's standard input when sent and
/// the fields are cleared; the provider's key is not asked here, it is the system store's
/// (`porelo-host key set scaleway`).
class HostDialog extends StatefulWidget {
  /// Constructor taking the project and, for the tests, how the command is started.
  const HostDialog({required this.project, required this.machines, this.start, super.key});

  /// The project to put on a server.
  final String project;

  /// Starts the command; the shipped one when null.
  final StartHostCommand? start;

  /// The fleet to add the completed host to and remove it from.
  final Machines machines;

  @override
  State<HostDialog> createState() => _HostDialogState();
}

class _HostDialogState extends State<HostDialog> {
  final _scaleway = TextEditingController();
  final _tresor = TextEditingController();
  final _account = TextEditingController(text: 'porelo');
  final _publicKey = TextEditingController(text: _home('.ssh/id_ed25519.pub'));
  final _identity = TextEditingController(text: _home('.ssh/id_ed25519'));
  final _collection = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _passphrase = TextEditingController();
  final _again = TextEditingController();
  HostSession? _session;
  bool _upStarted = false;
  bool _doneUp = false;
  bool _saving = false;
  String? _machineProblem;

  static String _home(String path) {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    return '$home${Platform.pathSeparator}${path.replaceAll('/', Platform.pathSeparator)}';
  }

  @override
  void dispose() {
    for (final field in <TextEditingController>[
      _scaleway,
      _tresor,
      _account,
      _publicKey,
      _identity,
      _collection,
      _email,
      _password,
      _code,
      _passphrase,
      _again, //
    ]) {
      field.dispose();
    }
    _session?.dispose();
    super.dispose();
  }

  HostSession _newSession() {
    _session?.dispose();
    final session = HostSession(
      executable: shippedPoreloHost(),
      arguments: <String>[
        '--project',
        widget.project,
        '--tresor',
        _tresor.text.trim(),
        '--account',
        _account.text.trim(),
        '--public-key',
        _publicKey.text.trim(),
        '--identity',
        _identity.text.trim(),
        '--collection',
        _collection.text.trim(),
        '--scaleway-project',
        _scaleway.text.trim(),
      ],
      start: widget.start,
    )..addListener(() => setState(() {}));
    return _session = session;
  }

  bool get _complete => <TextEditingController>[
    _scaleway, _tresor, _account, _publicKey, _identity, _collection, //
  ].every((field) => field.text.trim().isNotEmpty);

  bool get _running => _saving || _session?.state == HostRunState.running;

  void _up() {
    if (!_upStarted) {
      _newSession();
      _upStarted = true;
    }
    unawaited(_runUp(_session!.up));
  }

  // Keep the rented host's identity so teardown cannot silently target a different host.
  Future<void> _down() async {
    _doneUp = false;
    _machineProblem = null;
    final account = _account.text.trim();
    final session = _upStarted ? _session! : _newSession();
    await session.down();
    if (session.state != HostRunState.done) return;
    final address = session.releasedAddress;
    if (address == null || address.isEmpty) {
      if (mounted) setState(() => _machineProblem = 'No host was found. Your machines have been kept.');
      return;
    }
    for (final machine in widget.machines.all) {
      if (machine.kind == 'host' && machine.host == '$account@$address') {
        await widget.machines.forget(machine);
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _runUp(Future<void> Function() run) async {
    _doneUp = false;
    _machineProblem = null;
    await run();
    if (mounted) setState(() => _doneUp = _session!.state == HostRunState.done);
  }

  Future<void> _addHost() async {
    final session = _session!;
    final address = session.address ?? '';
    final account = session.account ?? '';
    final socket = session.socket ?? '';
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9.:-]*$').hasMatch(address) ||
        !RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*$').hasMatch(account) ||
        !RegExp(r'^/run/user/[0-9]+/porelo/porelod\.sock$').hasMatch(socket)) {
      setState(() => _machineProblem = 'The completed host did not name a valid address, account and daemon socket.');
      return;
    }
    final name = '${widget.project} server';
    if (widget.machines.all.any((machine) => machine.name == name && machine.kind != 'host')) {
      setState(() => _machineProblem = 'A machine named $name already exists and is not a host.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.machines.add(
        Machine(
          name: name,
          kind: 'host',
          socketPath: Platform.isWindows ? '' : Machine.endpointFor(name),
          host: '$account@$address',
          remoteSocket: socket,
          identity: _identity.text.trim(),
        ),
      );
      if (mounted) setState(() => _doneUp = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resume() {
    final needs = _session!.needs;
    final answers = Answers(
      driveEmail: needs.contains('drive') ? _email.text.trim() : null,
      drivePassword: needs.contains('drive') ? _password.text : null,
      driveCode: needs.contains('drive') && _code.text.trim().isNotEmpty ? _code.text.trim() : null,
      vaultPassphrase: needs.any((n) => n.startsWith('vault')) ? _passphrase.text : null,
    );
    // Gone from the fields before the command even starts: the answers live only in what is sent.
    _password.clear();
    _code.clear();
    _passphrase.clear();
    _again.clear();
    unawaited(_runUp(() => _session!.resume(answers)));
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return AlertDialog(
      title: Text('Put ${widget.project} on a server'),
      content: SizedBox(
        width: Sizes.dialogMedium,
        child: DialogScroll(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'porelo-host rents the host at Scaleway Elastic Metal, or finds it again, and runs the '
                'playbook there. Its key is the one `porelo-host key set scaleway` kept.',
              ),
              const SizedBox(height: Space.normal),
              _field(_scaleway, 'Scaleway project id', 'host-scaleway-project', namesHost: true),
              _field(_tresor, 'The project\'s tresor', 'host-tresor', namesHost: true),
              _field(_account, 'Account on the host', 'host-account', namesHost: true),
              _field(_publicKey, 'Your public ssh key', 'host-public-key', namesHost: true),
              _field(_identity, 'Your private ssh key', 'host-identity', namesHost: true),
              _field(_collection, 'porelo-host collection (.tar.gz)', 'host-collection', namesHost: true),
              const SizedBox(height: Space.normal),
              if (session != null) ...<Widget>[
                for (final step in session.steps) _stepRow(step),
                if (session.state == HostRunState.waiting) _askForTheStop(session.needs),
                if (session.fix != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.small),
                    child: Text(
                      session.fix!,
                      key: const Key('host-fix'),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                if (session.state == HostRunState.done)
                  const Padding(
                    padding: EdgeInsets.only(top: Space.small),
                    child: Text('Done.', key: Key('host-done')),
                  ),
              ],
              if (_machineProblem != null) Text(_machineProblem!),
              if (_doneUp)
                FilledButton(
                  key: const Key('host-add'),
                  onPressed: _running ? null : _addHost,
                  child: const Text('Add this server to your machines'),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: _running ? null : () => Navigator.of(context).pop(), child: const Text('Close')),
        OutlinedButton(
          key: const Key('host-down'),
          onPressed: _running || !_complete ? null : _down,
          child: const Text('Take it off the server'),
        ),
        FilledButton(
          key: const Key('host-up'),
          onPressed: _running || !_complete ? null : _up,
          child: const Text('Put it on a server'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String key, {
    bool secret = false,
    bool namesHost = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: Space.small),
    child: TextField(
      key: Key(key),
      controller: controller,
      obscureText: secret,
      enabled: !_running,
      readOnly: namesHost && _upStarted,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() {}),
    ),
  );

  Widget _stepRow(Step step) => Row(
    key: Key('host-step-${step.step}'),
    children: <Widget>[
      Icon(switch (step.state) {
        StepState.started => Icons.pending_outlined,
        StepState.done => Icons.check,
        StepState.refused => Icons.error_outline,
        StepState.waiting => Icons.person_outline,
      }, size: Sizes.mark),
      const SizedBox(width: Space.small),
      Expanded(child: Text(step.step)),
    ],
  );

  /// What only the person can give at the stop: the drive's login and the vault's passphrase.
  Widget _askForTheStop(List<String> needs) {
    final drive = needs.contains('drive');
    final fresh = needs.contains('vault-new');
    final vault = fresh || needs.contains('vault');
    const known = <String>{'drive', 'vault', 'vault-new'};
    final unknown = needs.where((need) => !known.contains(need)).toList();
    final matches = !fresh || _passphrase.text == _again.text;
    final given =
        (!drive || (_email.text.trim().isNotEmpty && _password.text.isNotEmpty)) &&
        (!vault || _passphrase.text.isNotEmpty) &&
        matches;
    return Column(
      key: const Key('host-stop'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: Space.normal),
        if (needs.isEmpty)
          const Text('The host waits without saying for what.')
        else
          const Text('The host waits for what only you can give. It goes to the host and is kept nowhere.'),
        for (final need in unknown) Text('porelo-host waits for $need; this interface cannot answer it yet.'),
        if (drive) ...<Widget>[
          _field(_email, 'Tresorit e-mail', 'host-drive-email'),
          _field(_password, 'Tresorit password', 'host-drive-password', secret: true),
          // Asked here, at the stop, so it is still valid when it reaches the host a moment later.
          _field(_code, 'Tresorit one-time code (empty without a second factor)', 'host-drive-code', secret: true),
        ],
        if (vault)
          _field(
            _passphrase,
            fresh ? 'A passphrase for the new vault' : 'The vault\'s passphrase',
            'host-passphrase',
            secret: true,
          ),
        if (fresh) _field(_again, 'The same passphrase again', 'host-passphrase-again', secret: true),
        if (!matches) const Text('The two passphrases differ.', key: Key('host-passphrases-differ')),
        if ((drive || vault) && unknown.isEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const Key('host-resume'),
              onPressed: given ? _resume : null,
              child: const Text('Go on'),
            ),
          ),
      ],
    );
  }
}
