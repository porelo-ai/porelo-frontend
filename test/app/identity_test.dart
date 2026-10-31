import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/identity.dart';
import 'package:porelo_frontend/src/app/run_here.dart';

const _old = 'SHA256:BvxPEqOldOldOldOldOldOldOldOldOldOldOldOld';
const _new = 'SHA256:NewNewNewNewNewNewNewNewNewNewNewNewNewNewNe';
const _key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOldKeyOldKeyOldKeyOldKeyOldKeyOldKey';

Map<String, Object?> _shown({
  String agent = 'holds',
  bool revoked = false,
  String? cardRefused,
  List<Map<String, Object?>> pending = const [],
  String fingerprint = _old,
}) => {
  'login': 'ms-test-reviewer',
  'name': 'MS Test Reviewer',
  'email': null,
  'fingerprint': fingerprint,
  'key': _key,
  'created': '2026-10-31',
  'expires': '2026-11-30',
  'predecessor': null,
  'card': 'login: "ms-test-reviewer"\n',
  'agent': agent,
  'agent_holds_key': agent == 'holds',
  'revoked': revoked,
  'card_refused': cardRefused,
  'registry': [
    {
      'address': 'https://github.com/porelo-ai/registry',
      'filed': 'done',
      'revision': '7fd5ae88',
      'may_file': true,
      'who_may': <Object?>[],
    },
  ],
  'forge': {
    'login': 'ms-test-reviewer',
    'key_listed': true,
    'keys_url': 'https://github.com/ms-test-reviewer.keys',
    'account_url': 'https://github.com/settings/keys',
  },
  'pending': pending,
};

Map<String, Object?> _operation(String id, {String status = 'done', String action = 'rotate'}) => {
  'id': id,
  'action': action,
  'fingerprint': _new,
  'predecessor': _old,
  'published': [
    {
      'where': 'registry',
      'address': 'https://github.com/porelo-ai/registry',
      'status': status,
      'why': null,
      'who_may': <Object?>[],
    },
    {
      'where': 'host',
      'host': 'walk6m',
      'status': 'pending',
      'why': 'the host takes it at its next sync',
      'who_may': <Object?>[],
    },
  ],
};

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
      await model.useExistingKey(login: 'ms', name: 'MS', key: revoked);
      await model.planLostKey(revoked);
      expect(core.calls, isEmpty);
    });
  });

  group('a retry after an interruption never starts a second change', () {
    // Harm: a second rotate or create makes a second key and card.
    test('a lost rotate answer leaves only publish with the same ID', () async {
      core.answer('identity show', _shown());
      await model.load();
      core.answer('identity rotate', '{"id": "rot-', code: 0);
      await model.rotate(_usable());
      final id = model.unfinishedId;
      expect(id, isNotNull);
      expect(model.whyNotChange, isNotNull);
      await model.rotate(_usable());
      core.answer('identity publish', _operation(id!));
      await model.retry(id);
      expect(core.named('identity rotate'), hasLength(1));
      expect(core.named('identity rotate').single, containsAllInOrder(['--id', id]));
      expect(core.named('identity publish').single, ['identity', 'publish', '--id', id, '--json']);
      expect(model.operation?.id, id);
    });

    test('a change Core still lists as pending blocks a new one', () async {
      core.answer(
        'identity show',
        _shown(
          pending: [
            {'id': 'rot-20261031-1', 'action': 'rotate'},
          ],
        ),
      );
      await model.load();
      await model.rotate(_usable());
      expect(core.named('identity rotate'), isEmpty);
      core.answer('identity publish', _operation('rot-20261031-1'));
      await model.retry('rot-20261031-1');
      expect(core.named('identity publish').single, contains('rot-20261031-1'));
    });

    test('a rotation run in a terminal is read back by its ID, never run again', () async {
      core.answer('identity show', _shown());
      await model.load();
      final started = model.rotateInTerminal(database: '/home/ms/Passwords.kdbx')!;
      expect(model.rotateInTerminal(database: '/home/ms/Passwords.kdbx'), isNull);
      core.answer('identity status', _operation(started.id));
      await model.terminalEnded(code: 1, lastLine: 'Interrupted', id: started.id);
      expect(core.named('identity rotate'), isEmpty);
      expect(core.named('identity status').single, ['identity', 'status', '--id', started.id, '--json']);
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
        'places': [
          {
            'where': 'registry',
            'address': 'https://github.com/porelo-ai/registry',
            'status': 'planned',
            'why': null,
            'who_may': [
              {'login': 'owner', 'name': 'Owner', 'email': null},
            ],
          },
        ],
        'hosts': [
          {'host': 'walk6m', 'vault': 'reset'},
        ],
        'sign_ins': [
          {
            'host': 'walk6m',
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
      final id = model.lostKeyPlan!.id;
      core.answer('identity revoke', _operation(id, action: 'revoke-lost', status: 'pending'));
      await model.confirmLostKey();
      await model.confirmLostKey();
      final runs = core.calls.where((call) => call[1] == 'revoke' && !call.contains('--dry-run')).toList();
      expect(runs, [
        ['identity', 'revoke', '--lost', '--key', _new, '--id', id, '--json'],
      ]);
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

    test('two agent fields that disagree are refused', () async {
      core.answer('identity show', {..._shown(agent: 'not-held'), 'agent_holds_key': true});
      await model.load();
      expect(model.card, isNull);
    });

    test('a status word nobody knows is never done', () async {
      core.answer('identity status', _operation('rot-1', status: 'accepted'));
      await model.readBack('rot-1');
      expect(model.operation!.published.first.status, PlaceState.unknown);
      expect(model.operation!.finished, isFalse);
    });

    test('a registry word nobody knows is never filed', () async {
      final shown = _shown();
      (shown['registry'] as List).first['filed'] = 'fine';
      core.answer('identity show', shown);
      await model.load();
      expect(model.card!.registry.single.filed, FiledState.unknown);
    });

    test('an answer for another operation is not this one', () async {
      core.answer('identity show', _shown());
      await model.load();
      core.answer('identity rotate', '', code: 70);
      await model.rotate(_usable());
      final mine = model.unfinishedId!;
      core.answer('identity publish', _operation('rot-other'));
      await model.retry(mine);
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
      'login': 'ms',
      'fingerprint': _new,
      'key': _key,
      'card': 'c',
      'agent': 'holds',
      'forge': null,
      'next': ['file-card'],
    });
    core.answer('identity rotate', _operation('rot-1'));
    core.answer('identity publish', _operation('rot-1'));
    core.answer('identity status', _operation('rot-1'));
    core.answer('identity revoke --dry-run', {'places': <Object?>[], 'hosts': <Object?>[], 'sign_ins': <Object?>[]});
    core.answer('identity revoke', _operation('lost-1', action: 'revoke-lost'));
    await identity.show();
    await identity.keys();
    await identity.createWithKey(login: 'ms', name: 'MS', email: 'ms@example.org', fingerprint: _new);
    await identity.rotate(fingerprint: _new, id: 'rot-1');
    await identity.publish('rot-1');
    await identity.status('rot-1');
    await identity.planLostKey(fingerprint: _new);
    await identity.replaceLostKey(fingerprint: _new, id: 'lost-1');
    expect(core.calls, [
      ['identity', 'show', '--json'],
      ['identity', 'keys', '--json'],
      ['identity', 'create', '--login', 'ms', '--name', 'MS', '--email', 'ms@example.org', '--key', _new, '--json'],
      ['identity', 'rotate', '--key', _new, '--id', 'rot-1', '--json'],
      ['identity', 'publish', '--id', 'rot-1', '--json'],
      ['identity', 'status', '--id', 'rot-1', '--json'],
      ['identity', 'revoke', '--lost', '--key', _new, '--dry-run', '--json'],
      ['identity', 'revoke', '--lost', '--key', _new, '--id', 'lost-1', '--json'],
    ]);
    expect(core.inputs, everyElement(isNull));
    expect(core.environments, everyElement(isEmpty));
    expect(
      Identity.createInKeepassxc(login: 'ms', name: 'MS', database: '/home/ms/Passwords.kdbx', entry: 'Porelo/key'),
      [
        'porelo',
        'identity',
        'create',
        '--login',
        'ms',
        '--name',
        'MS',
        '--keepassxc',
        '/home/ms/Passwords.kdbx',
        '--entry',
        'Porelo/key',
        '--json',
      ],
    );
    expect(Identity.rotateInKeepassxc(database: '/home/ms/Passwords.kdbx', id: 'rot-2'), [
      'porelo',
      'identity',
      'rotate',
      '--keepassxc',
      '/home/ms/Passwords.kdbx',
      '--id',
      'rot-2',
      '--json',
    ]);
  });

  test('the backup key refuses until Core builds it', () async {
    // Harm: an action that seems to make a backup while nothing is made.
    await expectLater(Identity(run: core.run).backupKey(), throwsA(isA<IdentityRefused>()));
    expect(core.calls, isEmpty);
  });

  group('filing the card never files twice', () {
    // Harm: a second commit of the card, or a filing against a registry state nobody reviewed.
    const first = '1111111111111111111111111111111111111111';
    const moved = '2222222222222222222222222222222222222222';
    const commit = '3333333333333333333333333333333333333333';
    const checkout = '/home/ms/registry';
    const card = '/home/ms/.config/porelo/identity/card';

    Map<String, Object?> absent({String revision = first, bool mayFile = true, bool revoked = false}) {
      final shown = _shown(revoked: revoked);
      shown['registry'] = [
        {
          'address': 'https://github.com/porelo-ai/registry',
          'filed': 'absent',
          'revision': revision,
          'may_file': mayFile,
          'who_may': mayFile
              ? <Object?>[]
              : [
                  {'login': 'owner', 'name': 'Owner', 'email': 'owner@example.org'},
                ],
        },
      ];
      return shown;
    }

    late IdentityModel filing;
    setUp(() {
      filing = IdentityModel(
        Identity(run: core.run),
        checkoutFor: (address) => address == 'https://github.com/porelo-ai/registry' ? checkout : null,
        environment: const {'XDG_CONFIG_HOME': '/home/ms/.config', 'HOME': '/home/ms'},
      );
    });

    test('a lost answer is retried with the same ID on the same base', () async {
      core.answer('identity show', absent());
      await filing.load();
      core.answer('registry file', '', code: 70);
      await filing.fileCard(filing.card!.registry.single);
      expect(filing.filingUnanswered(filing.card!.registry.single), isTrue);
      core.answer('registry file', {'commit': commit, 'path': 'people/ms-test-reviewer.card'});
      await filing.fileCard(filing.card!.registry.single);
      final files = core.named('registry file');
      expect(files, hasLength(2));
      expect(files.first, files.last);
      final id = files.first[files.first.indexOf('--id') + 1];
      expect(files.first, [
        'registry',
        'file',
        'card',
        checkout,
        '--card',
        card,
        '--id',
        id,
        '--base',
        first,
        '--json',
      ]);
      expect(filing.lastFiled?.commit, commit);
      expect(core.named('identity show'), hasLength(2));
    });

    test('a base conflict reads again and asks again instead of filing again', () async {
      core.answer('identity show', absent());
      await filing.load();
      core.answer('registry file', {'reason': 'base-moved', 'words': 'HEAD is not the base'}, code: 65);
      core.answer('identity show', absent(revision: moved));
      await filing.fileCard(filing.card!.registry.single);
      expect(core.named('registry file'), hasLength(1));
      expect(core.named('identity show'), hasLength(2));
      expect(filing.problem, isNotNull);
      expect(filing.filingUnanswered(filing.card!.registry.single), isFalse);
      core.answer('registry file', {'commit': commit, 'path': 'people/ms-test-reviewer.card'});
      await filing.fileCard(filing.card!.registry.single);
      final files = core.named('registry file');
      expect(files.last[files.last.indexOf('--base') + 1], moved);
      expect(files.last[files.last.indexOf('--id') + 1], isNot(files.first[files.first.indexOf('--id') + 1]));
    });

    test('two presses at once file once', () async {
      core.answer('identity show', absent());
      await filing.load();
      core.answer('registry file', {'commit': commit, 'path': 'people/ms-test-reviewer.card'});
      final registry = filing.card!.registry.single;
      await Future.wait([filing.fileCard(registry), filing.fileCard(registry)]);
      expect(core.named('registry file'), hasLength(1));
    });

    test('a registry only an owner may file in, or a revoked key, files nothing', () async {
      core.answer('identity show', absent(mayFile: false));
      await filing.load();
      expect(filing.whyNotFile(filing.card!.registry.single), isNotNull);
      await filing.fileCard(filing.card!.registry.single);
      core.answer('identity show', absent(revoked: true));
      await filing.load();
      await filing.fileCard(filing.card!.registry.single);
      expect(core.named('registry file'), isEmpty);
    });
  });

  group('a lost key replaced by a new KeePassXC key runs once in its terminal', () {
    // Harm: vaults reset without review, or a second new key made after an interruption.
    const plan = {'places': <Object?>[], 'hosts': <Object?>[], 'sign_ins': <Object?>[]};

    test('the dry run comes first, the confirmed command once, then only a read-back', () async {
      // A revoked key is the stolen case: replacing it stays open, unlike every change that needs it.
      core.answer('identity show', _shown(revoked: true));
      await model.load();
      core.answer('identity revoke --dry-run', plan);
      await model.planLostKeyInKeepassxc(database: '/home/ms/Passwords.kdbx', entry: 'Porelo/key');
      expect(core.named('identity revoke').single, [
        'identity',
        'revoke',
        '--lost',
        '--keepassxc',
        '/home/ms/Passwords.kdbx',
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
        '/home/ms/Passwords.kdbx',
        '--entry',
        'Porelo/key',
        '--id',
        id,
        '--json',
      ]);
      expect(model.confirmLostKeyInTerminal(), isNull);
      await model.confirmLostKey();
      core.answer('identity status', _operation(id, action: 'revoke-lost', status: 'pending'));
      await model.terminalEnded(code: 130, lastLine: '^C', id: id);
      expect(core.calls.where((call) => call[1] != 'show' && !call.contains('--dry-run')).toList(), [
        ['identity', 'status', '--id', id, '--json'],
      ]);
    });

    test('cancelling the plan leaves nothing to confirm', () async {
      core.answer('identity show', _shown());
      await model.load();
      core.answer('identity revoke --dry-run', plan);
      await model.planLostKeyInKeepassxc(database: '/home/ms/Passwords.kdbx');
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
    final pendingLost = _shown(
      pending: [
        {'id': 'lost-20261031-1', 'action': 'revoke-lost'},
      ],
    );

    test('a rotation in a terminal goes through the same guard', () async {
      core.answer('identity show', _shown(revoked: true));
      await model.load();
      expect(model.rotateInTerminal(database: '/home/ms/Passwords.kdbx'), isNull);
      core.answer('identity show', pendingRotation);
      await model.load();
      expect(model.rotateInTerminal(database: '/home/ms/Passwords.kdbx'), isNull);
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
        return (code: 0, out: jsonEncode(_operation(id, status: 'pending')), err: '');
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

    test('the lost-key flow waits for an open change too', () async {
      core.answer('identity show', pendingRotation);
      await model.load();
      expect(model.whyNotStart, isNotNull);
      await model.planLostKey(_usable());
      await model.planLostKeyInKeepassxc(database: '/home/ms/Passwords.kdbx');
      expect(core.named('identity revoke'), isEmpty);
    });

    test('a lost-key replacement is only read back, never published again', () async {
      core.answer('identity show', pendingLost);
      await model.load();
      await model.retry('lost-20261031-1');
      expect(core.named('identity publish'), isEmpty);
      core.answer('identity status', _operation('lost-20261031-1', action: 'revoke-lost', status: 'pending'));
      await model.readBack('lost-20261031-1');
      expect(core.named('identity status'), hasLength(1));
    });

    test('a rotation is not published again once the key is revoked', () async {
      core.answer('identity show', {..._shown(revoked: true), 'pending': pendingRotation['pending']});
      await model.load();
      await model.retry('rot-20261031-1');
      expect(core.named('identity publish'), isEmpty);
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

  group('a kept filing never outlives the right to file it', () {
    // Harm: a card filed with a revoked or refused key, or filed again after the registry accepted it.
    const first = '1111111111111111111111111111111111111111';
    Map<String, Object?> absent({bool revoked = false, String filed = 'absent', String fingerprint = _old}) => {
      ..._shown(revoked: revoked, fingerprint: fingerprint),
      'registry': [
        {
          'address': 'https://github.com/porelo-ai/registry',
          'filed': filed,
          'revision': first,
          'may_file': true,
          'who_may': <Object?>[],
          if (filed == 'refused') 'why': 'the signature does not verify',
        },
      ],
    };

    late IdentityModel filing;
    setUp(() {
      filing = IdentityModel(
        Identity(run: core.run),
        checkoutFor: (_) => '/home/ms/registry',
        environment: const {'XDG_CONFIG_HOME': '/home/ms/.config'},
      );
    });

    Future<void> lostAnswer() async {
      core.answer('identity show', absent());
      await filing.load();
      core.answer('registry file', '', code: 70);
      await filing.fileCard(filing.card!.registry.single);
      expect(filing.filingUnanswered(filing.card!.registry.single), isTrue);
    }

    test('a revoked key drops the kept filing and files nothing', () async {
      await lostAnswer();
      core.answer('identity show', absent(revoked: true));
      await filing.load();
      expect(filing.whyNotFile(filing.card!.registry.single), isNotNull);
      await filing.fileCard(filing.card!.registry.single);
      expect(core.named('registry file'), hasLength(1));
      expect(filing.filingUnanswered(filing.card!.registry.single), isFalse);
    });

    test('a card Core says is filed drops the kept filing', () async {
      await lostAnswer();
      core.answer('identity show', absent(filed: 'done'));
      await filing.load();
      expect(filing.filingUnanswered(filing.card!.registry.single), isFalse);
      await filing.fileCard(filing.card!.registry.single);
      expect(core.named('registry file'), hasLength(1));
    });

    for (final filed in ['pending', 'unknown']) {
      test('a card Core reads as $filed is never filed again under the kept request', () async {
        await lostAnswer();
        core.answer('identity show', absent(filed: filed));
        await filing.load();
        expect(filing.filingUnanswered(filing.card!.registry.single), isFalse);
        expect(filing.whyNotFile(filing.card!.registry.single), isNotNull);
        await filing.fileCard(filing.card!.registry.single);
        expect(core.named('registry file'), hasLength(1));
      });
    }

    test('a lost filing made over a refused card is retried under its own ID', () async {
      // Harm: a second filing under a new ID while the first one's answer was only lost.
      core.answer('identity show', absent(filed: 'refused'));
      await filing.load();
      core.answer('registry file', '', code: 70);
      await filing.fileCard(filing.card!.registry.single);
      await filing.load();
      expect(filing.filingUnanswered(filing.card!.registry.single), isTrue);
      await filing.fileCard(filing.card!.registry.single);
      final ids = [for (final call in core.named('registry file')) call[call.indexOf('--id') + 1]];
      expect(ids, hasLength(2));
      expect(ids.toSet(), hasLength(1));
    });

    test('a card with another key since the lost answer drops the kept request', () async {
      await lostAnswer();
      core.answer('identity show', absent(fingerprint: _new));
      await filing.load();
      expect(filing.filingUnanswered(filing.card!.registry.single), isFalse);
    });
  });

  group('a made card is the one asked for', () {
    // Harm: the first start reads an older, foreign or unserved card as the person's new working one.
    test('another key, an unserved key or a failed run is not made', () async {
      core.answer('identity show', _shown());
      await model.load();
      const login = 'ms-test-reviewer';
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
        'login': 'ms',
        'fingerprint': _new,
        'key': _key,
        'card': 'c',
        'agent': 'holds',
        'forge': null,
        'next': ['file-card'],
      };
      core.answer('identity create', {...made}..remove('forge'));
      await expectLater(
        identity.createWithKey(login: 'ms', name: 'MS', fingerprint: _new),
        throwsA(isA<FormatException>()),
      );
      core.answer('identity create', {...made, 'agent': 'maybe'});
      await expectLater(
        identity.createWithKey(login: 'ms', name: 'MS', fingerprint: _new),
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
