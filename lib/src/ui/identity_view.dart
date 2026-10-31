import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/commands.dart';
import '../app/identity.dart';
import '../app/links.dart';
import '../app/machines.dart';
import '../app/registry.dart' show RegistryContact;
import '../app/session.dart';
import 'tokens.dart';
import 'unlock_terminal.dart';
import 'wizard.dart';

/// Opens the person's key and card over the frame; [checkoutFor] names a registry's local checkout folder.
Future<void> showIdentity(
  BuildContext context, {
  IdentityModel? model,
  OpenTerminal? open,
  String? Function(String address)? checkoutFor,
}) => showDialog<void>(
  context: context,
  builder: (_) => IdentityDialog(
    model: model ?? IdentityModel(Identity(), checkoutFor: checkoutFor),
    open: open,
  ),
);

/// Runs [command] in a terminal the person sees on this computer; answers its exit code and last line.
Future<({int code, String last})> _keyTerminal(
  BuildContext context, {
  required String title,
  required List<String> command,
  OpenTerminal? open,
}) async {
  var code = -1;
  var last = '';
  await runInATerminal(
    context,
    title: title,
    explanation:
        'KeePassXC asks for its master password in this terminal. It goes to KeePassXC and never through this '
        'program. The new key is kept in KeePassXC only, never in a file.',
    machine: Machine.local(),
    command: command,
    open: open,
    onExit: (exit) => code = exit,
    lastLine: (line) => last = line,
    stillWorking: 'Waiting for KeePassXC and its SSH agent.',
  );
  return (code: code, last: last);
}

/// The person's one key and card: its state, where it is filed, and the changes to it.
class IdentityDialog extends StatefulWidget {
  /// Constructor taking the model, a fake-backed one in tests, and the terminal opener.
  const IdentityDialog({required this.model, this.open, super.key});

  /// The identity as Core answers it.
  final IdentityModel model;

  /// Opens the terminal a key is made in; a stand-in in tests.
  final OpenTerminal? open;

  @override
  State<IdentityDialog> createState() => _IdentityDialogState();
}

/// What the key picker is choosing a key for.
enum _Picking { none, rotate, lost }

class _IdentityDialogState extends State<IdentityDialog> {
  IdentityModel get _model => widget.model;
  final _database = TextEditingController();
  final _entry = TextEditingController();
  _Picking _picking = _Picking.none;
  bool _newKey = false;

  @override
  void initState() {
    super.initState();
    unawaited(_model.load());
  }

  @override
  void dispose() {
    for (final field in [_database, _entry]) {
      field.dispose();
    }
    super.dispose();
  }

  void _pick(_Picking what) {
    setState(() {
      _picking = what;
      _newKey = false;
    });
    unawaited(_model.readKeys());
  }

  void _chooseNewKey(_Picking what) => setState(() {
    _picking = what;
    _newKey = true;
  });

  Future<void> _picked(AgentKey key) async {
    final what = _picking;
    setState(() => _picking = _Picking.none);
    switch (what) {
      case _Picking.rotate:
        await _model.rotate(key);
      case _Picking.lost:
        await _model.planLostKey(key);
      case _Picking.none:
        break;
    }
  }

  /// Changes to a new key in KeePassXC in a terminal; the ID is kept first so only Retry follows.
  Future<void> _rotateToNewKey() async {
    final id = newOperationId('rot');
    final List<String> command;
    try {
      command = Identity.rotateInKeepassxc(database: _database.text.trim(), entry: _entry.text.trim(), id: id);
    } on FormatException catch (error) {
      setState(() => _model.problem = error.message);
      return;
    }
    _model.startedInTerminal(id);
    await _inTerminal('Change your key', command, id);
  }

  Future<void> _inTerminal(String title, List<String> command, String id) async {
    setState(() => _picking = _Picking.none);
    final ended = await _keyTerminal(context, title: title, command: command, open: widget.open);
    await _model.terminalEnded(code: ended.code, lastLine: ended.last, id: id);
  }

  /// Shows what a new key in KeePassXC would do for a lost one; nothing is made yet.
  Future<void> _planLostInKeepassxc() async {
    if (_database.text.trim().isEmpty) {
      setState(() => _model.problem = 'Name your KeePassXC database file.');
      return;
    }
    setState(() => _picking = _Picking.none);
    await _model.planLostKeyInKeepassxc(database: _database.text.trim(), entry: _entry.text.trim());
  }

  /// Runs the reviewed lost-key plan once in a terminal, then reads it back by its ID.
  Future<void> _confirmLostInTerminal() async {
    final started = _model.confirmLostKeyInTerminal();
    if (started == null) return;
    await _inTerminal('Replace your lost key', started.command, started.id);
  }

  Future<void> _makeMyCard() => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => FirstStartWizard(model: _model, open: widget.open),
  );

  List<Command> _commands(IdentityCard? card) => [
    Command(
      id: 'identity.changeKey',
      label: 'Change my key…',
      group: 'My key',
      home: Home.openedView,
      unavailable: _model.whyNotChange,
      run: () => _pick(_Picking.rotate),
    ),
    Command(
      id: 'identity.lostKey',
      label: 'I lost my key…',
      group: 'My key',
      home: Home.openedView,
      unavailable: card == null
          ? 'No card is read.'
          : _model.busy
          ? 'Still working.'
          : _model.unfinishedId != null
          ? 'An earlier change has not answered. Retry it first.'
          : null,
      run: () => _pick(_Picking.lost),
    ),
    const Command(
      id: 'identity.backupKey',
      label: 'Make a backup key…',
      group: 'My key',
      home: Home.openedView,
      unavailable: backupKeyRefusal,
      run: _nothing,
    ),
  ];

  static void _nothing() {}

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('identity-dialog'),
    title: const Text('My key and card'),
    content: SizedBox(
      width: Sizes.dialog,
      child: SingleChildScrollView(
        child: ListenableBuilder(
          listenable: _model,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_model.busy) const LinearProgressIndicator(),
              if (_model.problem case final problem?)
                _Problem(problem, reason: _model.problemReason, reread: _model.load),
              if (_model.firstStart) ..._firstStart(context),
              if (_model.card case final card?) ..._card(context, card),
              if (_model.unfinishedId case final id?) _Unfinished(id: id, model: _model),
              if (_model.operation case final operation?) _OperationView(operation, model: _model),
              if (_model.lostKeyPlan case final reviewed?)
                _PlanView(
                  reviewed.plan,
                  model: _model,
                  confirm: reviewed.database == null ? _model.confirmLostKey : _confirmLostInTerminal,
                ),
              if (_picking != _Picking.none) _newKey ? _keepassxc(context) : _keyPicker(context),
            ],
          ),
        ),
      ),
    ),
    actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
  );

  List<Widget> _firstStart(BuildContext context) => [
    const Text('You have no card yet. Your card names you and your one SSH key, which KeePassXC keeps.'),
    const SizedBox(height: Space.small),
    FilledButton(
      key: const Key('identity-make-card'),
      onPressed: _model.busy ? null : () => unawaited(_makeMyCard()),
      child: const Text('Make my card…'),
    ),
  ];

  List<Widget> _card(BuildContext context, IdentityCard card) {
    final text = Theme.of(context).textTheme;
    final error = Theme.of(context).colorScheme.error;
    return [
      Text('${card.name} (${card.login})${card.email == null ? '' : ', ${card.email}'}', style: text.titleMedium),
      SelectableText(card.fingerprint, key: const Key('identity-fingerprint')),
      Text('Valid from ${card.created} until ${card.expires}'),
      if (card.predecessor case final before?) Text('Follows the key $before'),
      Text(switch (card.agent) {
        AgentState.holds => 'Your SSH agent holds this key.',
        AgentState.notHeld =>
          'Waiting for your key: your SSH agent does not hold it. Unlock KeePassXC and load the entry.',
        AgentState.absent => 'Waiting for your key: no SSH agent is reachable. Start KeePassXC with its SSH agent.',
        AgentState.unknown => 'Core says “${card.agentWord}” about your SSH agent, which this interface does not know.',
      }, style: card.agent == AgentState.holds ? null : TextStyle(color: error)),
      if (card.revoked) Text('This key is revoked.', style: TextStyle(color: error)),
      if (card.cardRefused case final why?) Text('Your card does not verify: $why', style: TextStyle(color: error)),
      const SizedBox(height: Space.small),
      Text('Registries', style: text.titleSmall),
      if (card.registry.isEmpty) const Text('No registry is read on this computer yet.'),
      for (final registry in card.registry) _RegistryRow(registry, model: _model),
      if (_model.lastFiled case final filed?)
        Text('Your card is committed as ${filed.commit} (${filed.path}) in your registry checkout, not pushed yet.'),
      const SizedBox(height: Space.small),
      Text('Central forge', style: text.titleSmall),
      _ForgeRow(card.forge),
      if (card.pending.isNotEmpty) ...[
        const SizedBox(height: Space.small),
        Text('Unfinished changes', style: text.titleSmall),
        for (final pending in card.pending)
          Row(
            children: [
              Expanded(child: Text('${pending.action} ${pending.id}')),
              TextButton(
                key: Key('identity-retry ${pending.id}'),
                onPressed: _model.busy ? null : () => unawaited(_model.retry(pending.id)),
                child: const Text('Retry'),
              ),
              TextButton(
                key: Key('identity-read-back ${pending.id}'),
                onPressed: _model.busy ? null : () => unawaited(_model.readBack(pending.id)),
                child: const Text('Read it back'),
              ),
            ],
          ),
      ],
      const SizedBox(height: Space.small),
      for (final command in _commands(card)) _CommandButton(command),
    ];
  }

  Widget _keyPicker(BuildContext context) {
    final keys = _model.keys;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Space.small),
        Text(switch (_picking) {
          _Picking.rotate => 'Pick your new key',
          _Picking.lost => 'Pick the key that replaces the lost one',
          _ => 'Pick your key',
        }, style: Theme.of(context).textTheme.titleSmall),
        if (keys == null && !_model.busy) const Text('Your SSH agent’s keys could not be read.'),
        if (keys != null && keys.isEmpty) const Text('Your SSH agent serves no key.'),
        for (final key in keys ?? const <AgentKey>[])
          ListTile(
            key: Key('identity-key ${key.fingerprint}'),
            title: Text(key.comment.isEmpty ? key.fingerprint : '${key.comment} · ${key.fingerprint}'),
            subtitle: Text(
              key.whyNot ??
                  switch (key.keyListed) {
                    true => 'Listed at your forge.',
                    false => 'Not listed at your forge yet.',
                    null => 'Your forge was not asked.',
                  },
            ),
            // An unusable key is shown with its reason and never offered.
            enabled:
                key.usable &&
                !_model.busy &&
                (_picking != _Picking.rotate || key.fingerprint != _model.card?.fingerprint),
            onTap: () => unawaited(_picked(key)),
          ),
        TextButton(
          key: const Key('identity-new-in-keepassxc'),
          onPressed: () => _chooseNewKey(_picking),
          child: const Text('Make a new key in KeePassXC instead'),
        ),
      ],
    );
  }

  Widget _keepassxc(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: Space.small),
      const Text('Porelo makes the key and hands it to KeePassXC; it is never written to a file.'),
      TextField(
        key: const Key('identity-database'),
        controller: _database,
        decoration: const InputDecoration(
          labelText: 'Your KeePassXC database',
          helperText: 'The .kdbx file KeePassXC opens, for example ~/Passwords.kdbx',
        ),
      ),
      TextField(
        key: const Key('identity-entry'),
        controller: _entry,
        decoration: const InputDecoration(
          labelText: 'Entry (optional)',
          helperText: 'GROUP/NAME of the entry to keep the key in; Porelo names one when empty',
        ),
      ),
      const SizedBox(height: Space.small),
      FilledButton(
        key: const Key('identity-open-terminal'),
        onPressed: _model.busy
            ? null
            : () => unawaited(_picking == _Picking.lost ? _planLostInKeepassxc() : _rotateToNewKey()),
        child: Text(_picking == _Picking.lost ? 'Show what it does' : 'Open the terminal'),
      ),
    ],
  );
}

class _CommandButton extends StatelessWidget {
  const _CommandButton(this.command);

  final Command command;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton(key: Key(command.id), onPressed: command.available ? command.run : null, child: Text(command.label)),
      if (command.unavailable case final reason?) Text(reason, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _Problem extends StatelessWidget {
  const _Problem(this.words, {required this.reason, required this.reread});

  final String words;
  final String? reason;
  final Future<void> Function() reread;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Column(
      key: const Key('identity-problem'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(words, style: TextStyle(color: error)),
        if (reason == 'key-not-served')
          const Text(
            'KeePassXC kept the key but its SSH agent does not serve it: the database is not open, or its SSH agent '
            'integration is off. Fix either, then read your card again.',
          ),
        TextButton(
          key: const Key('identity-reread'),
          onPressed: () => unawaited(reread()),
          child: const Text('Read my card again'),
        ),
      ],
    );
  }
}

class _RegistryRow extends StatelessWidget {
  const _RegistryRow(this.registry, {required this.model});

  final IdentityRegistry registry;
  final IdentityModel model;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.tight),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(registry.address),
        Text(switch (registry.filed) {
          FiledState.done => 'Your card is filed and accepted.',
          FiledState.pending => 'Filed, waiting to be accepted.',
          FiledState.refused => 'Refused: ${registry.why}',
          FiledState.absent => 'Not filed yet.',
          FiledState.unknown => 'Core says “${registry.filedWord}”, which this interface does not know.',
        }),
        if (registry.mayFile &&
            (model.filingUnanswered(registry) ||
                registry.filed == FiledState.absent ||
                registry.filed == FiledState.refused))
          _CommandButton(
            Command(
              id: 'identity.fileCard ${registry.address}',
              label: model.filingUnanswered(registry) ? 'Retry filing my card' : 'File my card',
              group: 'My key',
              home: Home.openedView,
              unavailable: model.whyNotFile(registry),
              run: () => unawaited(model.fileCard(registry)),
            ),
          ),
        if (!registry.mayFile) ...[
          const Text('Your own key may not file it here. Ask one of them:'),
          for (final person in registry.whoMay) _ContactRow(person),
          if (registry.whoMay.isEmpty) const Text('Core names nobody who may.'),
        ],
      ],
    ),
  );
}

class _ContactRow extends StatelessWidget {
  const _ContactRow(this.person);

  final RegistryContact person;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text('${person.name} (${person.login})${person.email == null ? '' : ', ${person.email}'}')),
      if (person.email case final email?) ...[
        TextButton(
          onPressed: () => unawaited(openLink(Uri(scheme: 'mailto', path: email))),
          child: const Text('Write'),
        ),
        TextButton(
          onPressed: () => unawaited(Clipboard.setData(ClipboardData(text: email))),
          child: const Text('Copy'),
        ),
      ],
    ],
  );
}

class _ForgeRow extends StatelessWidget {
  const _ForgeRow(this.forge);

  final ForgeKeyListing? forge;

  @override
  Widget build(BuildContext context) {
    final listing = forge;
    if (listing == null) return const Text('No registry is read yet, so no forge is known.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(switch (listing.keyListed) {
          true => 'Your key is among ${listing.login}’s public keys.',
          false => 'Your key is not among ${listing.login}’s public keys. Add it on your account page.',
          null => 'The forge lists no public keys or could not be asked; an admin confirms your fingerprint instead.',
        }),
        Wrap(
          spacing: Space.small,
          children: [
            TextButton(
              onPressed: () => unawaited(openLink(Uri.parse(listing.keysUrl))),
              child: const Text('Your listed keys'),
            ),
            TextButton(
              key: const Key('identity-account-page'),
              onPressed: () => unawaited(openLink(Uri.parse(listing.accountUrl))),
              child: const Text('Add a key at the forge'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Unfinished extends StatelessWidget {
  const _Unfinished({required this.id, required this.model});

  final String id;
  final IdentityModel model;

  @override
  Widget build(BuildContext context) => Row(
    key: const Key('identity-unfinished'),
    children: [
      Expanded(child: Text('The change $id has not answered yet. Retry sends only what is not done.')),
      TextButton(
        key: const Key('identity-unfinished-retry'),
        onPressed: model.busy ? null : () => unawaited(model.retry(id)),
        child: const Text('Retry'),
      ),
      TextButton(
        key: const Key('identity-unfinished-read-back'),
        onPressed: model.busy ? null : () => unawaited(model.readBack(id)),
        child: const Text('Read it back'),
      ),
    ],
  );
}

String _placeWords(PublishedPlace place) => switch (place.status) {
  PlaceState.done => 'done',
  PlaceState.pending => 'pending${place.why == null ? '' : ': ${place.why}'}',
  PlaceState.refused => 'refused: ${place.why}',
  PlaceState.planned => 'planned${place.why == null ? '' : ': ${place.why}'}',
  PlaceState.unknown => 'Core says “${place.statusWord}”, which this interface does not know',
};

class _PlaceRow extends StatelessWidget {
  const _PlaceRow(this.place);

  final PublishedPlace place;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('${place.where} ${place.name}: ${_placeWords(place)}'),
      for (final person in place.whoMay) _ContactRow(person),
    ],
  );
}

class _OperationView extends StatelessWidget {
  const _OperationView(this.operation, {required this.model});

  final IdentityOperation operation;
  final IdentityModel model;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('identity-operation'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: Space.small),
      Text(
        '${operation.action == 'revoke-lost' ? 'Replacing your lost key' : 'Changing your key'} (${operation.id})',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      Text('From ${operation.predecessor} to ${operation.fingerprint}'),
      for (final place in operation.published) _PlaceRow(place),
      if (!operation.finished)
        TextButton(
          key: const Key('identity-operation-retry'),
          onPressed: model.busy ? null : () => unawaited(model.retry(operation.id)),
          child: const Text('Retry what is not done'),
        ),
    ],
  );
}

class _PlanView extends StatelessWidget {
  const _PlanView(this.plan, {required this.model, required this.confirm});

  final LostKeyPlan plan;
  final IdentityModel model;
  final Future<void> Function() confirm;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('identity-lost-plan'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: Space.small),
      Text('What replacing your lost key does', style: Theme.of(context).textTheme.titleSmall),
      const Text(
        'Your new card is not signed by the lost key, so each place below waits until someone named accepts it. '
        'If your key was stolen, ask them to revoke it first.',
      ),
      for (final place in plan.places) _PlaceRow(place),
      for (final host in plan.hosts) Text('Your vault on ${host.host} is deleted and made again.'),
      for (final signIn in plan.signIns) Text('On ${signIn.host}, sign in again for: ${signIn.entries.join(', ')}'),
      Wrap(
        spacing: Space.small,
        children: [
          TextButton(
            key: const Key('identity-lost-cancel'),
            onPressed: model.cancelLostKey,
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('identity-lost-confirm'),
            onPressed: model.busy ? null : () => unawaited(confirm()),
            child: const Text('Replace my key'),
          ),
        ],
      ),
    ],
  );
}

/// Which kind of key the first card is made for.
enum _KeyChoice { existing, keepassxc }

/// The first start: who you are, which key, a summary, then Core makes the card.
///
/// **Making the card runs once**: coming back to its step reads the card again, never a second create.
class FirstStartWizard extends StatefulWidget {
  /// Constructor taking the model and the terminal opener, stand-ins in tests.
  const FirstStartWizard({required this.model, this.open, super.key});

  /// The identity as Core answers it.
  final IdentityModel model;

  /// Opens the terminal a new key is made in.
  final OpenTerminal? open;

  @override
  State<FirstStartWizard> createState() => _FirstStartWizardState();
}

class _FirstStartWizardState extends State<FirstStartWizard> {
  IdentityModel get _model => widget.model;
  final _login = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _database = TextEditingController();
  final _entry = TextEditingController();
  final _choice = ValueNotifier<_KeyChoice?>(null);
  final _chosen = ValueNotifier<AgentKey?>(null);
  late final _changes = Listenable.merge([_model, _login, _name, _email, _database, _entry, _choice, _chosen]);
  bool _ran = false;

  @override
  void dispose() {
    for (final field in [_login, _name, _email, _database, _entry]) {
      field.dispose();
    }
    _choice.dispose();
    _chosen.dispose();
    super.dispose();
  }

  void _choose(_KeyChoice choice) {
    _choice.value = choice;
    if (choice == _KeyChoice.existing && _model.keys == null) unawaited(_model.readKeys());
  }

  Future<void> _make() async {
    // Once made or tried, only a read follows: a second create could make a second key.
    if (_ran) return _model.load();
    _ran = true;
    final email = _email.text.trim();
    if (_choice.value == _KeyChoice.existing) {
      final key = _chosen.value;
      if (key == null) return;
      await _model.useExistingKey(login: _login.text.trim(), name: _name.text.trim(), email: email, key: key);
      return;
    }
    final command = Identity.createInKeepassxc(
      login: _login.text.trim(),
      name: _name.text.trim(),
      email: email,
      database: _database.text.trim(),
      entry: _entry.text.trim(),
    );
    final ended = await _keyTerminal(context, title: 'Make your key', command: command, open: widget.open);
    await _model.terminalEnded(code: ended.code, lastLine: ended.last);
  }

  WizardActionState get _state => !_ran || _model.busy
      ? WizardActionState.running
      : _model.card != null
      ? WizardActionState.done
      : WizardActionState.refused;

  @override
  Widget build(BuildContext context) => Wizard(
    title: 'Make your card',
    changes: _changes,
    action: 'Make my card',
    actionKey: const Key('identity-wizard-make'),
    reviewWords: 'Core makes your card from these answers. Nothing is made before you start it here.',
    steps: [
      WizardStep(
        title: 'Who you are',
        words: 'Your card names you. Others read these values when they let you into a project or a host.',
        panel: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('identity-login'),
              controller: _login,
              decoration: const InputDecoration(
                labelText: 'Your login',
                helperText: 'Your user name at the central forge, as in its address github.com/<login>',
              ),
            ),
            TextField(
              key: const Key('identity-name'),
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Your name',
                helperText: 'Your full name, as others should read it on your card',
              ),
            ),
            TextField(
              key: const Key('identity-email'),
              controller: _email,
              decoration: const InputDecoration(
                labelText: 'Your email (optional)',
                helperText: 'The address others write to about your access; leave it empty to name none',
              ),
            ),
          ],
        ),
        check: () => _login.text.trim().isEmpty
            ? 'Enter your login at the central forge.'
            : _name.text.trim().isEmpty
            ? 'Enter your name.'
            : null,
        summary: () => [
          'Login: ${_login.text.trim()}',
          'Name: ${_name.text.trim()}',
          'Email: ${_email.text.trim().isEmpty ? 'none' : _email.text.trim()}',
        ],
      ),
      WizardStep(
        title: 'Which key',
        words:
            'Your one SSH key is kept by KeePassXC and served by its SSH agent. Use a key it already serves, or have '
            'Porelo make a new one into your KeePassXC database.',
        panel: (context) => _whichKey(context),
        check: () => switch (_choice.value) {
          null => 'Choose your existing key or a new one.',
          _KeyChoice.existing when _chosen.value == null => 'Pick one of the keys your SSH agent serves.',
          _KeyChoice.keepassxc when _database.text.trim().isEmpty => 'Name your KeePassXC database file.',
          _ => null,
        },
        summary: () => switch (_choice.value) {
          _KeyChoice.existing => ['Your existing key ${_chosen.value?.fingerprint ?? ''}'],
          _KeyChoice.keepassxc => [
            'A new key in ${_database.text.trim()}'
                '${_entry.text.trim().isEmpty ? '' : ', entry ${_entry.text.trim()}'}',
            'A terminal opens where KeePassXC asks for its master password.',
          ],
          null => ['No key chosen'],
        },
      ),
    ],
    actionSteps: [
      WizardActionStep(
        title: 'Your card',
        words: 'Core makes your card and checks that your SSH agent serves its key.',
        panel: (context) => _result(context),
        run: _make,
        state: () => _state,
      ),
    ],
  );

  Widget _whichKey(BuildContext context) {
    final keys = _model.keys;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Space.small,
          children: [
            ChoiceChip(
              key: const Key('identity-use-existing'),
              label: const Text('Use my existing key'),
              selected: _choice.value == _KeyChoice.existing,
              onSelected: (_) => _choose(_KeyChoice.existing),
            ),
            ChoiceChip(
              key: const Key('identity-make-new'),
              label: const Text('Make a new key'),
              selected: _choice.value == _KeyChoice.keepassxc,
              onSelected: (_) => _choose(_KeyChoice.keepassxc),
            ),
          ],
        ),
        if (_choice.value == _KeyChoice.existing) ...[
          if (_model.busy) const LinearProgressIndicator(),
          if (_model.problem case final problem?) Text(problem),
          if (keys != null && keys.isEmpty) const Text('Your SSH agent serves no key.'),
          for (final key in keys ?? const <AgentKey>[])
            ListTile(
              key: Key('identity-key ${key.fingerprint}'),
              selected: _chosen.value?.fingerprint == key.fingerprint,
              title: Text(key.comment.isEmpty ? key.fingerprint : '${key.comment} · ${key.fingerprint}'),
              subtitle: Text(key.whyNot ?? 'Ed25519, usable for your card.'),
              // An unusable key is shown with its reason and never offered.
              enabled: key.usable,
              onTap: () => _chosen.value = key,
            ),
        ],
        if (_choice.value == _KeyChoice.keepassxc) ...[
          TextField(
            key: const Key('identity-database'),
            controller: _database,
            decoration: const InputDecoration(
              labelText: 'Your KeePassXC database',
              helperText: 'The .kdbx file KeePassXC opens, shown in its title bar, for example ~/Passwords.kdbx',
            ),
          ),
          TextField(
            key: const Key('identity-entry'),
            controller: _entry,
            decoration: const InputDecoration(
              labelText: 'Entry (optional)',
              helperText: 'GROUP/NAME of the entry to keep the key in; Porelo names one when empty',
            ),
          ),
        ],
      ],
    );
  }

  Widget _result(BuildContext context) {
    final card = _model.card;
    if (card != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your card is made.'),
          SelectableText(card.fingerprint),
          if (card.forge?.keyListed == false) const Text('Add this key at your forge; the card page links it.'),
        ],
      );
    }
    if (_model.problem case final problem?) {
      return _Problem(problem, reason: _model.problemReason, reread: _model.load);
    }
    return const LinearProgressIndicator();
  }
}
