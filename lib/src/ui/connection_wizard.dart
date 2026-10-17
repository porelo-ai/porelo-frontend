import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:guided_walk/guided_walk.dart';
import 'package:porelo_frontend/client.dart';

import '../app/connections.dart';
import 'choice_field.dart';
import 'pick_a_file.dart';
import 'tokens.dart';
import 'dialog_scroll.dart';

/// What a value kept outside the vault means, said wherever such a value is chosen or shown.
const notInTheVault =
    'Not in the vault: it is kept in plain form on the machine, where anyone who '
    "can read this account's files can read it, and shutting the vault does not protect it.";

/// How the value of a new connection reaches the machine once it is declared.
enum Storing {
  /// It is already where the record says: a file or a variable there.
  nothing,

  /// A private key of this computer, sent to the machine's store command on its standard input.
  sendTheKey,

  /// The machine copies a key from its own disk into its vault; nothing is sent.
  onTheMachine,

  /// A token or a password, typed into a terminal on the machine — never into this interface.
  inATerminal,
}

/// What the wizard settled on.
///
/// [key] is the one secret this interface ever carries: a private key of this computer, handed on
/// once to be sent and then dropped.
class NewConnection {
  /// Constructor taking every field.
  const NewConnection({
    required this.kind,
    required this.match,
    required this.purpose,
    required this.source,
    required this.storing,
    this.id,
    this.user,
    this.fromFile,
    this.key,
  });

  final String kind;
  final String match;
  final String purpose;
  final String source;
  final Storing storing;
  final String? id;
  final String? user;
  final String? fromFile;
  final String? key;
}

/// The purposes a machine accepts, from Porelo's own list: only `git` is read today.
const _purposes = <Choice<String>>[
  Choice('git', 'git — fetching and pushing repositories', id: 'purpose-git'),
  Choice('any', 'any use', id: 'purpose-any'),
];

/// Where the value comes from, by kind. A key, a token and a password each have their own ways.
enum _Way { onTheMachine, ofThisComputer, variable, vault, variables }

/// Asks, step by step, for a connection to declare: what it is, where its value comes from, and
/// — asked of the machine without writing anything — whether it would work.
///
/// [keys] lists the machine's own ssh keys; [check] is a dry run of the declaration.
Future<NewConnection?> askForAConnection(
  BuildContext context, {
  String match = '',
  required Future<List<SshKey>> Function() keys,
  required Future<CredentialDeclared> Function(NewConnection asked) check,
  required PickAFile pick,
  String keysAt = '',
  Future<void> Function()? makeTheVault,
  Future<void> Function()? openTheVault,
}) => showDialog<NewConnection>(
  context: context,
  builder: (context) => _ConnectionWizard(
    match: match,
    keys: keys,
    check: check,
    pick: pick,
    keysAt: keysAt,
    makeTheVault: makeTheVault,
    openTheVault: openTheVault,
  ),
);

class _ConnectionWizard extends StatefulWidget {
  const _ConnectionWizard({
    required this.match,
    required this.keys,
    required this.check,
    required this.pick,
    required this.keysAt,
    this.makeTheVault,
    this.openTheVault,
  });

  /// Makes the machine's vault in a terminal there, or null where nothing here reaches that machine.
  final Future<void> Function()? makeTheVault;

  /// Opens the machine's vault in a terminal there, or null likewise.
  final Future<void> Function()? openTheVault;

  final String match;
  final Future<List<SshKey>> Function() keys;
  final Future<CredentialDeclared> Function(NewConnection asked) check;
  final PickAFile pick;
  final String keysAt;

  @override
  State<_ConnectionWizard> createState() => _ConnectionWizardState();
}

class _ConnectionWizardState extends State<_ConnectionWizard> {
  int _step = 0;

  late final _match = TextEditingController(text: widget.match);
  String? _kind;
  String _purpose = 'git';

  _Way? _way;
  String _keyPath = '';
  bool _intoTheVault = false;
  final _key = TextEditingController();
  String? _keyRefused;
  final _variable = TextEditingController();
  final _user = TextEditingController();
  final _userVariable = TextEditingController();
  Future<List<SshKey>>? _keys;

  CredentialDeclared? _checked;
  String? _checkFailed;

  @override
  void dispose() {
    for (final each in <TextEditingController>[_match, _key, _variable, _user, _userVariable]) {
      each.dispose();
    }
    super.dispose();
  }

  List<Choice<_Way>> get _ways => switch (_kind) {
    'SSH_KEY' => const <Choice<_Way>>[
      Choice(_Way.onTheMachine, 'A key already on the machine', id: 'way-machine'),
      Choice(_Way.ofThisComputer, 'A key of this computer, sent into the vault', id: 'way-computer'),
      Choice(_Way.variable, 'A variable on the machine', id: 'way-variable'),
    ],
    'TOKEN' => const <Choice<_Way>>[
      Choice(_Way.vault, 'In the vault, typed at the machine', id: 'way-vault'),
      Choice(_Way.variable, 'A variable on the machine', id: 'way-variable'),
    ],
    'BASIC' => const <Choice<_Way>>[
      Choice(_Way.vault, 'In the vault, the password typed at the machine', id: 'way-vault'),
      Choice(_Way.variables, 'Two variables on the machine', id: 'way-variables'),
    ],
    _ => const <Choice<_Way>>[],
  };

  /// What the choices so far describe, the key's contents included only where it is sent.
  NewConnection get _asked {
    final kind = _kind!;
    final match = _match.text.trim();
    return switch (_way!) {
      _Way.onTheMachine when _intoTheVault => NewConnection(
        kind: kind,
        match: match,
        purpose: _purpose,
        source: 'VAULT',
        fromFile: _keyPath,
        storing: Storing.onTheMachine,
      ),
      _Way.onTheMachine => NewConnection(
        kind: kind,
        match: match,
        purpose: _purpose,
        source: 'FILE',
        id: _keyPath,
        storing: Storing.nothing,
      ),
      _Way.ofThisComputer => NewConnection(
        kind: kind,
        match: match,
        purpose: _purpose,
        source: 'VAULT',
        key: _key.text,
        storing: Storing.sendTheKey,
      ),
      _Way.variable => NewConnection(
        kind: kind,
        match: match,
        purpose: _purpose,
        source: 'ENVIRONMENT',
        id: _variable.text.trim(),
        storing: Storing.nothing,
      ),
      _Way.vault => NewConnection(
        kind: kind,
        match: match,
        purpose: _purpose,
        source: 'VAULT',
        user: _user.text.trim().isEmpty ? null : _user.text.trim(),
        storing: Storing.inATerminal,
      ),
      _Way.variables => NewConnection(
        kind: kind,
        match: match,
        purpose: _purpose,
        source: 'ENVIRONMENT',
        id: _variable.text.trim(),
        user: '\$${_userVariable.text.trim()}',
        storing: Storing.nothing,
      ),
    };
  }

  bool get _describedEnough => _match.text.trim().isNotEmpty && _kind != null;

  bool get _valueEnough => switch (_way) {
    null => false,
    _Way.onTheMachine => _keyPath.isNotEmpty && !_keyPath.endsWith('.pub'),
    _Way.ofThisComputer => _key.text.trim().isNotEmpty,
    _Way.variable => _variable.text.trim().isNotEmpty,
    _Way.vault => true,
    _Way.variables => _variable.text.trim().isNotEmpty && _userVariable.text.trim().isNotEmpty,
  };

  void _choose(void Function() change) => setState(() {
    change();
    _checks++;
    _checked = null;
    _checkFailed = null;
  });

  /// Counts the checks, so the answer to an earlier declaration never lands on a later one.
  int _checks = 0;

  /// Back never carries a secret: a key sent from here is chosen again.
  void _back() => _choose(() {
    _key.clear();
    _keyRefused = null;
    _step--;
  });

  Future<void> _next() async {
    if (_step == 1 && _way == _Way.ofThisComputer) {
      final refused = notAPrivateKey(_key.text);
      if (refused != null) {
        // Out of the field at once: what was put there is not kept, whatever it was.
        _key.clear();
        setState(() => _keyRefused = refused);
        return;
      }
    }
    _choose(() => _step++);
    if (_step == 2) await _check();
  }

  Future<void> _check() async {
    final asking = ++_checks;
    bool current() => mounted && asking == _checks;
    try {
      final answer = await widget.check(_asked);
      if (current()) setState(() => _checked = answer);
    } on FeatureNotSupported catch (ex) {
      if (current()) setState(() => _checkFailed = '$ex');
    } on Exception catch (ex) {
      if (current()) setState(() => _checkFailed = 'The machine could not be asked: $ex');
    }
  }

  Future<void> _fillFromAFile() async {
    final chosen = await widget.pick(
      initialDirectory: widget.keysAt.isEmpty ? null : widget.keysAt,
      title: 'Use this key',
    );
    if (chosen == null || !mounted) return;
    try {
      // Whole and at once: a key is a few hundred bytes, and a widget test cannot wait on real I/O.
      final read = File(chosen).readAsStringSync();
      _choose(() {
        _key.text = read;
        _keyRefused = notAPrivateKey(read);
        if (_keyRefused != null) _key.clear();
      });
    } on FileSystemException catch (ex) {
      setState(() => _keyRefused = 'That file could not be read: ${ex.osError?.message ?? ex.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = <String>['What it is', 'Where its value comes from', 'Whether it would work'];
    return AlertDialog(
      key: const Key('connection-wizard'),
      title: Text('Add a connection — ${_step + 1} of 3: ${steps[_step]}'),
      content: SizedBox(
        width: Sizes.dialog,
        child: DialogScroll(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            // A floating label rises above its field, into one that touches it.
            spacing: Space.small,
            children: switch (_step) {
              0 => _whatItIs(),
              1 => _whereItsValueComesFrom(),
              _ => _whetherItWouldWork(context),
            },
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('connection-leave'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Leave it'),
        ),
        if (_step > 0) TextButton(key: const Key('wizard-back'), onPressed: _back, child: const Text('Back')),
        if (_step < 2)
          FilledButton(
            key: const Key('wizard-next'),
            onPressed: (_step == 0 ? _describedEnough : _valueEnough) ? () => unawaited(_next()) : null,
            child: const Text('Next'),
          )
        else
          FilledButton(
            key: const Key('connection-add'),
            onPressed: _checked?.canBeAdded ?? false ? () => Navigator.of(context).pop(_asked) : null,
            child: const Text('Add it'),
          ),
      ],
    );
  }

  List<Widget> _whatItIs() => <Widget>[
    TextField(
      key: const Key('connection-match'),
      controller: _match,
      onChanged: (_) => _choose(() {}),
      decoration: const InputDecoration(
        labelText: 'Where it connects to — ssh://github.com, https://gitlab.example/acme/',
      ),
    ),
    ChoiceField<String>(
      id: 'connection-kind',
      label: 'What it is',
      value: _kind,
      onChanged: (chosen) => _choose(() {
        _kind = chosen;
        _way = null;
      }),
      choices: const <Choice<String>>[
        Choice('SSH_KEY', 'An ssh key', id: 'kind-SSH_KEY'),
        Choice(
          'TOKEN',
          'A token',
          id: 'kind-TOKEN',
          means: 'A restricted, read-only token is enough to follow a repository.',
        ),
        Choice('BASIC', 'A user and password', id: 'kind-BASIC'),
      ],
    ),
    ChoiceField<String>(
      id: 'connection-purpose',
      label: 'What it is for',
      value: _purpose,
      onChanged: (chosen) => _choose(() => _purpose = chosen ?? 'git'),
      choices: _purposes,
    ),
  ];

  List<Widget> _whereItsValueComesFrom() {
    final way = _way;
    return <Widget>[
      ChoiceField<_Way>(
        id: 'connection-way',
        label: 'Where its value comes from',
        value: way,
        onChanged: (chosen) => _choose(() {
          _way = chosen;
          if (chosen == _Way.onTheMachine) _keys ??= widget.keys()..ignore();
        }),
        choices: _ways,
      ),
      if (way == _Way.onTheMachine) ...<Widget>[
        KeyOnTheMachine(
          keys: _keys!,
          chosen: _keyPath,
          // Trimmed once, where it is kept: the check and what is sent then read the same path.
          onChosen: (path) => _choose(() => _keyPath = path.trim()),
          onTyped: (path) => _choose(() => _keyPath = path.trim()),
        ),
        ChoiceField<bool>(
          id: 'connection-keep',
          label: 'What becomes of it',
          value: _intoTheVault,
          onChanged: (chosen) => _choose(() => _intoTheVault = chosen ?? false),
          choices: const <Choice<bool>>[
            Choice(false, 'Used where it lies', id: 'keep-where-it-lies', means: notInTheVault),
            Choice(
              true,
              'Copied into the vault by the machine',
              id: 'keep-in-the-vault',
              means:
                  'The machine reads the file from its own disk; nothing of it passes through '
                  'this program. The file stays where it is.',
            ),
          ],
        ),
      ],
      if (way == _Way.ofThisComputer) ...<Widget>[
        // A private key: blanked, and left out of what a walk writes down.
        WalkSecret(
          child: TextField(
            key: const Key('connection-private-key'),
            controller: _key,
            minLines: 3,
            maxLines: 6,
            onChanged: (_) => _choose(() => _keyRefused = null),
            decoration: InputDecoration(
              labelText: 'The private key — pasted, or filled from a file below',
              errorText: _keyRefused,
              errorMaxLines: 3,
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        OutlinedButton.icon(
          key: const Key('connection-key-from-file'),
          onPressed: () => unawaited(_fillFromAFile()),
          icon: const Icon(Icons.folder_open, size: Sizes.rowIcon),
          label: const Text('Fill it from a key file of this computer'),
        ),
      ],
      if (way == _Way.variable)
        TextField(
          key: const Key('connection-variable'),
          controller: _variable,
          onChanged: (_) => _choose(() {}),
          decoration: const InputDecoration(labelText: 'The variable, as it is set on the machine'),
        ),
      if (way == _Way.vault && _kind == 'BASIC')
        TextField(
          key: const Key('connection-user'),
          controller: _user,
          onChanged: (_) => _choose(() {}),
          decoration: const InputDecoration(labelText: 'The user'),
        ),
      if (way == _Way.variables) ...<Widget>[
        TextField(
          key: const Key('connection-user-variable'),
          controller: _userVariable,
          onChanged: (_) => _choose(() {}),
          decoration: const InputDecoration(labelText: "The variable holding the user's name"),
        ),
        TextField(
          key: const Key('connection-variable'),
          controller: _variable,
          onChanged: (_) => _choose(() {}),
          decoration: const InputDecoration(labelText: 'The variable holding the password'),
        ),
      ],
      if (way != null)
        Text(_whereItLives(way), key: const Key('connection-lives'), style: Theme.of(context).textTheme.bodySmall),
    ];
  }

  String _whereItLives(_Way way) => switch (way) {
    _Way.onTheMachine when _intoTheVault => 'Its value will live in the vault.',
    _Way.onTheMachine => 'Its value lives in that file on the machine. $notInTheVault',
    _Way.ofThisComputer =>
      'Its value will live in the vault. The key is sent there once, and '
          'nothing of it is kept here.',
    _Way.variable || _Way.variables => 'Its value lives in the environment on the machine. $notInTheVault',
    _Way.vault =>
      'Its value will live in the vault. After adding it, a terminal on the machine '
          'opens to type it there; it never passes through this program.',
  };

  /// A vault that is not there, or shut, is fixed at the machine — and then asked about again.
  List<Widget> _aboutTheVault(String outcome) {
    final act = switch (outcome) {
      'NO_VAULT' => (widget.makeTheVault, 'connection-make-vault', 'Make the vault on the machine'),
      'VAULT_LOCKED' => (widget.openTheVault, 'connection-open-vault', 'Open the vault on the machine'),
      _ => null,
    };
    if (act == null || act.$1 == null) return const <Widget>[];
    return <Widget>[
      OutlinedButton(
        key: Key(act.$2),
        onPressed: () async {
          await act.$1!();
          if (!mounted) return;
          _choose(() {});
          await _check();
        },
        child: Text(act.$3),
      ),
    ];
  }

  List<Widget> _whetherItWouldWork(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final checked = _checked;
    if (_checkFailed != null) {
      return <Widget>[Text(_checkFailed!, key: const Key('connection-check-failed'))];
    }
    if (checked == null) {
      return <Widget>[const Text('Asking the machine, without writing anything…')];
    }
    final asked = _asked;
    return <Widget>[
      Text(
        checked.canBeAdded ? 'Nothing stands in the way.' : 'This would not work as it is.',
        key: const Key('connection-check-says'),
        style: checked.canBeAdded ? null : text.bodyLarge?.copyWith(color: scheme.error),
      ),
      if (checked.detail.isNotEmpty) Text(checked.detail, key: const Key('connection-check-detail')),
      if (checked.identity.isNotEmpty)
        Text('The forge says this key logs in as: ${checked.identity}', key: const Key('connection-identity')),
      ..._aboutTheVault(checked.outcome),
      if (checked.canBeAdded)
        Text(
          switch (asked.storing) {
            Storing.nothing => 'Adding it writes the record; its value is already there.',
            Storing.sendTheKey => 'Adding it writes the record and then sends the key into the vault.',
            Storing.onTheMachine =>
              'Adding it writes the record, and the machine then copies the key into '
                  'its vault.',
            Storing.inATerminal =>
              'Adding it writes the record, and then a terminal on the machine opens '
                  'to type its value.',
          },
          key: const Key('connection-next'),
          style: text.bodySmall,
        )
      else
        Text('Go back and change what does not fit.', style: text.bodySmall),
    ];
  }
}

/// The keys the machine's account already has, one picked rather than a path typed blind.
///
/// **Only a key with its private half is offered**: ssh signs with that file. A Porelo that cannot
/// list keys is not a machine without any, so it falls back to a typed path and says why.
class KeyOnTheMachine extends StatelessWidget {
  /// Constructor taking every field.
  const KeyOnTheMachine({
    super.key,
    required this.keys,
    required this.chosen,
    required this.onChosen,
    required this.onTyped,
  });

  final Future<List<SshKey>> keys;
  final String chosen;
  final ValueChanged<String> onChosen;
  final ValueChanged<String> onTyped;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<SshKey>>(
    future: keys,
    builder: (context, answer) {
      final small = Theme.of(context).textTheme.bodySmall;
      if (answer.hasError) {
        final why = answer.error is FeatureNotSupported
            ? "This machine's Porelo cannot list its keys yet, so its path is typed."
            : 'The machine could not list its keys (${answer.error}), so its path is typed.';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Space.small,
          children: <Widget>[
            Text(why, key: const Key('connection-keys-unavailable'), style: small),
            TextFormField(
              key: const Key('connection-id'),
              initialValue: chosen,
              onChanged: onTyped,
              decoration: InputDecoration(
                labelText: 'Its path on the machine — a file there, not on this computer',
                errorText: chosen.trim().endsWith('.pub')
                    ? 'That is the public half. Name the private key file — usually the same name '
                          'without .pub.'
                    : null,
                errorMaxLines: 3,
              ),
            ),
          ],
        );
      }
      if (!answer.hasData) {
        return Text('Asking the machine which keys it has…', style: small);
      }
      final offered = answer.data!.where((each) => each.servesWhereItLies).toList();
      if (offered.isEmpty) {
        return Text(
          'This machine has no private key in ~/.ssh or named in ~/.ssh/config. To send one '
          'from this computer, go with “A key of this computer”.',
          key: const Key('connection-no-keys'),
          style: small,
        );
      }
      return ChoiceField<String>(
        id: 'connection-key',
        label: 'Which key',
        hint: "Choose one of the machine's keys",
        value: offered.any((each) => each.path == chosen) ? chosen : null,
        onChanged: (path) {
          if (path != null) onChosen(path);
        },
        choices: <Choice<String>>[
          for (final key in offered)
            Choice(
              key.path,
              key.path,
              id: 'key ${key.path}',
              means: <String>[
                <String>[key.type, key.fingerprint, key.comment].where((each) => each.isNotEmpty).join('  '),
                if (key.found == 'CONFIGURED') 'Named by an IdentityFile in ~/.ssh/config.',
                if (key.obstacle.isNotEmpty) key.obstacle,
              ].join('\n'),
            ),
        ],
      );
    },
  );
}
