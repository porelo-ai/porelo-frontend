import 'dart:async';

import 'package:flutter/material.dart';

import '../app/host_token_sources.dart';
import '../app/server_first_login.dart';
import '../app/server_setup.dart';
import 'command_to_copy.dart';
import 'following_output.dart';
import 'host_check_list.dart';
import 'host_preparation_settings.dart';
import 'tokens.dart';
import 'wizard.dart';

/// Opens a terminal on this computer running [command], and returns once it ended.
typedef OpenServerTerminal = Future<void> Function(BuildContext context, List<String> command);

/// The line that prints the server's own host key fingerprint, run on the server to compare.
const compareCommand = 'ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub';

/// Shows [ServerSetupWizard] as the one dialog it is; [onSignIn] closes it first.
Future<void> showServerSetupWizard(
  BuildContext context, {
  required ServerSetup setup,
  required OpenServerTerminal openTerminal,
  HostTokenStep Function(String host)? token,
  VoidCallback? onSignIn,
  VoidCallback? onUnlock,
}) => showDialog<void>(
  context: context,
  builder: (context) => ServerSetupWizard(
    setup: setup,
    openTerminal: openTerminal,
    token: token,
    onSignIn: onSignIn == null
        ? null
        : () {
            Navigator.of(context).pop();
            onSignIn();
          },
    onUnlock: onUnlock,
  ),
);

/// Sets a server up as a machine of the organization, one question per page.
///
/// [token] is the last step's giving of the host's forge token, made once the machine is prepared; null leaves the
/// token to the machine's row.
class ServerSetupWizard extends StatefulWidget {
  /// Asks what [setup] needs, opening a terminal on the server by [openTerminal].
  const ServerSetupWizard({
    required this.setup,
    required this.openTerminal,
    this.token,
    this.onSignIn,
    this.onUnlock,
    super.key,
  });

  /// Leads to signing in under *My forges*, from the token's page.
  final VoidCallback? onSignIn;

  /// Opens this computer's Porelo-Vault in a terminal, from the token's page.
  final VoidCallback? onUnlock;

  /// What is asked and proven.
  final ServerSetup setup;

  /// Opens the provider's first login in a terminal.
  final OpenServerTerminal openTerminal;

  /// Gives the prepared host its token, made for the host once its name is known.
  final HostTokenStep Function(String host)? token;

  @override
  State<ServerSetupWizard> createState() => _ServerSetupWizardState();
}

class _ServerSetupWizardState extends State<ServerSetupWizard> {
  late final _address = TextEditingController(text: widget.setup.address);
  late final _login = TextEditingController(text: widget.setup.firstLogin);
  final _pasted = TextEditingController();
  final _goBackTo = ValueNotifier<int?>(null);
  HostTokenStep? _token;
  bool _inTerminal = false;

  ServerSetup get _setup => widget.setup;

  @override
  void initState() {
    super.initState();
    _setup.keyChangedSinceCompared.addListener(_keyChanged);
    unawaited(_setup.start());
  }

  void _keyChanged() {
    if (!_setup.keyChangedSinceCompared.value) return;
    _setup.keyChangedSinceCompared.value = false;
    _pasted.clear();
    _goBackTo.value = null;
    _goBackTo.value = 2;
  }

  @override
  void dispose() {
    _setup.keyChangedSinceCompared.removeListener(_keyChanged);
    for (final field in [_address, _login, _pasted]) {
      field.dispose();
    }
    _goBackTo.dispose();
    _token?.dispose();
    super.dispose();
  }

  Future<void> _openTerminal() async {
    final pin = await _setup.pin();
    if (pin == null || !mounted) return;
    setState(() => _inTerminal = true);
    try {
      await widget.openTerminal(
        context,
        firstLoginCommand(pin: pin.file.path, user: _setup.firstLogin, address: _setup.address),
      );
    } finally {
      if (mounted) setState(() => _inTerminal = false);
    }
    // Once the terminal ends, whether the line ran is asked of root itself.
    if (mounted) await _setup.tryRoot();
  }

  Widget _machine(BuildContext context) {
    final choices = _setup.choices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.small,
      children: [
        if (choices.isNotEmpty)
          DropdownButtonFormField<String>(
            key: const Key('setup-machine'),
            initialValue: choices.contains(_setup.name) ? _setup.name : null,
            decoration: const InputDecoration(
              labelText: 'Machine name',
              helperText: 'A machine the organization lists and you are Machine Admin of, not set up yet.',
            ),
            items: [for (final each in choices) DropdownMenuItem(value: each, child: Text(each))],
            onChanged: (value) => _setup.name = value ?? '',
          ),
        const Text(
          'A machine not listed yet is listed by an Organization Admin with Add a machine on the organization\'s '
          'page, naming you its first Machine Admin.',
        ),
      ],
    );
  }

  Widget _where(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: Space.small,
    children: [
      TextField(
        key: const Key('setup-address'),
        controller: _address,
        decoration: const InputDecoration(
          labelText: 'Server address',
          helperText: 'The IP address or name your provider shows for the server.',
        ),
        onChanged: (value) => _setup.address = value,
      ),
      TextField(
        key: const Key('setup-first-login'),
        controller: _login,
        decoration: const InputDecoration(
          labelText: 'First login',
          hintText: 'e.g. ubuntu',
          helperText: 'The account your provider made for you on the server, as its console or mail names it.',
        ),
        onChanged: (value) => _setup.firstLogin = value,
      ),
      CheckboxListTile(
        key: const Key('setup-provider-ready'),
        contentPadding: EdgeInsets.zero,
        title: const Text('My provider reports the server ready, with its installation finished'),
        subtitle: const Text(
          'Until then the server may answer with its installer\'s SSH key, which is not the one it keeps.',
        ),
        value: _setup.providerReady,
        onChanged: (value) => _setup.providerReady = value == true,
      ),
      if (_setup.sshProblem case final problem?) Text(problem, key: const Key('setup-ssh-problem')),
    ],
  );

  Widget _key(BuildContext context) {
    final key = _setup.key;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.small,
      children: [
        Wrap(
          spacing: Space.small,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              key: const Key('setup-fetch-key'),
              onPressed: _setup.fetching || !_setup.sshAnswered ? null : () => unawaited(_setup.fetchKey()),
              child: const Text('Fetch SSH host key'),
            ),
            if (_setup.fetching) const Text('Fetching…', key: Key('setup-fetching')),
          ],
        ),
        TextField(
          key: const Key('setup-pasted-key'),
          controller: _pasted,
          decoration: const InputDecoration(
            labelText: 'Or paste the key',
            helperText: "The line of the server's /etc/ssh/ssh_host_ed25519_key.pub, if you have it from elsewhere.",
          ),
          onSubmitted: (value) => unawaited(_setup.pasteKey(value)),
          onChanged: (value) {
            if (value.trim().isEmpty) unawaited(_setup.pasteKey(''));
          },
        ),
        TextButton(
          key: const Key('setup-take-pasted'),
          onPressed: _setup.fetching ? null : () => unawaited(_setup.pasteKey(_pasted.text)),
          child: const Text('Take the pasted key'),
        ),
        if (_setup.keyProblem case final problem?) Text(problem, key: const Key('setup-key-problem')),
        if (key != null)
          DecoratedBox(
            key: const Key('setup-key-box'),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(Radii.small),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Space.normal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.small,
                children: [
                  Text(_setup.pasted ? 'The pasted key' : 'The key the server answered with'),
                  SelectableText(key.key, style: const TextStyle(fontFamily: 'monospace')),
                  const Text('Its fingerprint:'),
                  SelectableText(
                    key.fingerprint,
                    key: const Key('setup-fingerprint'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontFamily: 'monospace'),
                  ),
                  const Text(
                    'On the server, in its provider\'s console or a login you trust, run this and compare what it '
                    'prints with the fingerprint above:',
                  ),
                  const CommandToCopy(command: compareCommand, textKey: Key('setup-compare-command')),
                ],
              ),
            ),
          ),
        if (_setup.oldKey case final old?)
          Text(
            key: const Key('setup-old-key'),
            'Your own known_hosts holds ${old.host} with another key: ${old.fingerprints.join('; ')}. That is what '
            'usually happens when a provider gives a deleted server\'s address to a new one. Once you compared the '
            'new fingerprint, preparing takes the old key out of ${old.files.join(', ')}; until then it stays.',
            style: TextStyle(color: scheme.error),
          ),
        if (key != null)
          CheckboxListTile(
            key: const Key('setup-compared'),
            contentPadding: EdgeInsets.zero,
            title: const Text('I compared this fingerprint'),
            value: _setup.compared,
            onChanged: (value) => _setup.compared = value == true,
          ),
      ],
    );
  }

  Widget _choices(BuildContext context) {
    final chosen = _setup.chosen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const Key('host-forge'),
          contentPadding: EdgeInsets.zero,
          title: const Text('This host has a forge of its own'),
          subtitle: const Text(
            'On: builds run here, and take memory and CPUs from the tasks. Off: a central forge alone, with less to '
            'run on the machine.',
          ),
          value: chosen.forge,
          onChanged: (value) => _setup.chosen = chosen.withPlainChoices(forge: value, kvm: value && chosen.kvm),
        ),
        if (chosen.forge)
          SwitchListTile(
            key: const Key('host-check-vms'),
            contentPadding: EdgeInsets.zero,
            title: const Text('This host runs VMs in its jobs'),
            subtitle: const Text(
              'On installs KVM and libvirt, needs a CPU with virtualization, and is for a job that makes a VM; a job '
              'in a container needs none of it.',
            ),
            value: chosen.kvm,
            onChanged: (value) => _setup.chosen = chosen.withPlainChoices(forge: true, kvm: value),
          ),
        HostPreparationSettingsForm(value: chosen, onChanged: (value) => _setup.chosen = value),
      ],
    );
  }

  Widget _handOver(BuildContext context) {
    final line = _setup.bootstrapLine;
    final root = _setup.root;
    final busy = _inTerminal || _setup.tryingRoot || _setup.runningBootstrap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.small,
      children: [
        Text(
          'This line runs on the server, as ${_setup.firstLogin.isEmpty ? 'the first login' : _setup.firstLogin}, '
          'never on this computer. It replaces root\'s authorized keys with your Machine Admin card key; from then on '
          'Porelo logs in as root.',
        ),
        if (line == null)
          const Text('The line is shown once your identity was read again.')
        else
          CommandToCopy(command: line, textKey: const Key('host-bootstrap-command')),
        Text(
          '*Run it for me* runs it as ${_setup.firstLogin} at ${_setup.address}, trusting only the key you compared, '
          'and tries root\'s login right after. Where sudo wants your password, open a terminal on the server instead: '
          'paste the line there, type the password, and close the terminal when it is done; root\'s login is tried then.',
        ),
        Wrap(
          spacing: Space.small,
          runSpacing: Space.small,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              key: const Key('setup-run-bootstrap'),
              onPressed: line == null || busy ? null : () => unawaited(_setup.runBootstrap()),
              child: const Text('Run it for me'),
            ),
            OutlinedButton(
              key: const Key('setup-open-terminal'),
              onPressed: busy ? null : () => unawaited(_openTerminal()),
              child: const Text('Open a terminal on the server'),
            ),
            OutlinedButton(
              key: const Key('setup-try-root'),
              onPressed: busy ? null : () => unawaited(_setup.tryRoot()),
              child: const Text('Try the root login'),
            ),
            if (_setup.runningBootstrap)
              const Text('Running the bootstrap line on the server…', key: Key('setup-running-bootstrap')),
            if (_setup.tryingRoot) const Text('Trying the root login…', key: Key('setup-trying-root')),
          ],
        ),
        if (_setup.bootstrapRun case final run? when run.state != BootstrapRunState.ran)
          Text(run.words, key: const Key('setup-bootstrap-answer')),
        if (root != null) Text(root.words, key: const Key('setup-root-answer')),
      ],
    );
  }

  Widget _check(BuildContext context) {
    if (_setup.hostCheck == null) {
      return Text(
        key: const Key('host-check-none'),
        _setup.noCheckWhy ?? 'The collection carried here holds no check, so preparing runs without one.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.small,
      children: [
        Wrap(
          spacing: Space.small,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              key: const Key('host-check-run'),
              onPressed: _setup.checking ? null : () => unawaited(_setup.runCheck()),
              child: const Text('Check this machine'),
            ),
            if (_setup.checking) const Text('Checking the machine…', key: Key('host-check-running')),
          ],
        ),
        if (_setup.checkAnswer case final answer?) HostCheckList(answer: answer),
      ],
    );
  }

  WizardActionState get _prepareState {
    if (_setup.preparing) return WizardActionState.running;
    if (_setup.prepared) return WizardActionState.done;
    if (_setup.prepareProblem != null) return WizardActionState.refused;
    return _setup.run == null ? WizardActionState.waiting : WizardActionState.refused;
  }

  Widget _prepare(BuildContext context) {
    final run = _setup.run;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.small,
      children: [
        if (_setup.preparing)
          Text(
            'Preparing machine ${_setup.name}. This can take minutes. It goes on if you close this wizard; its row '
            'opens the protocol again.',
          ),
        if (_setup.prepareProblem case final problem?) Text(problem, key: const Key('setup-prepare-problem')),
        if (run != null) FollowingOutput(text: run.session.protocolText),
        if (_setup.prepared)
          const Text('The machine is ready, and its address, SSH host key and ports stand on its card.'),
      ],
    );
  }

  HostTokenStep? get _tokenStep {
    final make = widget.token;
    if (make == null || _setup.name.isEmpty) return null;
    return _token ??= make(_setup.name)..addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _setup,
    builder: (context, _) => Wizard(
      title: 'Set up a machine',
      changes: _setup,
      goBackTo: _goBackTo,
      action: 'Prepare the machine',
      reviewWords: 'This is what will be prepared. Preparing installs Porelo on the server and changes it.',
      steps: [
        WizardStep(
          title: 'Which machine',
          words: 'The organization\'s machine this server becomes.',
          panel: _machine,
          check: () => _setup.whyNotMachine,
          summary: () => ['Machine: ${_setup.name}'],
        ),
        WizardStep(
          title: 'Where it is',
          words: 'Where this computer reaches the server, and the login your provider gave you.',
          panel: _where,
          check: () => _setup.whyNotWhere,
          beforeNext: _setup.askSsh,
          summary: () => ['Address: ${_setup.address}, first login ${_setup.firstLogin}'],
        ),
        WizardStep(
          title: 'Its SSH host key',
          words: 'The key the server proves itself with, compared on the server before anything logs in.',
          panel: _key,
          check: () => _setup.whyNotKey,
          summary: () => [
            if (_setup.key case final key?)
              'SSH host key: ${key.fingerprint}${_setup.pasted ? ' (pasted)' : ''}, compared',
          ],
        ),
        WizardStep(
          title: 'What it will run',
          words: 'What the machine is set up for. These can be changed only by setting it up again.',
          panel: _choices,
          check: () => null,
          summary: () => [
            _setup.chosen.forge
                ? 'It has a forge of its own${_setup.chosen.kvm ? ', and runs VMs in its jobs' : ''}.'
                : 'It has no forge of its own.',
          ],
        ),
        WizardStep(
          title: 'Hand the login over',
          words: 'Root\'s login goes to your Machine Admin card key, by one line run on the server.',
          panel: _handOver,
          check: () => _setup.whyNotLogin,
          summary: () => [if (_setup.whyNotLogin == null) 'Root logs in with your Machine Admin card key.'],
        ),
        WizardStep(
          title: 'The check',
          words: 'A check that only reads, and says what would stand in the way.',
          panel: _check,
          check: () => _setup.whyNotCheck,
          summary: () => [if (_setup.hostCheck != null && _setup.whyNotCheck == null) 'The check passed.'],
        ),
      ],
      actionSteps: [
        WizardActionStep(
          title: 'Prepare',
          words: 'Porelo is installed on the server, and its card in the organization gets its address and key.',
          panel: _prepare,
          run: _setup.prepare,
          state: () => _prepareState,
        ),
        if (widget.token != null)
          WizardActionStep(
            title: 'Give it your token',
            words:
                'The machine reads the organization\'s repositories with read keys it adds itself, once, with your '
                'forge token. It does not keep the token.',
            panel: (context) => _tokenStep == null
                ? const SizedBox.shrink()
                : HostTokenPanel(step: _tokenStep!, onSignIn: widget.onSignIn, onUnlock: widget.onUnlock),
            run: () async => _tokenStep?.ask(),
            state: () => switch (_tokenStep) {
              null => WizardActionState.refused,
              final step when step.given => WizardActionState.done,
              final step when step.asking || step.giving => WizardActionState.running,
              _ => WizardActionState.waiting,
            },
          ),
      ],
    ),
  );
}

/// What each source of a forge token answered for a host, and the way on from each.
class HostTokenPanel extends StatelessWidget {
  /// Shows [step].
  const HostTokenPanel({required this.step, this.onSignIn, this.onUnlock, super.key});

  /// The step shown.
  final HostTokenStep step;

  /// Leads to signing in under *My forges*, where this computer offers it.
  final VoidCallback? onSignIn;

  /// Opens this computer's Porelo-Vault in a terminal, where this computer offers it.
  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: step,
    builder: (context, _) {
      final answers = step.answers;
      final offered = step.offered;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Space.small,
        children: [
          if (step.asking) Text('Reaching ${step.host} and asking where a token is…'),
          if (answers != null)
            for (final answer in answers)
              ListTile(
                key: Key('token-source-${answer.source.name}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(switch (answer.state) {
                  TokenSourceState.found => Icons.check_circle_outline,
                  TokenSourceState.none => Icons.remove_circle_outline,
                  TokenSourceState.failed => Icons.error_outline,
                }),
                title: Text(answer.name),
                subtitle: Text(answer.words),
              ),
          if (answers != null && offered == null)
            const Text('No source holds a token now. Each line above says why, and what to do.'),
          if (step.problem case final problem?) Text(problem, key: const Key('token-problem')),
          if (step.given) Text('${step.host} took the token.', key: const Key('token-given')),
          Wrap(
            spacing: Space.small,
            runSpacing: Space.small,
            children: [
              if (offered != null && !step.given)
                FilledButton(
                  key: const Key('token-give'),
                  onPressed: step.giving ? null : () => unawaited(step.giveFrom(offered)),
                  child: Text('Give it the token from ${offered.name.toLowerCase()}'),
                ),
              OutlinedButton(
                key: const Key('token-ask-again'),
                onPressed: step.asking || step.giving ? null : () => unawaited(step.ask()),
                child: const Text('Ask again'),
              ),
              if (onUnlock != null &&
                  answers?.any((each) => each.source == TokenSource.declared && each.state != TokenSourceState.found) ==
                      true)
                OutlinedButton(onPressed: onUnlock, child: const Text("Open this computer's Porelo-Vault")),
              if (onSignIn != null &&
                  answers?.any((each) => each.source == TokenSource.kept && each.state == TokenSourceState.none) ==
                      true)
                OutlinedButton(onPressed: onSignIn, child: const Text('Sign in under My forges')),
            ],
          ),
        ],
      );
    },
  );
}
