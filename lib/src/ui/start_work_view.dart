import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/start_work.dart';
import '../app/templates.dart';
import 'choice_field.dart';
import 'tokens.dart';
import 'dialog_scroll.dart';
import '../app/links.dart';

/// Starts work: a project, an agent, a way of being involved, and what to ask for.
///
/// The mode is the decision here. It is what says whether anybody is going to be there, and it
/// governs the rest of the form: a prompt belongs to an unattended run and to nothing else,
/// because the backend would accept `SHELL` with a prompt and record it — a run nobody is
/// attached to, described as one somebody is driving.
Future<bool> openStartWork(
  BuildContext context, {
  required StartWork starting,
  required VoidCallback onStart,
  required VoidCallback onKeep,
  Future<void> Function()? onStoreTheCredential,
  Future<void> Function(Agent agent)? onLogIn,
  Future<void> Function()? onOpenWithThisDevice,
  Future<void> Function(String entry)? onGrant,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => StartWorkDialog(
          starting: starting,
          onStart: onStart,
          onKeep: onKeep,
          onStoreTheCredential: onStoreTheCredential,
          onLogIn: onLogIn,
          onOpenWithThisDevice: onOpenWithThisDevice,
          onGrant: onGrant),
    ) ??
    false;

/// The dialog itself, separated so it can be built directly in a test.
class StartWorkDialog extends StatefulWidget {
  /// Constructor taking the model and what to do with it.
  const StartWorkDialog({
    required this.starting,
    required this.onStart,
    required this.onKeep,
    this.onStoreTheCredential,
    this.onLogIn,
    this.onOpenWithThisDevice,
    this.onGrant,
    super.key,
  });

  /// What is being started.
  final StartWork starting;

  /// Starts it.
  final VoidCallback onStart;

  /// Keeps what is on screen as a recurring job under the name that was typed.
  final VoidCallback onKeep;

  /// Stores the missing credential in a terminal on the machine, then asks again; null where
  /// nothing here reaches that machine.
  final Future<void> Function()? onStoreTheCredential;

  /// Runs the agent's own login in a terminal on the machine, then asks again; null likewise.
  final Future<void> Function(Agent agent)? onLogIn;

  /// Opens a locked vault with this device, then asks again; null where this device is not
  /// enrolled on that machine and so has nothing to open it with.
  final Future<void> Function()? onOpenWithThisDevice;

  /// Grants the authorization an entry names, in a browser, then asks again; null where not offered.
  final Future<void> Function(String entry)? onGrant;

  @override
  State<StartWorkDialog> createState() => _StartWorkDialogState();
}

class _StartWorkDialogState extends State<StartWorkDialog> {
  late final TextEditingController _prompt =
      TextEditingController(text: widget.starting.prompt);

  late final TextEditingController _name = TextEditingController(text: widget.starting.name);

  /// The name field, showing a suggestion that came in since, but never replacing what is being typed.
  TextEditingController _nameShown(String name) {
    if (_name.text.trim() != name) {
      _name.value = TextEditingValue(text: name, selection: TextSelection.collapsed(offset: name.length));
    }
    return _name;
  }

  @override
  void dispose() {
    _prompt.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.starting,
        builder: (context, _) {
          final starting = widget.starting;
          final continuing = starting.continuing;

          return AlertDialog(
            title: Text(switch ((continuing, starting.from)) {
              (final Task task, _) => 'Continue ${task.name}',
              (_, final Template job) =>
                'Run ${job.name} in ${starting.project?.name ?? ''}',
              _ => 'Start work in ${starting.project?.name ?? ''}',
            }),
            content: SizedBox(
              width: Sizes.dialogMedium,
              child: DialogScroll(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (continuing != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.normal),
                        child: Text(
                          'What it was asked to do last time is below. Continuing means asking '
                          'for something more, so it is here to be edited rather than sent as '
                          'it stands.',
                          key: const Key('start-continuing'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    if (starting.apartFromElsewhere case final apart?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.normal),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(Space.normal),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(Radii.small),
                          ),
                          child: Text(apart, key: const Key('start-apart-from-elsewhere')),
                        ),
                      ),
                    if (starting.problem != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.normal),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(Space.normal),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(Radii.small),
                          ),
                          child: Text(starting.problem!,
                              key: const Key('start-problem')),
                        ),
                      ),
                    // What a start needs comes first, above the fold: a sign-in nobody saw was why a
                    // new person started a shell where the agent said "Not logged in".
                    if (starting.needsASignIn && widget.onLogIn != null)
                      _SignInFirst(
                          starting: starting,
                          onLogIn: widget.onLogIn!,
                          onStoreTheCredential: widget.onStoreTheCredential),
                    if (starting.needsARepository) ...<Widget>[
                      const SizedBox(height: Space.wide),
                      Text('Which repository', style: Theme.of(context).textTheme.labelLarge),
                      _WhichRepository(starting: starting),
                    ],
                    // Required, and filled in from the repository.
                    if (continuing == null) ...<Widget>[
                      const SizedBox(height: Space.wide),
                      TextField(
                        key: const Key('start-name'),
                        controller: _nameShown(starting.name),
                        decoration: InputDecoration(
                          labelText: 'A name for this run',
                          border: const OutlineInputBorder(),
                          helperText: 'Filled in from the repository; change it if you like. It names '
                              'this piece of work and its container on the machine.',
                          errorText: starting.nameProblem,
                        ),
                        onChanged: starting.callIt,
                      ),
                    ],
                    const SizedBox(height: Space.wide),
                    Text('Which agent', style: Theme.of(context).textTheme.labelLarge),
                    if (starting.busy)
                      const Padding(
                        padding: EdgeInsets.all(Space.normal),
                        child: Text('Asking the machine what it has…'),
                      )
                    else if (starting.agents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: Space.small),
                        child: Text(
                          'None is installed on this machine. That is a state, not a failure, '
                          'and nothing can be started until one is.',
                          key: Key('start-no-agents'),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        key: const Key('start-agent'),
                        initialValue: starting.agent,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: <DropdownMenuItem<String>>[
                          for (final agent in starting.agents)
                            DropdownMenuItem<String>(
                              value: agent.name,
                              child: Text(agent.version.isEmpty
                                  ? agent.label
                                  : '${agent.label} · ${agent.version}'),
                            ),
                        ],
                        onChanged: (chosen) =>
                            chosen == null ? null : starting.chooseAgent(chosen),
                      ),
                    // Shown, never dropped: an agent missing from a list looks exactly like one
                    // that was never installed, and only one of those is worth fixing.
                    for (final failure in starting.failures.entries)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.tight),
                        child: Text('${failure.key} could not be read: ${failure.value}',
                            key: const Key('start-agent-failure'),
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    const SizedBox(height: Space.wide),
                    Text('How you are involved',
                        style: Theme.of(context).textTheme.labelLarge),
                    _WhichMode(starting: starting),
                    // Only where it belongs: a greyed box for the two ways a person drives took the
                    // room the start's buttons needed on a small window.
                    if (starting.takesAPrompt) ...<Widget>[
                      const SizedBox(height: Space.normal),
                      TextField(
                        key: const Key('start-prompt'),
                        controller: _prompt,
                        maxLines: 4,
                        minLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'What to ask it to do',
                          border: OutlineInputBorder(),
                          helperText: 'It runs on its own until this is done or its time is up.',
                        ),
                        onChanged: starting.ask,
                      ),
                    ],

                    // Answered before anything is created, and shown before the button. Three of
                    // its outcomes are different actions — choose a provider, store a secret,
                    // unlock the vault — and sending somebody to the wrong one costs more than
                    // saying nothing would.
                    if (starting.readiness != null &&
                        !starting.readiness!.ready &&
                        !(starting.needsASignIn && widget.onLogIn != null) &&
                        !starting.readinessIsAboutTheName &&
                        !starting.readinessIsAboutTheRepository) ...<Widget>[
                      const SizedBox(height: Space.wide),
                      _NotReady(
                          starting: starting,
                          onStoreTheCredential: widget.onStoreTheCredential,
                          onGrant: widget.onGrant,
                          onLogIn: widget.onLogIn,
                          onOpenWithThisDevice: widget.onOpenWithThisDevice),
                    ],
                    const SizedBox(height: Space.normal),
                    // Out of the way of a first start: a name, more credentials, keeping it as a job.
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        key: const Key('start-more'),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        initiallyExpanded: continuing != null || starting.from != null,
                        title: const Text('More options'),
                        subtitle: const Text('More credentials, keeping it to start again'),
                        children: <Widget>[
                          _MoreCredentials(starting: starting),
                          const SizedBox(height: Space.wide),
                          _KeepAsTemplate(starting: starting, onKeep: widget.onKeep),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                key: const Key('start-not-now'),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
              if (starting.needsASignIn && widget.onLogIn != null)
                FilledButton(
                  key: const Key('start-sign-in-first'),
                  onPressed: () => widget.onLogIn!(starting.chosenAgent!),
                  child: const Text('Sign in first'),
                )
              else
              FilledButton(
                key: const Key('start-go'),
                onPressed: starting.ready
                    ? () {
                        widget.onStart();
                        Navigator.of(context).pop(true);
                      }
                    : null,
                child: Text(continuing == null ? 'Start it' : 'Continue it'),
              ),
            ],
          );
        },
      );
}

/// Credentials the work is given beyond what its project names, each a vault entry for one of the
/// machine's destinations. **None is given until somebody gives it.**
class _MoreCredentials extends StatelessWidget {
  const _MoreCredentials({required this.starting});

  final StartWork starting;


  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // What an entry can be for: the destinations in force, then the providers. One of each name,
    // the destination first, as a menu of two items with one value cannot be drawn.
    final places = <({String name, String label, String reaches})>[
      for (final each in starting.destinations ?? const <Destination>[])
        if (each.inForce) (name: each.name, label: each.label, reaches: each.upstream),
    ];
    for (final each in starting.providers) {
      if (places.every((place) => place.name != each.name)) {
        places.add((name: each.name, label: '${each.label.isEmpty ? each.name : each.label}, a provider',
            reaches: each.upstream));
      }
    }
    return Column(
      key: const Key('start-credentials'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('More credentials', style: text.labelLarge),
        ..._fromTheProject(context, starting.project),
        Text(
          'Beside what its project gives it, it can be given vault entries, each for a destination or '
          'a provider.',
          style: text.bodySmall,
        ),
        const SizedBox(height: Space.tight),
        if (starting.destinations == null)
          const Text('This machine cannot list destinations.', key: Key('start-credentials-unsupported')),
        if (starting.destinations != null && places.length == starting.providers.length)
          const Text('No destination is declared on this machine. One is added under Destinations, in '
              "the machine's menu.", key: Key('start-no-destinations')),
        if (places.isNotEmpty && starting.vaultEntries.isEmpty)
          const Text('The vault holds nothing that could be given, or cannot be read now.',
              key: Key('start-no-vault-entries')),
        if (places.isNotEmpty)
          for (final entry in starting.vaultEntries)
            // The project's own are given anyway and cannot be pointed elsewhere, so not offered.
            if (!(starting.project?.credentials.containsKey(entry.name) ?? false))
            Padding(
              padding: const EdgeInsets.only(top: Space.tight),
              child: DropdownButtonFormField<String>(
                key: ValueKey<String>('start-credential ${entry.name}'),
                isExpanded: true,
                initialValue: starting.credentials[entry.name] ?? '',
                decoration: InputDecoration(labelText: entry.name, border: const OutlineInputBorder()),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(value: '', child: Text('Not given')),
                  for (final place in places)
                    DropdownMenuItem<String>(
                      value: place.name,
                      child: Text(
                          place.label.isEmpty || place.label == place.name
                              ? place.name
                              : '${place.label} (${place.name})',
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (chosen) => chosen == null || chosen.isEmpty
                    ? starting.withdraw(entry.name)
                    : starting.grant(entry.name, chosen),
              ),
            ),
        // What it will be given, said before it starts: entry, host, and the names inside. Never a value.
        for (final given in starting.credentials.entries)
          Padding(
            padding: const EdgeInsets.only(top: Space.tight),
            child: Text(
              '${given.key} for ${given.value}'
              '${_host(places, given.value)}: inside the task as PORELO_TOKEN_${Credential.variableOf(given.key)} '
              'and PORELO_URL_${Credential.variableOf(given.key)}, a token worthless anywhere else.',
              key: ValueKey<String>('start-given ${given.key}'),
              style: text.bodySmall,
            ),
          ),
      ],
    );
  }

  /// What its project gives every task, named where the machine says, and said as unnamed where not.
  static List<Widget> _fromTheProject(BuildContext context, Project? project) {
    final text = Theme.of(context).textTheme;
    if (project == null || !project.credentialsAnswered) {
      return <Widget>[
        Text("What its project names under credentials: in project.yml it is given anyway; this "
            'machine does not say what that is.', key: const Key('start-project-credentials-unsaid'),
            style: text.bodySmall),
      ];
    }
    if (project.credentials.isEmpty) {
      return <Widget>[
        Text('Its project gives it no credential of its own.',
            key: const Key('start-project-credentials-none'), style: text.bodySmall),
      ];
    }
    return <Widget>[
      Text('Its project gives it these, and they cannot be pointed elsewhere here:', style: text.bodySmall),
      for (final given in project.credentials.entries)
        Text('${given.key} for ${given.value}: inside the task as PORELO_TOKEN_${Credential.variableOf(given.key)}',
            key: ValueKey<String>('start-project-credential ${given.key}'), style: text.bodySmall),
    ];
  }

  /// The host a place reaches: a destination names a URL, a provider may name the host alone.
  static String _host(List<({String name, String label, String reaches})> places, String name) {
    final reaches = places.where((each) => each.name == name).firstOrNull?.reaches;
    if (reaches == null || reaches.isEmpty) return '';
    final host = Uri.tryParse(reaches)?.host ?? '';
    return ', reaching ${host.isEmpty ? reaches : host}';
  }
}

/// The project's repositories, the project's own first, with **none chosen** until somebody
/// chooses — not even when there is only one.
class _WhichRepository extends StatelessWidget {
  const _WhichRepository({required this.starting});

  final StartWork starting;

  @override
  Widget build(BuildContext context) {
    final project = starting.project!;
    return ChoiceField<String>(
      id: 'start-repository',
      label: 'Which repository',
      value: starting.repository,
      onChanged: (chosen) => chosen == null ? null : starting.chooseRepository(chosen),
      choices: <Choice<String>>[
        // Only where work happens: a project naming others under `repositories:` is never worked
        // in itself, and the person found the two kinds side by side unclear.
        for (final name in project.workRepositories)
          Choice(name, name,
              id: 'start-repository-$name',
              means: project.workRepositories.length < project.repositories.length
                  ? ''
                  : (name == project.ownRepository ? 'The project itself: its code, its file and its planning.' : '')),
      ],
    );
  }
}

/// The ways of being involved: with the agent, by default, or leaving it to run on its own.
class _WhichMode extends StatelessWidget {
  const _WhichMode({required this.starting});

  final StartWork starting;

  @override
  Widget build(BuildContext context) => ChoiceField<Mode>(
        // `Start` would default this — `UNATTENDED` with a prompt, `SHELL` without. Not relied
        // on: work is started *with* a mode, and a screen that picked one quietly
        // would be deciding whether anybody is going to be there.
        id: 'start-mode',
        label: 'How you take part',
        value: starting.mode,
        onChanged: (chosen) => chosen == null ? null : starting.chooseMode(chosen),
        // Two ways: an agent session ends in the container's
        // shell when the agent is left, so a start into a bare shell was a third way to the same
        // place. A shell is offered only to work that was started as one before.
        choices: <Choice<Mode>>[
          // Called a shell, as a person reads it, and the agent is started in it.
          const Choice(Mode.agent, 'A shell, driven by hand', id: 'start-mode-agent',
              means: 'A terminal in the container with the agent already started in it. Leaving the '
                  'agent (/exit) leaves you in the shell.'),
          const Choice(Mode.unattended, 'Unattended, against a prompt', id: 'start-mode-unattended',
              means: 'It runs on its own. Nobody is expected to be watching.'),
          if (starting.mode == Mode.shell)
            const Choice(Mode.shell, 'A bare shell, without the agent', id: 'start-mode-shell',
                means: 'A terminal in the container. The agent does not start: nothing runs until you run it.'),
        ],
      );
}

/// Keeping what is on screen as a recurring job.
///
/// Deliberately at the bottom and deliberately small: a template is worth naming after the choices
/// have been made, not before. Nothing here can carry a setting the dialog above does not show,
/// which is what keeps a template from quietly widening what work may reach.
class _KeepAsTemplate extends StatefulWidget {
  const _KeepAsTemplate({required this.starting, required this.onKeep});

  final StartWork starting;
  final VoidCallback onKeep;

  @override
  State<_KeepAsTemplate> createState() => _KeepAsTemplateState();
}

class _KeepAsTemplateState extends State<_KeepAsTemplate> {
  late final TextEditingController _name =
      TextEditingController(text: widget.starting.templateName);
  bool _kept = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: TextField(
              key: const Key('template-name'),
              controller: _name,
              decoration: const InputDecoration(
                // **Not "a recurring job".** That wording reads as *recurring on its own*, and
                // it misled the backend into answering a question about schedules that nobody
                // asked — there is no scheduler, and a job kept here starts when somebody starts
                // it. Both facts a person would otherwise assume wrongly are said in the helper.
                labelText: 'Save these choices as a job, under a name',
                hintText: 'nightly-tests',
                border: OutlineInputBorder(),
                helperText: 'For starting the same again with one click: it keeps the repository, '
                    'the agent, the mode and the prompt — nothing else. It stays with you rather '
                    'than with the project, and nothing starts it but you. Not the name of this run.',
              ),
              onChanged: (typed) {
                widget.starting.callTheTemplate(typed);
                if (_kept) setState(() => _kept = false);
              },
            ),
          ),
          const SizedBox(width: Space.small),
          Padding(
            padding: const EdgeInsets.only(top: Space.small),
            child: OutlinedButton(
              key: const Key('template-keep'),
              onPressed: widget.starting.asTemplate == null
                  ? null
                  : () {
                      widget.onKeep();
                      setState(() => _kept = true);
                    },
              child: Text(_kept ? 'Kept' : 'Keep'),
            ),
          ),
        ],
      );
}

/// What stands in the way of starting, and what to do about it.
///
/// Coloured by whether the person can act on it here. Unlocking a vault happens at the machine —
/// a daemon has no terminal to take a passphrase at — and that is a different sentence from *this
/// cannot be done*, so it is not drawn as a fault.
class _NotReady extends StatelessWidget {
  const _NotReady({
    required this.starting,
    this.onStoreTheCredential,
    this.onGrant,
    this.onLogIn,
    this.onOpenWithThisDevice,
  });

  final StartWork starting;
  final Future<void> Function()? onStoreTheCredential;
  final Future<void> Function(String entry)? onGrant;
  final Future<void> Function(Agent agent)? onLogIn;
  final Future<void> Function()? onOpenWithThisDevice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final answer = starting.readiness!;
    final elsewhere = answer.outcome.answeredAtTheMachine;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.normal),
      decoration: BoxDecoration(
        color: elsewhere ? scheme.tertiaryContainer : scheme.errorContainer,
        borderRadius: BorderRadius.circular(Radii.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(answer.whatToDo, key: const Key('not-ready')),
          // The daemon's own words, under ours. Never parsed, only shown.
          if (answer.detail.isNotEmpty) ...<Widget>[
            const SizedBox(height: Space.tight),
            Text(answer.detail,
                key: const Key('not-ready-detail'),
                style: Theme.of(context).textTheme.bodySmall),
          ],
          // A host the machine never met: its keys, the one the forge publishes marked and trusted with
          // one press, as binding a machine does; a changed key offers nothing.
          if (answer.hostKeys.isNotEmpty) ...<Widget>[
            const SizedBox(height: Space.small),
            for (final each in answer.hostKeys)
              SelectableText(
                '${each.type}  ${each.fingerprint}'
                '${starting.published.contains(each.fingerprint) ? '  · the forge publishes this key' : ''}',
                key: ValueKey<String>('start-host-key ${each.fingerprint}'),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            if (starting.publishedOffer != null) ...<Widget>[
              const SizedBox(height: Space.small),
              FilledButton(
                key: const Key('start-trust-host-key'),
                onPressed: () => starting.trustThePublishedKey(),
                child: const Text('Trust the key the forge publishes, and ask again'),
              ),
            ] else if (answer.outcome.name == 'UNKNOWN_HOST_KEY')
              Text(
                'None of these is a key the forge kept here publishes, so nothing is trusted from here: '
                'compare one with what the host publishes, and trust it at the machine.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
          // The one way a locked vault opens from here: a device enrolled there, never a passphrase.
          if (onOpenWithThisDevice != null && answer.outcome.name == 'VAULT_LOCKED') ...<Widget>[
            const SizedBox(height: Space.small),
            OutlinedButton.icon(
              key: const Key('open-with-this-device'),
              onPressed: () => onOpenWithThisDevice!(),
              icon: const Icon(Icons.lock_open_outlined, size: Sizes.rowIcon),
              label: const Text('Open it with this device'),
            ),
          ],
          // Granting, once, in a browser: not storing a secret, and not a terminal.
          if (onGrant != null && answer.outcome.name == 'AUTHORIZATION_NEEDED' && answer.credential.isNotEmpty) ...<Widget>[
            const SizedBox(height: Space.small),
            OutlinedButton.icon(
              key: const Key('grant-to-start'),
              onPressed: () => onGrant!(answer.credential),
              icon: const Icon(Icons.verified_user_outlined, size: Sizes.rowIcon),
              label: Text('Grant ${answer.credential} now, in a browser'),
            ),
          ],
          // Not a sentence to act on elsewhere: the way to store it, here, in a terminal there.
          if (onStoreTheCredential != null &&
              const <String>{'CREDENTIAL_MISSING', 'CREDENTIAL_UNUSABLE'}.contains(answer.outcome.name)) ...<Widget>[
            const SizedBox(height: Space.small),
            OutlinedButton.icon(
              key: const Key('store-the-credential'),
              onPressed: () => onStoreTheCredential!(),
              icon: const Icon(Icons.terminal, size: Sizes.rowIcon),
              label: Text('Store ${answer.credential.isEmpty ? 'it' : answer.credential} now, in a '
                  'terminal on the machine'),
            ),
          ],
          if (starting.refusedOutright) ...<Widget>[
            const SizedBox(height: Space.small),
            Text(
              'An unattended run that cannot authenticate is refused before anything is created — '
              'no container, no workspace, nothing to clear up. Nobody would be watching it fail.',
              key: const Key('refused-outright'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (starting.whatItWouldCost != null) ...<Widget>[
            const SizedBox(height: Space.small),
            Text(starting.whatItWouldCost!,
                key: const Key('what-it-would-cost'),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

String _labelOf(Agent agent) => agent.label.isEmpty ? agent.name : agent.label;

/// The sign-in a start needs, at the top of the form: the agent's own login, in a terminal on the
/// machine, and storing a key there as the other way.
class _SignInFirst extends StatelessWidget {
  const _SignInFirst({required this.starting, required this.onLogIn, this.onStoreTheCredential});

  final StartWork starting;
  final Future<void> Function(Agent agent) onLogIn;
  final Future<void> Function()? onStoreTheCredential;

  @override
  Widget build(BuildContext context) {
    final agent = starting.chosenAgent!;
    final label = _labelOf(agent);
    return Container(
      key: const Key('start-sign-in'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Space.normal),
      padding: const EdgeInsets.all(Space.normal),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(Radii.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Sign in to $label first', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Space.tight),
          Text('Nothing is stored for $label on this machine yet. Signing in runs its own login in a '
              'terminal there: you sign in in your browser, and what it gives is kept in the vault, '
              'never by this program. Then work can start.'),
          const SizedBox(height: Space.small),
          Wrap(
            spacing: Space.small,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              FilledButton.icon(
                key: const Key('log-in-with-the-agent'),
                onPressed: () => onLogIn(agent),
                icon: const Icon(Icons.login, size: Sizes.rowIcon),
                label: Text('Sign in to $label'),
              ),
              // The daemon's words: one that does not parse is not offered, rather than thrown on a press.
              if (Uri.tryParse(agent.loginDocumentation) case final page? when page.hasScheme)
                TextButton.icon(
                  key: const Key('login-documentation'),
                  onPressed: () => unawaited(openLink(page)),
                  icon: const Icon(Icons.open_in_new, size: Sizes.rowIcon),
                  label: const Text('How this login works'),
                ),
              if (onStoreTheCredential != null)
                TextButton(
                  key: const Key('store-the-credential'),
                  onPressed: () => onStoreTheCredential!(),
                  child: const Text('or store a key instead'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
