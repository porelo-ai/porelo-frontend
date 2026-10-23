import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:porelo_host/porelo_host.dart';

import '../app/host_session.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';

/// Puts [project] on a server, or takes it off again, by the `porelo-host` shipped beside this
/// interface, showing each step as it says it and asking at its one stop.
Future<void> openHostDialog(BuildContext context, {required String project, StartHostCommand? start}) =>
    showDialog<void>(
      context: context,
      builder: (context) => HostDialog(project: project, start: start),
    );

/// The page: where it goes, the steps, and at the stop what only the person can give.
///
/// **Nothing typed here is kept.** The answers go to the command's standard input when sent and
/// the fields are cleared; the provider's key is not asked here, it is the system store's
/// (`porelo-host key set scaleway`).
class HostDialog extends StatefulWidget {
  /// Constructor taking the project and, for the tests, how the command is started.
  const HostDialog({required this.project, this.start, super.key});

  /// The project to put on a server.
  final String project;

  /// Starts the command; the shipped one when null.
  final StartHostCommand? start;

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

  bool get _running => _session?.state == HostRunState.running;

  void _up() {
    if (!_upStarted) {
      _newSession();
      _upStarted = true;
    }
    unawaited(_session!.up());
  }

  // Keep the rented host's identity so teardown cannot silently target a different host.
  void _down() => unawaited((_upStarted ? _session! : _newSession()).down());

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
    unawaited(_session!.resume(answers));
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

  /// The drive and vault answers, and the agent sign-ins still needed on the host.
  Widget _askForTheStop(List<String> needs) {
    final drive = needs.contains('drive');
    final fresh = needs.contains('vault-new');
    final vault = fresh || needs.contains('vault');
    final agentLogins = needs
        .where((need) => need.startsWith('agent-login:') && need.length > 'agent-login:'.length)
        .toList();
    final known = <String>{'drive', 'vault', 'vault-new', ...agentLogins};
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
        for (final need in agentLogins) Text('${need.substring('agent-login:'.length)} must be signed in on the host.'),
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
