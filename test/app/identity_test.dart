import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/identity.dart';
import 'package:porelo_frontend/src/app/run_here.dart';

const _old = 'SHA256:BvxPEqOldOldOldOldOldOldOldOldOldOldOldOld';
const _new = 'SHA256:NewNewNewNewNewNewNewNewNewNewNewNewNewNewNe';
const _revision = '56420b3';
const _key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOldKeyOldKeyOldKeyOldKeyOldKeyOldKey';

Map<String, Object?> _shown({
  String agent = 'holds',
  bool revoked = false,
  String? cardRefused,
  List<Map<String, Object?>> pending = const [],
  String fingerprint = _old,
}) => {
  'login': 'rowan-example',
  'name': 'Rowan Example',
  'email': null,
  'fingerprint': fingerprint,
  'key': _key,
  'created': '2026-10-31',
  'expires': '2026-11-30',
  'predecessor': null,
  'card': 'login: "rowan-example"\n',
  'agent': agent,
  'agent_holds_key': agent == 'holds',
  'revoked': revoked,
  'card_refused': cardRefused,
  'organization': [
    {
      'address': 'https://github.com/porelo-ai/organization',
      'filed': 'done',
      'revision': _revision,
      'may_file': true,
      'who_may': <Object?>[],
    },
  ],
  'forge': {
    'login': 'rowan-example',
    'key_listed': true,
    'keys_url': 'https://github.com/rowan-example.keys',
    'account_url': 'https://github.com/settings/keys',
  },
  'pending': pending,
};

Map<String, Object?> _operation(String id, {bool again = false}) => {'revision': '9d0fcc5', 'id': id, 'again': again};

const _keys = {
  'keys': [
    {
      'fingerprint': _new,
      'key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINewKeyNewKeyNewKeyNewKeyNewKeyNewKey',
      'comment': 'laptop',
      'usable': true,
      'reason': null,
      'key_listed': false,
    },
  ],
};

/// Answers exactly the contract's JSON per verb and records every call.
class _Core {
  final calls = <List<String>>[];
  final inputs = <String?>[];
  final environments = <Map<String, String>>[];
  final answers = <String, Ran>{};

  void answer(String verb, Object? json, {int code = 0}) =>
      answers[verb] = (code: code, out: json is String ? json : jsonEncode(json), err: '');

  Future<Ran> run(
    String program,
    List<String> arguments, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) async {
    expect(program, 'porelo');
    calls.add(arguments);
    inputs.add(input);
    environments.add(environment);
    final verb = arguments.take(2).join(' ');
    final dry = arguments.contains('--dry-run') ? ' --dry-run' : '';
    return answers['$verb$dry'] ?? (code: 70, out: '', err: 'no answer');
  }

  List<List<String>> named(String verb) => calls.where((call) => call.take(2).join(' ') == verb).toList();
}

AgentKey _usable() => const AgentKey(
  fingerprint: _new,
  key: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINewKeyNewKeyNewKeyNewKeyNewKeyNewKey',
  comment: 'laptop',
  usable: true,
  reason: null,
  login: null,
  keyListed: false,
);

void main() {
  late _Core core;
  late IdentityModel model;

  setUp(() {
    core = _Core();
    model = IdentityModel(Identity(run: core.run));
  });

  group('a refused or revoked identity never offers a change that needs the key', () {
    // Harm: a successor card signed by a revoked or unserved key is offered and sent.
    for (final (label, shown) in [
      ('revoked', _shown(revoked: true)),
      ('card refused', _shown(cardRefused: 'the signature does not verify')),
      ('agent not holding the key', _shown(agent: 'not-held')),
      ('no agent', _shown(agent: 'absent')),
      ('an agent word nobody knows', _shown(agent: 'perhaps')),
    ]) {
      test(label, () async {
        core.answer('identity show', shown);
        await model.load();
        expect(model.card, isNotNull);
        expect(model.whyNotChange, isNotNull);
        await model.rotate(_usable());
        expect(core.named('identity rotate'), isEmpty);
      });
    }

    test('a key the agent lists as unusable is never used to make a card', () async {
      // Harm: a revoked or foreign key becomes the person's card.
      const revoked = AgentKey(
        fingerprint: _new,
        key: 'ssh-ed25519 AAAA',
        comment: '',
        usable: false,
        reason: 'revoked',
        login: null,
        keyListed: null,
      );
      await model.useExistingKey(login: 'rowan', name: 'Rowan', key: revoked);
      await model.planLostKey(revoked);
      expect(core.calls, isEmpty);
    });
  });

  group('a retry after an interruption never starts a second change', () {
    // Harm: a second rotate or create makes a second key and card.
    test('a lost rotate answer leaves only the same rotate under the same ID', () async {
      core.answer('identity show', _shown());
      await model.load();
      core.answer('identity rotate', '{"id": "rot-', code: 0);
      await model.rotate(_usable());
      final id = model.unfinishedId;
      expect(id, isNotNull);
      expect(model.whyNotChange, isNotNull);
      await model.rotate(_usable());
      expect(core.named('identity rotate'), hasLength(1));
      core.answer('identity rotate', _operation(id!, again: true));
      await model.retry();
      expect(core.named('identity rotate'), hasLength(2));
      expect(core.named('identity rotate').first, core.named('identity rotate').last);
      expect(core.named('identity rotate').last, [
        'identity',
        'rotate',
        '--key',
        _new,
        '--base',
        _revision,
        '--id',
        id,
        '--json',
      ]);
      expect(model.operation?.id, id);
      expect(model.operation?.again, isTrue);
      expect(model.unfinishedId, isNull);
    });

    // Harm: a change that may have been made is dropped and made a second time; one refused keeps blocking for nothing.
    for (final (code, kept) in [(69, true), (70, true), (65, false), (64, false), (66, false)]) {
      test('exit $code ${kept ? 'keeps' : 'drops'} the ID', () async {
        core.answer('identity show', _shown());
        await model.load();
        core.answer('identity rotate', {'reason': 'x', 'words': 'said by Porelo'}, code: code);
        await model.rotate(_usable());
        expect(model.unfinishedId != null, kept);
        expect(model.problem, 'said by Porelo');
      });
    }

    test('a change Core still lists as pending blocks a new one', () async {
      core.answer(
        'identity show',
        _shown(
          pending: [
            {'id': 'rot-20261031-1', 'action': 'rotate', 'fingerprint': _new},
          ],
        ),
      );
      await model.load();
      await model.rotate(_usable());
      expect(core.named('identity rotate'), isEmpty);
      expect(model.whyNotStart, isNotNull);
    });

    test('a rotation run in a terminal is taken from its answer, and only asked again by the person', () async {
      core.answer('identity show', _shown());
      await model.load();
      final started = model.rotateInTerminal(database: '/home/person/Passwords.kdbx')!;
      expect(started.command, [
        'porelo',
        'identity',
        'rotate',
        '--keepassxc',
        '/home/person/Passwords.kdbx',
        '--base',
        _revision,
        '--id',
        started.id,
        '--json',
      ]);
      expect(model.rotateInTerminal(database: '/home/person/Passwords.kdbx'), isNull);
      await model.terminalEnded(code: -1, lastLine: '', id: started.id);
      expect(core.named('identity rotate'), isEmpty);
      expect(model.unfinishedId, started.id);
      expect(model.unfinishedCommand, started.command, reason: 'asked again as it was asked');
      await model.terminalEnded(code: 0, lastLine: jsonEncode(_operation('rot-other')), id: started.id);
      expect(model.unfinishedId, started.id, reason: 'another operation’s answer is not this one’s');
      await model.terminalEnded(code: 0, lastLine: jsonEncode(_operation(started.id)), id: started.id);
      expect(model.unfinishedId, isNull);
      expect(model.operation?.id, started.id);
    });

    test('key-not-served after making a key reads the card again and never creates again', () async {
      core.answer('identity show', {'reason': 'no-identity', 'words': 'no card is kept'}, code: 65);
      await model.terminalEnded(
        code: 65,
        lastLine: '{"reason": "key-not-served", "words": "KeePassXC did not serve the key within 60 s"}',
      );
      expect(core.named('identity create'), isEmpty);
      expect(core.named('identity show'), hasLength(1));
      expect(model.problemReason, 'key-not-served');
      expect(model.card, isNull);
    });

    test('cancelling a lost-key plan calls nothing; confirming runs the reviewed key once', () async {
      // Harm: a vault deleted without the person's review, or deleted twice.
      core.answer('identity revoke --dry-run', {
        'plan': {
          'who_may': [
            {'login': 'owner', 'name': 'Owner', 'email': null},
          ],
          'accepted_with': 'porelo org person replace LOGIN --card FILE',
          'order': 'A backup key works only while the old key is still on the forge.',
        },
        'hosts': [
          {'host': 'demo', 'vault': 'reset'},
        ],
        'sign_ins': [
          {
            'host': 'demo',
            'entries': ['git.token.github.com'],
          },
        ],
      });
      core.answer('identity show', _shown());
      await model.load();
      await model.planLostKey(_usable());
      model.cancelLostKey();
      await model.confirmLostKey();
      expect(core.calls.where((call) => call[1] != 'show' && !call.contains('--dry-run')), isEmpty);

      await model.planLostKey(_usable());
      expect(model.lostKeyPlan!.plan.whoMay.single.login, 'owner');
      final id = model.lostKeyPlan!.id;
      core.answer('identity revoke', _operation(id));
      await model.confirmLostKey();
      await model.confirmLostKey();
      final runs = core.calls.where((call) => call[1] == 'revoke' && !call.contains('--dry-run')).toList();
      expect(runs, [
        ['identity', 'revoke', '--lost', '--key', _new, '--id', id, '--json'],
      ]);
      expect(model.lostKeyCardMade, isTrue);
    });
  });

  group('an unknown or incomplete answer never reads as a good state', () {
    // Harm: a card shown as working, or a change shown as done, that Core never confirmed.
    test('a show answer missing a field keeps no card', () async {
      core.answer('identity show', _shown());
      await model.load();
      expect(model.card, isNotNull);
      core.answer('identity show', _shown()..remove('revoked'));
      await model.load();
      expect(model.card, isNull);
      expect(model.problem, isNotNull);
    });

    // Harm: a card read wrongly decides who holds a key, and an old answer is taken for a current one.
    test('a show answer without organization refuses in words, and keeps no card', () async {
      core.answer('identity show', {
        ..._shown()..remove('organization'),
        'registry': [
          {
            'address': 'https://github.com/porelo-ai/registry',
            'filed': 'done',
            'revision': _revision,
            'may_file': true,
            'who_may': <Object?>[],
          },
        ],
      });
      await model.load();
      expect(model.card, isNull);
      expect(model.problem, contains('no organization'));
    });

    test('a show answer is read from its organization, field by field', () async {
      core.answer('identity show', _shown());
      await model.load();
      final organization = model.card!.organization.single;
      expect(organization.address, 'https://github.com/porelo-ai/organization');
      expect(organization.filed, FiledState.done);
      expect(organization.revision, _revision);
      expect(organization.mayFile, isTrue);
    });

    test('two agent fields that disagree are refused', () async {
      core.answer('identity show', {..._shown(agent: 'not-held'), 'agent_holds_key': true});
      await model.load();
      expect(model.card, isNull);
    });

    test('an organization word nobody knows is never filed', () async {
      final shown = _shown();
      (shown['organization'] as List).first['filed'] = 'fine';
      core.answer('identity show', shown);
      await model.load();
      expect(model.card!.organization.single.filed, FiledState.unknown);
    });

    test('an answer for another operation is not this one', () async {
      core.answer('identity show', _shown());
      await model.load();
      core.answer('identity rotate', '', code: 70);
      await model.rotate(_usable());
      final mine = model.unfinishedId!;
      core.answer('identity rotate', _operation('rot-other'));
      await model.retry();
      expect(model.operation, isNull);
      expect(model.unfinishedId, mine);
    });

    test('an unusable key without its reason is refused', () async {
      core.answer('identity keys', {
        'keys': [
          {
            'fingerprint': _new,
            'key': 'ssh-rsa AAAA',
            'comment': 'x',
            'usable': false,
            'reason': null,
            'key_listed': null,
          },
        ],
      });
      await model.readKeys();
      expect(model.keys, isNull);
      expect(model.problem, isNotNull);
    });
  });

  test('no secret is on any command line', () async {
    // Harm: a key, password or token in an argument list, where every process listing reads it.
    final identity = Identity(run: core.run);
    core.answer('identity show', _shown());
    core.answer('identity keys', _keys);
    core.answer('identity create', {
      'login': 'rowan',
      'fingerprint': _new,
      'key': _key,
      'card': 'c',
      'agent': 'holds',
      'forge': null,
      'next': ['file-card'],
    });
    core.answer('identity rotate', _operation('rot-1'));
    core.answer('identity revoke --dry-run', {
      'plan': <String, Object?>{'who_may': <Object?>[]},
      'hosts': <Object?>[],
      'sign_ins': <Object?>[],
    });
    core.answer('identity revoke', _operation('lost-1'));
    await identity.show();
    await identity.keys();
    await identity.createWithKey(login: 'rowan', name: 'Rowan', email: 'rowan@example.org', fingerprint: _new);
    await identity.rotate(fingerprint: _new, id: 'rot-1', base: _revision);
    await identity.planLostKey(fingerprint: _new);
    await identity.replaceLostKey(fingerprint: _new, id: 'lost-1');
    expect(core.calls, [
      ['identity', 'show', '--json'],
      ['identity', 'keys', '--json'],
      [
        'identity',
        'create',
        '--login',
        'rowan',
        '--name',
        'Rowan',
        '--email',
        'rowan@example.org',
        '--key',
        _new,
        '--json',
      ],
      ['identity', 'rotate', '--key', _new, '--base', _revision, '--id', 'rot-1', '--json'],
      ['identity', 'revoke', '--lost', '--key', _new, '--dry-run', '--json'],
      ['identity', 'revoke', '--lost', '--key', _new, '--id', 'lost-1', '--json'],
    ]);
    expect(core.inputs, everyElement(isNull));
    expect(core.environments, everyElement(isEmpty));
    expect(
      Identity.createInKeepassxc(
        login: 'rowan',
        name: 'Rowan',
        database: '/home/person/Passwords.kdbx',
        entry: 'Porelo/key',
      ),
      [
        'porelo',
        'identity',
        'create',
        '--login',
        'rowan',
        '--name',
        'Rowan',
        '--keepassxc',
        '/home/person/Passwords.kdbx',
        '--entry',
        'Porelo/key',
        '--json',
      ],
    );
    expect(Identity.rotateInKeepassxc(database: '/home/person/Passwords.kdbx', id: 'rot-2'), [
      'porelo',
      'identity',
      'rotate',
      '--keepassxc',
      '/home/person/Passwords.kdbx',
      '--id',
      'rot-2',
      '--json',
    ]);
  });

  group('a lost key replaced by a new KeePassXC key runs once in its terminal', () {
    // Harm: vaults reset without review, or a second new key made after an interruption.
    const plan = {
      'plan': <String, Object?>{'who_may': <Object?>[]},
      'hosts': <Object?>[],
      'sign_ins': <Object?>[],
    };

    test('the dry run comes first, then the confirmed command once', () async {
      // A revoked key is the stolen case: replacing it stays open, unlike every change that needs it.
      core.answer('identity show', _shown(revoked: true));
      await model.load();
      core.answer('identity revoke --dry-run', plan);
      await model.planLostKeyInKeepassxc(database: '/home/person/Passwords.kdbx', entry: 'Porelo/key');
      expect(core.named('identity revoke').single, [
        'identity',
        'revoke',
        '--lost',
        '--keepassxc',
        '/home/person/Passwords.kdbx',
        '--entry',
        'Porelo/key',
        '--dry-run',
        '--json',
      ]);
      final id = model.lostKeyPlan!.id;
      final started = model.confirmLostKeyInTerminal();
      expect(started?.command, [
        'porelo',
        'identity',
        'revoke',
        '--lost',
        '--keepassxc',
        '/home/person/Passwords.kdbx',
        '--entry',
        'Porelo/key',
        '--id',
        id,
        '--json',
      ]);
      expect(model.confirmLostKeyInTerminal(), isNull);
      await model.confirmLostKey();
      await model.terminalEnded(code: -1, lastLine: '', id: id);
      expect(core.calls.where((call) => call[1] != 'show' && !call.contains('--dry-run')), isEmpty);
      expect(model.unfinishedId, id, reason: 'it may have been made, so only the same ID goes on');
    });

    test('cancelling the plan leaves nothing to confirm', () async {
      core.answer('identity show', _shown());
      await model.load();
      core.answer('identity revoke --dry-run', plan);
      await model.planLostKeyInKeepassxc(database: '/home/person/Passwords.kdbx');
      expect(model.lostKeyPlan, isNotNull);
      model.cancelLostKey();
      expect(model.confirmLostKeyInTerminal(), isNull);
      expect(model.unfinishedId, isNull);
    });
  });

  group('no change starts or repeats past an open one', () {
    // Harm: a second key made, or a lost or revoked key used to sign, while an earlier change is still open.
    final pendingRotation = _shown(
      pending: [
        {'id': 'rot-20261031-1', 'action': 'rotate'},
      ],
    );
    test('a rotation in a terminal goes through the same guard', () async {
      core.answer('identity show', _shown(revoked: true));
      await model.load();
      expect(model.rotateInTerminal(database: '/home/person/Passwords.kdbx'), isNull);
      core.answer('identity show', pendingRotation);
      await model.load();
      expect(model.rotateInTerminal(database: '/home/person/Passwords.kdbx'), isNull);
      expect(model.unfinishedId, isNull);
    });

    test('an answered rotation reads the card again and its pending entry blocks another', () async {
      core.answer('identity show', _shown());
      // Core answers with the caller's ID, and lists the operation as pending from then on.
      Future<Ran> echo(
        String program,
        List<String> arguments, {
        String? inDirectory,
        Map<String, String> environment = const {},
        String? input,
      }) async {
        if (arguments[1] != 'rotate') {
          return core.run(program, arguments, inDirectory: inDirectory, environment: environment, input: input);
        }
        core.calls.add(arguments);
        final id = arguments[arguments.indexOf('--id') + 1];
        core.answer('identity show', {
          ..._shown(),
          'pending': [
            {'id': id, 'action': 'rotate'},
          ],
        });
        return (code: 0, out: jsonEncode(_operation(id)), err: '');
      }

      final echoing = IdentityModel(Identity(run: echo));
      await echoing.load();
      await echoing.rotate(_usable());
      expect(core.named('identity show'), hasLength(2));
      expect(echoing.card!.pending, hasLength(1));
      expect(echoing.whyNotChange, isNotNull);
      await echoing.rotate(_usable());
      expect(core.named('identity rotate'), hasLength(1));
    });

    // Harm: a person who lost the key a pending rotation was made with can never replace it.
    test('a pending rotation does not hold up replacing a lost key, even waiting for that key', () async {
      core.answer(
        'identity show',
        _shown(
          revoked: true,
          pending: [
            {'id': 'rot-20261031-1', 'action': 'rotate', 'fingerprint': _usable().fingerprint},
          ],
        ),
      );
      await model.load();
      expect(model.whyNotLostKey, isNull);
      core.answer('identity revoke --dry-run', {
        'plan': <String, Object?>{'who_may': <Object?>[]},
        'hosts': <Object?>[],
        'sign_ins': <Object?>[],
      });
      await model.planLostKey(_usable());
      expect(core.named('identity revoke'), hasLength(1));
      expect(model.lostKeyPlan?.id, isNot('rot-20261031-1'), reason: 'a new change, under its own id');
    });

    // Harm: a second new card beside one still pending.
    test('a pending replacement of a lost key does hold up another', () async {
      core.answer(
        'identity show',
        _shown(
          pending: [
            {'id': 'lost-20261031-1', 'action': 'revoke-lost', 'fingerprint': _usable().fingerprint},
          ],
        ),
      );
      await model.load();
      expect(model.whyNotLostKey, isNotNull);
      await model.planLostKey(_usable());
      await model.planLostKeyInKeepassxc(database: '/home/person/Passwords.kdbx');
      expect(core.named('identity revoke'), isEmpty);
    });

    // Harm: a terminal killed after the key was made loses its id, and the next attempt makes a second key.
    for (final code in [129, 137]) {
      test('a terminal killed with exit $code keeps the change to ask again', () async {
        core.answer('identity show', _shown());
        await model.load();
        final started = model.rotateInTerminal(database: '/home/person/Passwords.kdbx')!;
        await model.terminalEnded(code: code, lastLine: '', id: started.id);
        expect(model.unfinishedId, started.id);
      });
    }

    test('a rotation is not asked again once the key is revoked', () async {
      core.answer('identity show', _shown());
      await model.load();
      core.answer('identity rotate', '', code: 70);
      await model.rotate(_usable());
      core.answer('identity show', _shown(revoked: true));
      await model.load();
      expect(model.whyNotRetry, isNotNull);
      await model.retry();
      expect(core.named('identity rotate'), hasLength(1));
    });

    test('the lost or stolen key is never its own replacement', () async {
      core.answer('identity show', _shown(revoked: true));
      await model.load();
      const current = AgentKey(
        fingerprint: _old,
        key: _key,
        comment: 'stolen',
        usable: true,
        reason: null,
        login: null,
        keyListed: null,
      );
      expect(model.whyNotSuccessor(current), isNotNull);
      await model.planLostKey(current);
      expect(core.named('identity revoke'), isEmpty);
    });
  });

  group('a change left pending goes on, or starts again, by what Core names', () {
    const waiting = 'SHA256:WaitingWaitingWaitingWaitingWaitingWaitingWa';
    const row = PendingIdentityOperation(id: 'rot-20261031-1', action: 'rotate', fingerprint: waiting);
    final rowRead = {'id': row.id, 'action': row.action, 'fingerprint': waiting};
    String idOf(List<String> call) => call[call.indexOf('--id') + 1];
    String keyOf(List<String> call) => call[call.indexOf('--key') + 1];

    Future<PendingIdentityOperation> read(
      Map<String, Object?> rowAnswer, {
      String agent = 'holds',
      bool revoked = false,
    }) async {
      core.answer('identity show', _shown(agent: agent, revoked: revoked, pending: [rowAnswer]));
      await model.load();
      return model.card!.pending.single;
    }

    // Harm: a second key made because a retry took a new id.
    test('Try again keeps the row\'s ID and key, also after an attempt with no clear answer', () async {
      final pending = await read(rowRead);
      core.answer('identity rotate', '', code: 69);
      await model.tryAgain(pending);
      core.answer('identity rotate', _operation(row.id));
      await model.tryAgain(pending);
      expect(core.named('identity rotate'), hasLength(2));
      for (final call in core.named('identity rotate')) {
        expect(idOf(call), row.id);
        expect(keyOf(call), waiting);
        expect(call, containsAllInOrder(['--base', _revision]));
      }
      expect(model.operation?.id, row.id);
    });

    test('Try again goes by the row\'s action and opens no terminal', () async {
      final pending = await read({'id': 'lost-1', 'action': 'revoke-lost', 'fingerprint': waiting});
      core.answer('identity revoke', {'revision': _revision, 'id': 'lost-1', 'again': true, 'card': 'the card'});
      await model.tryAgain(pending);
      expect(core.named('identity revoke').single, [
        'identity',
        'revoke',
        '--lost',
        '--key',
        waiting,
        '--id',
        'lost-1',
        '--json',
      ]);
      expect(model.operation?.card, 'the card');
    });

    // Harm: a pending change replaced under the same id with another key.
    test('another key always goes under a new ID, and Try again never names it', () async {
      final pending = await read(rowRead);
      model.startReplacing(pending);
      core.answer('identity rotate', '', code: 65);
      await model.rotate(_usable());
      final call = core.named('identity rotate').single;
      expect(keyOf(call), _new);
      expect(idOf(call), isNot(row.id));
      expect(model.replacing, isNull);

      await model.tryAgain(pending);
      expect(keyOf(core.named('identity rotate').last), waiting);
      expect(idOf(core.named('identity rotate').last), row.id);
    });

    test('another key in a terminal goes under a new ID too', () async {
      final pending = await read(rowRead);
      model.startReplacing(pending);
      final started = model.rotateInTerminal(database: '/home/person/Passwords.kdbx')!;
      expect(started.id, isNot(row.id));
      expect(started.command, isNot(contains(row.id)));
    });

    test('the key a change waits for is no other key: a new ID for it would make a second change', () async {
      final pending = await read(rowRead);
      model.startReplacing(pending);
      const same = AgentKey(
        fingerprint: waiting,
        key: _key,
        comment: 'same',
        usable: true,
        reason: null,
        login: null,
        keyListed: null,
      );
      expect(model.whyNotSuccessor(same), isNotNull);
      await model.rotate(same);
      expect(core.named('identity rotate'), isEmpty);
    });

    test('a replacement with no clear answer is asked again under its own new ID, nothing else on offer', () async {
      final pending = await read(rowRead);
      model.startReplacing(pending);
      core.answer('identity rotate', '', code: 70);
      await model.rotate(_usable());
      final id = idOf(core.named('identity rotate').single);
      expect(model.whyNotTryAgain(pending), isNotNull);
      expect(model.whyNotReplace(pending), isNotNull);
      await model.tryAgain(pending);
      expect(core.named('identity rotate'), hasLength(1));

      core.answer('identity rotate', _operation(id));
      await model.retry();
      expect(core.named('identity rotate').map(idOf), [id, id]);
      expect(core.named('identity rotate').map(keyOf), [_new, _new]);
    });

    // Harm: a person offered again what the organization has refused, with its first card standing.
    for (final (name, ask) in <(String, Future<void> Function(PendingIdentityOperation))>[
      ('Try again', (pending) => model.tryAgain(pending)),
      (
        'another key',
        (pending) async {
          model.startReplacing(pending);
          await model.rotate(_usable());
        },
      ),
    ]) {
      test('an exists refusal of $name is said by its words and offers neither again', () async {
        final pending = await read(rowRead);
        const words = 'that change reached the organization, and its first card stands';
        core.answer('identity rotate', {'reason': 'exists', 'words': words}, code: 65);
        await ask(pending);
        expect(model.problem, contains(words));
        expect(model.standing(model.card!.pending.single), words);
        expect(model.whyNotTryAgain(model.card!.pending.single), words);
        expect(model.whyNotReplace(model.card!.pending.single), words);
        final before = core.named('identity rotate').length;
        await model.tryAgain(pending);
        model.startReplacing(pending);
        expect(model.replacing, isNull);
        expect(core.named('identity rotate'), hasLength(before));
      });
    }

    test('an exists refusal in a terminal offers neither again', () async {
      final pending = await read(rowRead);
      model.startReplacing(pending);
      final started = model.rotateInTerminal(database: '/home/person/Passwords.kdbx')!;
      const words = 'that change reached the organization';
      await model.terminalEnded(code: 65, lastLine: jsonEncode({'reason': 'exists', 'words': words}), id: started.id);
      expect(model.standing(pending), words);
    });

    // Harm: a key sent that Core never named for this change.
    for (final (name, answer) in <(String, Map<String, Object?>)>[
      ('absent', {'id': row.id, 'action': 'rotate'}),
      ('null', {'id': row.id, 'action': 'rotate', 'fingerprint': null}),
      ('no fingerprint', {'id': row.id, 'action': 'rotate', 'fingerprint': '--evil'}),
      ('another shape', {'id': row.id, 'action': 'rotate', 'fingerprint': 3}),
    ]) {
      test('a row whose key is $name offers no Try again, says so, and still offers another key', () async {
        final pending = await read(answer);
        expect(model.problem, isNull);
        expect(pending.fingerprint, isNull);
        expect(model.whyNotTryAgain(pending), isNotNull);
        await model.tryAgain(pending);
        expect(core.named('identity rotate'), isEmpty);
        expect(model.whyNotReplace(pending), isNull);
      });
    }

    test('an agent that no longer serves a key is no dead end: Core decides, and its refusal is said', () async {
      final pending = await read(rowRead, agent: 'not-held');
      expect(model.whyNotTryAgain(pending), isNull);
      expect(model.whyNotReplace(pending), isNull);
      model.startReplacing(pending);
      expect(model.whyNotChange, isNull);
      core.answer('identity rotate', {'reason': 'no-key', 'words': 'your agent does not serve it'}, code: 69);
      model.stopReplacing();
      await model.tryAgain(pending);
      expect(model.problem, contains('your agent does not serve it'));
      expect(model.whyNotTryAgain(pending), isNull);
      expect(model.whyNotReplace(pending), isNull);
    });

    test('a rotation on a revoked card offers neither, and a word this interface does not know neither', () async {
      final revoked = await read(rowRead, revoked: true);
      expect(model.whyNotTryAgain(revoked), isNotNull);
      expect(model.whyNotReplace(revoked), isNotNull);
      final unknown = await read({'id': 'x-1', 'action': 'merge', 'fingerprint': waiting});
      expect(model.whyNotTryAgain(unknown), contains('merge'));
      expect(model.whyNotReplace(unknown), contains('merge'));
    });

    test('while one row is replaced, another still blocks a new change', () async {
      core.answer(
        'identity show',
        _shown(
          pending: [
            rowRead,
            {'id': 'rot-2', 'action': 'rotate', 'fingerprint': waiting},
          ],
        ),
      );
      await model.load();
      model.startReplacing(model.card!.pending.first);
      expect(model.whyNotChange, isNotNull);
      await model.rotate(_usable());
      expect(core.named('identity rotate'), isEmpty);
    });
  });

  group('a lost key\'s new card is read from the answer', () {
    // Harm: a person hands over nothing, or a card this interface made up, believing it is the new one.
    Future<IdentityOperation?> answered(Map<String, Object?> answer) async {
      core.answer('identity show', _shown());
      await model.load();
      core.answer('identity revoke --dry-run', {
        'plan': <String, Object?>{'who_may': <Object?>[]},
        'hosts': <Object?>[],
        'sign_ins': <Object?>[],
      });
      await model.planLostKey(_usable());
      core.answer('identity revoke', {..._operation(model.lostKeyPlan!.id), ...answer});
      await model.confirmLostKey();
      return model.operation;
    }

    test('the card is the answer\'s, as it came', () async {
      expect((await answered({'card': 'login: ms\n'}))?.card, 'login: ms\n');
      expect(model.handoverPlan, isNotNull);
    });

    for (final (name, card) in <(String, Object?)>[('null', null), ('empty', '  '), ('another shape', 3)]) {
      test('a card that is $name is absent, never guessed', () async {
        expect((await answered({'card': card}))?.card, isNull);
      });
    }

    test('an answer without the field is absent too, and a rotation reads no card', () async {
      expect((await answered({}))?.card, isNull);
      expect(Identity.terminalAnswer(jsonEncode({'id': 'a', 'card': 'c'}), id: 'a', action: 'rotate').card, isNull);
      expect(Identity.terminalAnswer(jsonEncode({'id': 'a', 'card': 'c'}), id: 'a', action: 'revoke-lost').card, 'c');
    });
  });

  group('a made card is the one asked for', () {
    // Harm: the first start reads an older, foreign or unserved card as the person's new working one.
    test('another key, an unserved key or a failed run is not made', () async {
      core.answer('identity show', _shown());
      await model.load();
      const login = 'rowan-example';
      expect(model.whyNotMade(login: login, fingerprint: _new), isNotNull);
      expect(model.whyNotMade(login: login, before: _old), isNotNull);
      expect(model.whyNotMade(login: login, fingerprint: _old), isNull);
      // A card of another login, or the picked key's card read before making, is not the one made now.
      expect(model.whyNotMade(login: 'someone-else', fingerprint: _old), isNotNull);
      expect(model.whyNotMade(login: login, fingerprint: _old, before: _old), isNotNull);
      core.answer('identity show', _shown(agent: 'not-held'));
      await model.load();
      expect(model.whyNotMade(login: login, fingerprint: _old), isNotNull);
      core.answer('identity show', _shown());
      await model.terminalEnded(code: 65, lastLine: '{"reason":"key-not-served","words":"not served"}');
      expect(model.card, isNotNull);
      expect(model.problemReason, 'key-not-served');
    });

    test('a create answer without forge or with an unknown agent word is refused', () async {
      final identity = Identity(run: core.run);
      final made = {
        'login': 'rowan',
        'fingerprint': _new,
        'key': _key,
        'card': 'c',
        'agent': 'holds',
        'forge': null,
        'next': ['file-card'],
      };
      core.answer('identity create', {...made}..remove('forge'));
      await expectLater(
        identity.createWithKey(login: 'rowan', name: 'Rowan', fingerprint: _new),
        throwsA(isA<FormatException>()),
      );
      core.answer('identity create', {...made, 'agent': 'maybe'});
      await expectLater(
        identity.createWithKey(login: 'rowan', name: 'Rowan', fingerprint: _new),
        throwsA(isA<FormatException>()),
      );
    });

    test('a usable agent key that is no Ed25519 key is refused', () async {
      core.answer('identity keys', {
        'keys': [
          {
            'fingerprint': _new,
            'key': 'ssh-rsa AAAAB3NzaC1yc2E',
            'comment': 'x',
            'usable': true,
            'reason': null,
            'key_listed': null,
          },
        ],
      });
      await expectLater(Identity(run: core.run).keys(), throwsA(isA<FormatException>()));
    });
  });
}
