import 'dart:async';
import 'dart:io' show File, FileSystemException;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/commands.dart';
import '../app/identity.dart';
import '../app/key_recovery.dart' show BackupScope;
import '../app/links.dart';
import '../app/machines.dart';
import '../app/session.dart';
import 'pick_a_file.dart';
import 'tokens.dart';
import 'unlock_terminal.dart';
import 'wizard.dart';

/// Opens the person's key and card over the frame.
Future<void> showIdentity(BuildContext context, {IdentityModel? model, OpenTerminal? open}) => showDialog<void>(
  context: context,
  builder: (_) => IdentityDialog(model: model ?? IdentityModel(Identity()), open: open),
);

/// Writes a person's new card to [file]; a card is public, so nothing more is asked of the file.
typedef WriteCard = Future<void> Function(String file, String card);

/// Writes the card to a file of this computer.
Future<void> writeCardFile(String file, String card) => File(file).writeAsString(card);

/// Runs [command] in a terminal the person sees on this computer; answers its exit code and last line.
Future<({int code, String last})> _keyTerminal(
  BuildContext context, {
  required String title,
  required List<String> command,
  OpenTerminal? open,
}) async {
  var last = '';
  final end = await runInATerminal(
    context,
    title: title,
    explanation:
        'KeePassXC asks for its master password in this terminal. It goes to KeePassXC and never through this '
        'program. The new key is kept in KeePassXC only, never in a file.',
    machine: Machine.local(),
    command: command,
    open: open,
    lastLine: (line) => last = line,
    stillWorking: 'Waiting for KeePassXC and its SSH agent.',
  );
  // The end includes a code that arrived while the terminal closed; none seen is -1.
  return (code: end.code ?? -1, last: last);
}

/// The person's one key and card: its state, where it is filed, and the change of its key.
class IdentityDialog extends StatefulWidget {
  /// Constructor taking the model, a fake-backed one in tests, and the terminal opener.
  const IdentityDialog({
    required this.model,
    this.open,
    this.chooseNewFile = chooseWithTheDesktop,
    this.writeCard = writeCardFile,
    super.key,
  });

  /// The identity as Core answers it.
  final IdentityModel model;

  /// Opens the terminal a key is made in; a stand-in in tests.
  final OpenTerminal? open;

  /// Asks where a lost key's new card is saved.
  final ChooseNewFile chooseNewFile;

  /// Writes a lost key's new card.
  final WriteCard writeCard;

  @override
  State<IdentityDialog> createState() => _IdentityDialogState();
}

class _IdentityDialogState extends State<IdentityDialog> {
  IdentityModel get _model => widget.model;
  final _database = TextEditingController();
  final _entry = TextEditingController();
  bool _picking = false;
  bool _newKey = false;

  /// The rotation under review: an agent key, or a new KeePassXC key when [_reviewNew] is set; nothing runs before
  /// the person confirms it.
  AgentKey? _reviewKey;
  bool _reviewNew = false;

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

  void _pick() {
    setState(() {
      _picking = true;
      _newKey = false;
    });
    unawaited(_model.readKeys());
  }

  void _useAnother(PendingIdentityOperation row) {
    _model.startReplacing(row);
    _pick();
  }

  void _picked(AgentKey key) => setState(() {
    _picking = false;
    _reviewKey = key;
    _reviewNew = false;
  });

  /// Runs the reviewed rotation once; the model's guard decides whether it may start.
  Future<void> _confirmRotation() async {
    final key = _reviewKey;
    final viaKeepassxc = _reviewNew;
    setState(() {
      _reviewKey = null;
      _reviewNew = false;
    });
    if (key != null) return _model.rotate(key);
    if (!viaKeepassxc) return;
    final started = _model.rotateInTerminal(database: _database.text.trim(), entry: _entry.text.trim());
    if (started == null) return;
    await _inTerminal(context, _model, 'Change your key', started.command, started.id, widget.open);
  }

  void _cancelRotation() {
    _model.stopReplacing();
    setState(() {
      _reviewKey = null;
      _reviewNew = false;
    });
  }

  Future<void> _makeMyCard() => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => FirstStartWizard(model: _model, open: widget.open),
  );

  List<Command> _commands() => [
    Command(
      id: 'identity.changeKey',
      label: 'Change my key…',
      group: 'My key',
      home: Home.openedView,
      unavailable: _model.whyNotChange,
      run: _pick,
    ),
  ];

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
              if (_model.unfinishedId case final id?) _Unfinished(id: id, model: _model, open: widget.open),
              if (_model.operation case final operation?)
                _OperationView(
                  operation,
                  plan: _model.handoverPlan,
                  chooseNewFile: widget.chooseNewFile,
                  writeCard: widget.writeCard,
                ),
              if (_reviewKey != null || _reviewNew) _rotationReview(context),
              if (_picking)
                _newKey
                    ? _KeepassxcFields(
                        database: _database,
                        entry: _entry,
                        busy: _model.busy,
                        onShow: () => setState(() {
                          _picking = false;
                          _reviewKey = null;
                          _reviewNew = true;
                        }),
                      )
                    : _KeyPicker(
                        model: _model,
                        title: 'Pick your new key',
                        onPicked: _picked,
                        onNewKey: () => setState(() => _newKey = true),
                      ),
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
      Text('Organization', style: text.titleSmall),
      if (card.organization.isEmpty) const Text('No organization is read on this computer yet.'),
      for (final organization in card.organization) _OrganizationRow(organization),
      const SizedBox(height: Space.small),
      Text('Central forge', style: text.titleSmall),
      _ForgeRow(card.forge),
      if (card.pending.isNotEmpty) ...[
        const SizedBox(height: Space.small),
        Text('Unfinished changes', style: text.titleSmall),
        for (final pending in card.pending)
          _PendingChange(
            pending,
            model: _model,
            onUseAnother: pending.action == 'rotate' ? () => _useAnother(pending) : null,
            elsewhere: 'Another key for a lost key is chosen under “Replace a lost key…” on the Organization page.',
          ),
      ],
      const SizedBox(height: Space.small),
      for (final command in _commands()) _CommandButton(command),
    ];
  }

  Widget _rotationReview(BuildContext context) {
    final card = _model.card;
    final to = _reviewKey?.fingerprint ?? 'a new key KeePassXC keeps in ${_database.text.trim()}';
    return Column(
      key: const Key('identity-rotation-review'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Space.small),
        Text('What changing your key does', style: Theme.of(context).textTheme.titleSmall),
        Text('Your key ${card?.fingerprint ?? ''} is replaced by $to.'),
        if (_model.replacing case final row?)
          Text(
            'This starts again under a new ID, in place of the pending change ${row.id}. If that one has reached your '
            'organization, Porelo refuses this and its first card stands.',
          ),
        const Text('Porelo signs the new card with both keys and files it in your organization.'),
        if (_reviewNew) const Text('A terminal opens where KeePassXC asks for its master password.'),
        if (_model.whyNotChange case final why?) Text(why),
        Wrap(
          spacing: Space.small,
          children: [
            TextButton(
              key: const Key('identity-rotation-cancel'),
              onPressed: _cancelRotation,
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('identity-rotation-confirm'),
              onPressed: _model.whyNotChange == null ? () => unawaited(_confirmRotation()) : null,
              child: const Text('Change my key'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Runs a change of key in a terminal the person sees, then takes what it answered.
Future<void> _inTerminal(
  BuildContext context,
  IdentityModel model,
  String title,
  List<String> command,
  String id,
  OpenTerminal? open,
) async {
  final ended = await _keyTerminal(context, title: title, command: command, open: open);
  await model.terminalEnded(code: ended.code, lastLine: ended.last, id: id);
}

/// The keys the agent serves, to choose one from.
class _KeyPicker extends StatelessWidget {
  const _KeyPicker({
    required this.model,
    required this.title,
    required this.onPicked,
    required this.onNewKey,
    this.forLostKey = false,
  });

  final IdentityModel model;
  final bool forLostKey;
  final String title;
  final ValueChanged<AgentKey> onPicked;
  final VoidCallback onNewKey;

  @override
  Widget build(BuildContext context) {
    final keys = model.keys;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Space.small),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        if (keys == null && !model.busy) const Text('Your SSH agent’s keys could not be read.'),
        if (keys != null && keys.isEmpty) const Text('Your SSH agent serves no key.'),
        for (final key in keys ?? const <AgentKey>[])
          ListTile(
            key: Key('identity-key ${key.fingerprint}'),
            title: Text(key.comment.isEmpty ? key.fingerprint : '${key.comment} · ${key.fingerprint}'),
            subtitle: Text(
              model.whyNotSuccessor(key, forLostKey: forLostKey) ??
                  switch (key.keyListed) {
                    true => 'Listed at your forge.',
                    false => 'Not listed at your forge yet.',
                    null => 'Your forge was not asked.',
                  },
            ),
            // An unusable key is shown with its reason and never offered.
            // The current key is never its own successor, least of all when it is lost or stolen.
            enabled: model.whyNotSuccessor(key, forLostKey: forLostKey) == null && !model.busy,
            onTap: () => onPicked(key),
          ),
        TextButton(
          key: const Key('identity-new-in-keepassxc'),
          onPressed: onNewKey,
          child: const Text('Make a new key in KeePassXC instead'),
        ),
      ],
    );
  }
}

/// Where a new key in KeePassXC goes.
class _KeepassxcFields extends StatelessWidget {
  const _KeepassxcFields({required this.database, required this.entry, required this.busy, required this.onShow});

  final TextEditingController database;
  final TextEditingController entry;
  final bool busy;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: Space.small),
      const Text('Porelo makes the key and hands it to KeePassXC; it is never written to a file.'),
      TextField(
        key: const Key('identity-database'),
        controller: database,
        decoration: const InputDecoration(
          labelText: 'Your KeePassXC database',
          helperText: 'The .kdbx file KeePassXC opens, for example ~/Passwords.kdbx',
        ),
      ),
      TextField(
        key: const Key('identity-entry'),
        controller: entry,
        decoration: const InputDecoration(
          labelText: 'Entry (optional)',
          helperText: 'GROUP/NAME of the entry to keep the key in; Porelo names one when empty',
        ),
      ),
      const SizedBox(height: Space.small),
      FilledButton(
        key: const Key('identity-open-terminal'),
        onPressed: busy ? null : onShow,
        child: const Text('Show what it does'),
      ),
    ],
  );
}

/// Replaces the person's own lost key: what it does first, then a new key signed by nothing else, or their backup key.
class ReplaceLostKeyDialog extends StatefulWidget {
  /// Constructor taking the model, the places a backup key may serve and how it is used.
  const ReplaceLostKeyDialog({
    required this.model,
    required this.places,
    required this.useBackup,
    this.open,
    this.chooseNewFile = chooseWithTheDesktop,
    this.writeCard = writeCardFile,
    super.key,
  });

  /// The identity as Core answers it.
  final IdentityModel model;

  /// The places the person holds, for which they may have a backup key.
  final List<BackupScope> places;

  /// Opens the terminal that uses the backup key of a place.
  final Future<void> Function(BackupScope scope) useBackup;

  /// Opens the terminal a key is made in; a stand-in in tests.
  final OpenTerminal? open;

  /// Asks where the new card is saved.
  final ChooseNewFile chooseNewFile;

  /// Writes the new card.
  final WriteCard writeCard;

  @override
  State<ReplaceLostKeyDialog> createState() => _ReplaceLostKeyDialogState();
}

class _ReplaceLostKeyDialogState extends State<ReplaceLostKeyDialog> {
  IdentityModel get _model => widget.model;
  final _database = TextEditingController();
  final _entry = TextEditingController();
  bool _newKey = false;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  Future<void> _read() async {
    await _model.load();
    if (mounted && _model.card != null) await _model.readKeys();
  }

  @override
  void dispose() {
    _database.dispose();
    _entry.dispose();
    super.dispose();
  }

  Future<void> _planInKeepassxc() async {
    if (_database.text.trim().isEmpty) {
      setState(() => _model.problem = 'Name your KeePassXC database file.');
      return;
    }
    await _model.planLostKeyInKeepassxc(database: _database.text.trim(), entry: _entry.text.trim());
  }

  Future<void> _confirmInTerminal() async {
    final started = _model.confirmLostKeyInTerminal();
    if (started == null) return;
    await _inTerminal(context, _model, 'Replace your lost key', started.command, started.id, widget.open);
  }

  void _useAnother(PendingIdentityOperation row) {
    _model.startReplacing(row);
    setState(() => _newKey = false);
    unawaited(_model.readKeys());
  }

  Future<void> _useBackup(BackupScope scope) async {
    await widget.useBackup(scope);
    await _model.load();
  }

  List<Command> get _backupCommands => [
    for (final place in widget.places)
      Command(
        id: 'identity.useBackup ${place.receiptKey}',
        label: 'Use my backup key for ${place.words}…',
        group: 'My key',
        home: Home.openedView,
        unavailable: _model.lostKeyCardMade
            ? null
            : 'First make your new key above: the backup key puts that card in place of the lost key.',
        run: () => unawaited(_useBackup(place)),
      ),
  ];

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('replace-lost-key'),
    title: const Text('Replace a lost key'),
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
              if (_model.firstStart) const Text('You have no card on this computer yet, so no key can be replaced.'),
              if (_model.unfinishedId case final id?) _Unfinished(id: id, model: _model, open: widget.open),
              if (_model.operation case final operation?)
                _OperationView(
                  operation,
                  plan: _model.handoverPlan,
                  chooseNewFile: widget.chooseNewFile,
                  writeCard: widget.writeCard,
                ),
              for (final pending in _model.card?.pending ?? const <PendingIdentityOperation>[])
                _PendingChange(
                  pending,
                  model: _model,
                  onUseAnother: pending.action == 'revoke-lost' ? () => _useAnother(pending) : null,
                  elsewhere: 'Another key for this change is chosen under “My key and card”.',
                ),
              if (_model.lostKeyPlan case final reviewed?)
                _PlanView(
                  reviewed.plan,
                  model: _model,
                  confirm: reviewed.database == null ? _model.confirmLostKey : _confirmInTerminal,
                )
              else if (_model.card != null && (_model.operation == null || _model.replacing != null)) ...[
                if (_model.whyNotLostKey case final why? when !_model.busy) Text(why),
                if (_model.whyNotLostKey == null || _model.busy)
                  _newKey
                      ? _KeepassxcFields(
                          database: _database,
                          entry: _entry,
                          busy: _model.busy,
                          onShow: () => unawaited(_planInKeepassxc()),
                        )
                      : _KeyPicker(
                          model: _model,
                          title: 'Pick the key that replaces the lost one',
                          forLostKey: true,
                          onPicked: (key) => unawaited(_model.planLostKey(key)),
                          onNewKey: () => setState(() => _newKey = true),
                        ),
              ],
              if (_model.card != null)
                for (final command in _backupCommands) _CommandButton(command),
            ],
          ),
        ),
      ),
    ),
    actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
  );
}

/// A change left pending: its state, and the two ways on, or Core's words where the organization already holds it.
class _PendingChange extends StatelessWidget {
  const _PendingChange(this.row, {required this.model, required this.onUseAnother, required this.elsewhere});

  final PendingIdentityOperation row;
  final IdentityModel model;

  /// Starts choosing another key here; null where this dialog does not choose one for this change.
  final VoidCallback? onUseAnother;

  /// Where another key is chosen when not here.
  final String elsewhere;

  @override
  Widget build(BuildContext context) {
    final stands = model.standing(row);
    return Column(
      key: Key('identity-pending ${row.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${row.action} ${row.id}${row.fingerprint == null ? '' : ', to the key ${row.fingerprint}'}'),
        if (stands != null)
          Text(stands, style: TextStyle(color: Theme.of(context).colorScheme.error))
        else ...[
          _CommandButton(
            Command(
              id: 'identity.tryAgain ${row.id}',
              label: 'Try again',
              group: 'My key',
              home: Home.openedView,
              unavailable: model.whyNotTryAgain(row),
              run: () => unawaited(model.tryAgain(row)),
            ),
          ),
          _CommandButton(
            Command(
              id: 'identity.useAnotherKey ${row.id}',
              label: 'Use another key…',
              group: 'My key',
              home: Home.openedView,
              unavailable: model.whyNotReplace(row) ?? (onUseAnother == null ? elsewhere : null),
              run: onUseAnother ?? () {},
            ),
          ),
        ],
      ],
    );
  }
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

class _OrganizationRow extends StatelessWidget {
  const _OrganizationRow(this.organization);

  final IdentityOrganization organization;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.tight),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(organization.address),
        Text(switch (organization.filed) {
          FiledState.done => 'Your card is filed and accepted.',
          FiledState.pending => 'Filed, waiting to be accepted.',
          FiledState.refused => 'Refused: ${organization.why}',
          FiledState.absent => 'Not filed yet.',
          FiledState.unknown => 'Core says “${organization.filedWord}”, which this interface does not know.',
        }),
        if (!organization.mayFile) ...[
          const Text('Your own key may not file it here. Ask one of them:'),
          for (final person in organization.whoMay) _ContactRow(person),
          if (organization.whoMay.isEmpty) const Text('Core names nobody who may.'),
        ],
      ],
    ),
  );
}

class _ContactRow extends StatelessWidget {
  const _ContactRow(this.person);

  final PersonContact person;

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
    if (listing == null) return const Text('No organization is read yet, so no forge is known.');
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
  const _Unfinished({required this.id, required this.model, required this.open});

  final String id;
  final IdentityModel model;
  final OpenTerminal? open;

  Future<void> _retry(BuildContext context) async {
    final command = model.unfinishedCommand;
    if (command == null) return model.retry();
    await _inTerminal(context, model, 'Ask again under the same ID', command, id, open);
  }

  @override
  Widget build(BuildContext context) => Row(
    key: const Key('identity-unfinished'),
    children: [
      Expanded(
        child: Text('The change $id has not answered yet. Retry asks under the same ID, which makes no second.'),
      ),
      TextButton(
        key: const Key('identity-unfinished-retry'),
        onPressed: model.whyNotRetry == null ? () => unawaited(_retry(context)) : null,
        child: const Text('Retry'),
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
  const _OperationView(this.operation, {required this.plan, required this.chooseNewFile, required this.writeCard});

  final IdentityOperation operation;
  final LostKeyPlan? plan;
  final ChooseNewFile chooseNewFile;
  final WriteCard writeCard;

  @override
  Widget build(BuildContext context) {
    final again = operation.again ? ', as Porelo had already made it' : '';
    return Padding(
      key: const Key('identity-operation'),
      padding: const EdgeInsets.only(top: Space.small),
      child: operation.action == 'revoke-lost'
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your new card is made (${operation.id})$again. Nothing is filed and nothing is accepted yet.'),
                if (operation.card case final card?)
                  _NewCard(card, chooseNewFile: chooseNewFile, writeCard: writeCard)
                else
                  const Text(
                    'Core answered no new card, so there is nothing to hand over. Read your card again; Try again asks '
                    'for it under the same ID.',
                    key: Key('identity-lost-no-card'),
                  ),
                if (plan case final plan?)
                  _PlanWords(plan)
                else
                  const Text(
                    'No plan was read in this window, so nobody is named here. An organization owner accepts the '
                    'card; the Organization page lists them.',
                  ),
              ],
            )
          : Text('Your key is changed (${operation.id})$again.'),
    );
  }
}

/// A lost key's new card, public, to hand to an owner outside Porelo; nothing here accepts it.
class _NewCard extends StatefulWidget {
  const _NewCard(this.card, {required this.chooseNewFile, required this.writeCard});

  final String card;
  final ChooseNewFile chooseNewFile;
  final WriteCard writeCard;

  @override
  State<_NewCard> createState() => _NewCardState();
}

class _NewCardState extends State<_NewCard> {
  String? _said;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.card));
    if (mounted) setState(() => _said = 'Copied.');
  }

  Future<void> _save() async {
    final file = await widget.chooseNewFile(title: 'Save my new card');
    if (file == null) return;
    String said;
    try {
      await widget.writeCard(file, widget.card);
      said = 'Saved to $file.';
    } on FileSystemException catch (error) {
      said = 'It could not be saved to $file: ${error.osError?.message ?? error.message}.';
    }
    if (mounted) setState(() => _said = said);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Hand this card to an organization owner outside Porelo. A card is public, so any way will do.'),
      SelectableText(widget.card, key: const Key('identity-lost-card')),
      Wrap(
        spacing: Space.small,
        children: [
          TextButton(
            key: const Key('identity-lost-copy'),
            onPressed: () => unawaited(_copy()),
            child: const Text('Copy the card'),
          ),
          TextButton(
            key: const Key('identity-lost-save'),
            onPressed: () => unawaited(_save()),
            child: const Text('Save the card…'),
          ),
        ],
      ),
      if (_said case final said?) Text(said, key: const Key('identity-lost-said')),
    ],
  );
}

/// What a lost key's plan says: who must accept the new card at each place, and what is made again.
class _PlanWords extends StatelessWidget {
  const _PlanWords(this.plan);

  final LostKeyPlan plan;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Your new card is not signed by the lost key, so each place below waits until someone named accepts it. '
        'If your key was stolen, ask them to revoke it first.',
      ),
      for (final place in plan.places) _PlaceRow(place),
      for (final host in plan.hosts) Text('Your vault on ${host.host} is deleted and made again.'),
      for (final signIn in plan.signIns) Text('On ${signIn.host}, sign in again for: ${signIn.entries.join(', ')}'),
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
      _PlanWords(plan),
      const Text('Porelo files nothing: you hand the new card to one of them yourself, outside Porelo.'),
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

  /// The card's fingerprint before making, so a new KeePassXC key is told from an older card.
  String? _before;

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
    // The key before making is read now, so a card read later than the wizard opened is never taken as new.
    await _model.load();
    if (!mounted || _model.problem != null) return;
    _ran = true;
    _before = _model.card?.fingerprint;
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
      : _whyNotMade == null
      ? WizardActionState.done
      : WizardActionState.refused;

  /// Why the card read is not the newly made, working one; a failed run's problem counts too.
  String? get _whyNotMade =>
      _model.problem ??
      _model.whyNotMade(
        login: _login.text.trim(),
        fingerprint: _choice.value == _KeyChoice.existing ? _chosen.value?.fingerprint : null,
        before: _before,
      );

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
    if (_ran && !_model.busy && card != null && _whyNotMade == null) {
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
    if (!_ran || _model.busy) return const LinearProgressIndicator();
    return _Problem(_whyNotMade ?? 'No card is read.', reason: _model.problemReason, reread: _model.load);
  }
}
