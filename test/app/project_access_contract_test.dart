import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/src/app/access_developers.dart';
import 'package:porelo_frontend/src/app/project_access_contract.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_host/porelo_host.dart';

import '../support/host_registry.dart';
import '../support/project_access.dart' show projectRevision, accessAddress;

const _id = '0123456789abcdef0123456789abcdef';
const _base = '1111111111111111111111111111111111111111';
const _revision = '2222222222222222222222222222222222222222';
const _registry = '/private/registry/checkout';
final _source = ProjectVerifySource(
  repository: '/workspace/demo.bundle',
  signedBy: [hostKey],
  accessRepository: '/workspace/access.bundle',
);
const _verify = [
  'project',
  'verify',
  '--repository',
  '/workspace/demo.bundle',
  '--signed-by',
  hostKey,
  '--project',
  'demo',
  '--access-repository',
  '/workspace/access.bundle',
  '--json',
];

ProjectAccessChange _change({
  String action = 'add',
  String project = 'demo',
  String host = 'orchard',
  String actor = 'alice',
}) => ProjectAccessChange(
  id: _id,
  project: project,
  host: host,
  hostCard: PreparedHost.read(sshCompletion()),
  repository: accessAddress,
  projectRevision: projectRevision,
  baseRevision: _base,
  actor: actor,
  actorFingerprint: adminFingerprint,
  action: action,
  person: action == 'register'
      ? null
      : AccessDeveloper(login: 'bob', role: 'developer', fingerprint: personFingerprint),
);

ProjectAccessCoreAdapter _adapter(_CoreCommand command, {List<String> agentKeys = const [hostKey]}) =>
    ProjectAccessCoreAdapter(
      directory: '/workspace/demo',
      run: command.run,
      source: _source,
      registryCheckout: _registry,
      agentKeys: () async => agentKeys,
    );

class _CoreCommand {
  final calls = <({String program, List<String> arguments, String? directory})>[];
  final filed = <String, String>{};
  Ran? filingAnswer;
  Ran? verificationAnswer;
  Map<String, Object?> verification = {
    'project': 'demo',
    'commit': projectRevision,
    'access_commit': _base,
    'persons': <Map<String, Object?>>[
      <String, Object?>{
        'login': 'alice',
        'ssh': hostKey,
        'role': 'admin',
        'hosts': ['orchard'],
        'expires': '2030-01-01T00:00:00Z',
        'revoked': false,
        'locked': false,
      },
      <String, Object?>{
        'login': 'bob',
        'ssh': '',
        'role': 'developer',
        'hosts': ['orchard'],
        'expires': '',
        'revoked': true,
        'locked': false,
      },
    ],
    'admins': ['alice'],
    'certifiers': ['alice namespaces="git,porelo-message" cert-authority $hostKey'],
    'signers': [hostKey],
  };

  /// The access commit in force, which Core's verify answers and a filing moves.
  Object? get head => verification['access_commit'];
  set head(Object? revision) => verification['access_commit'] = revision;

  Map<String, Object?> get alice => (verification['persons'] as List).first as Map<String, Object?>;

  List<List<String>> get filings => [
    for (final call in calls)
      if (call.arguments[1] == 'access') call.arguments,
  ];

  Future<Ran> run(
    String program,
    List<String> arguments, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) async {
    calls.add((program: program, arguments: List.of(arguments), directory: inDirectory));
    if (arguments[1] == 'verify') {
      return verificationAnswer ?? (code: 0, out: jsonEncode(verification), err: '');
    }
    if (filingAnswer case final answer?) return answer;
    final id = arguments[arguments.indexOf('--id') + 1];
    final request = jsonEncode(arguments);
    if (filed.containsKey(id)) {
      // The same id on the same base answers the same revision, as Core's trailer lookup does.
      if (filed[id] != request) return (code: 64, out: '', err: 'ID already used for another change');
      return (code: 0, out: jsonEncode({'revision': _revision}), err: '');
    }
    final base = arguments.contains('--base') ? arguments[arguments.indexOf('--base') + 1] : null;
    if (base != null && base != head) return (code: 65, out: '', err: 'Base $base is not head $head');
    filed[id] = request;
    head = _revision;
    return (code: 0, out: jsonEncode({'revision': _revision}), err: '');
  }
}

void main() {
  // Harm: dependency exceptions must reach recovery as Retry rather than strand signed work.
  for (final failure in <Exception>[
    const WorkspaceRefused('private verification diagnostic'),
    const FormatException('private unsupported access format'),
    const RegistryRefusal('private delivery refusal'),
  ]) {
    test('delivery maps ${failure.runtimeType} to a safe Retry failure', () async {
      final adapter = ProjectAccessCoreAdapter(
        directory: '/workspace/demo',
        delivery: (change, revision) async => throw failure,
      );
      await expectLater(adapter.delivery(_change(), _revision), throwsA(isA<ProjectAccessRetry>()));
    });
  }

  // Harm: only a verdict naming this exact request and revision may discard signed work.
  for (final verdict in <ProjectAccessDelivery>[
    const ProjectAccessRevisionRefused(_id, _revision),
    const ProjectAccessRevisionOvertaken(_id, _revision),
  ]) {
    test('delivery retains typed ${verdict.runtimeType} without reading words', () async {
      final adapter = ProjectAccessCoreAdapter(directory: '/workspace/demo', delivery: (_, _) async => verdict);
      expect(await adapter.delivery(_change(), _revision), same(verdict));
    });
  }

  // Harm: verify format and process refusals must always leave a usable recovery failure.
  test('verification maps a process refusal to a safe Retry failure', () async {
    final command = _CoreCommand()..verificationAnswer = (code: 1, out: '', err: 'private diagnostic');
    final adapter = _adapter(command);
    await expectLater(adapter.verify('demo'), throwsA(isA<ProjectAccessRetry>()));
  });

  // Harm: an incorrectly scoped command can grant access on the wrong host or duplicate a signed edit.
  test('add sends the person host card role base and durable id as separate arguments', () async {
    final command = _CoreCommand();
    final adapter = _adapter(command);

    expect(await adapter.file(_change(), hasAccessFile: true), _revision);
    expect(command.calls.last.program, 'porelo');
    expect(command.calls.last.directory, '/workspace/demo');
    expect(command.filings.single, [
      'project',
      'access',
      'add',
      '--project',
      'demo',
      '--person',
      'bob',
      '--host',
      'orchard',
      '--card',
      path.join(_registry, 'people', 'bob.card'),
      '--role',
      'developer',
      '--base',
      _base,
      '--id',
      _id,
      '--json',
    ]);
  });

  // Harm: registration must initialize the first access state, never silently replace existing access.
  for (final exists in [false, true]) {
    test('register uses ${exists ? 'add with a base' : 'init without a base'} for the admin', () async {
      final command = _CoreCommand();
      final adapter = _adapter(command);

      expect(await adapter.file(_change(action: 'register'), hasAccessFile: exists), _revision);
      expect(command.filings.single, [
        'project',
        'access',
        exists ? 'add' : 'init',
        '--project',
        'demo',
        '--person',
        'alice',
        '--host',
        'orchard',
        '--card',
        path.join(_registry, 'people', 'alice.card'),
        // Core's init makes its person admin and refuses --role; add without it would make a developer.
        if (exists) ...['--role', 'admin', '--base', _base],
        '--id',
        _id,
        '--json',
      ]);
    });
  }

  // Harm: a host-scoped removal or lock would leave unintended access in this project.
  for (final action in ['remove', 'lock', 'unlock']) {
    test('$action is project wide and sends no host option', () async {
      final command = _CoreCommand();
      final adapter = _adapter(command);

      expect(await adapter.file(_change(action: action), hasAccessFile: true), _revision);
      expect(command.filings.single, [
        'project',
        'access',
        action,
        '--project',
        'demo',
        '--person',
        'bob',
        '--base',
        _base,
        '--id',
        _id,
        '--json',
      ]);
    });
  }

  // Harm: replacing a durable ID or hiding its collision can create duplicate or different grants.
  test('Core receives the same id on repeat and refuses its use for another change', () async {
    final command = _CoreCommand();
    final adapter = _adapter(command);
    expect(await adapter.file(_change(), hasAccessFile: true), _revision);
    expect(await adapter.file(_change(), hasAccessFile: true), _revision);
    await expectLater(adapter.file(_change(action: 'remove'), hasAccessFile: true), throwsA(isA<WorkspaceRefused>()));
    expect(command.filed.length, 1);
    expect(command.filings[0], command.filings[1]);
  });

  // Harm: automatically rebasing a refused access edit applies a grant the person never approved.
  test('a stale base rereads and requires another decision without retrying the edit', () async {
    final command = _CoreCommand()..head = _revision;
    final adapter = _adapter(command);

    await expectLater(
      adapter.file(_change(), hasAccessFile: true),
      throwsA(
        isA<ProjectAccessConflict>()
            .having((error) => error.words, 'both revisions', allOf(contains(_base), contains(_revision)))
            .having((error) => error.current['persons'], 'reread persons', command.verification['persons']),
      ),
    );
    expect(command.calls.map((call) => call.arguments[1]), ['verify', 'access', 'verify']);
    expect(command.filed, isEmpty);
  });

  // Harm: stale-base refresh failure must not allow an automatic edit against an unknown head.
  test('a failed stale-base refresh refuses without retry', () async {
    final command = _CoreCommand()
      ..filingAnswer = (code: 65, out: '', err: 'Base $_base is not head $_revision')
      ..verificationAnswer = (code: 1, out: '', err: 'refused');
    final adapter = _adapter(command);
    await expectLater(adapter.file(_change(), hasAccessFile: true), throwsA(isA<ProjectAccessRetry>()));
    expect(command.filings, isEmpty);
  });

  // Harm: unsafe external names must not select commands, paths, or another person's access.
  for (final entry in {
    'project': _change(project: '--json'),
    'host': _change(host: 'bad/host'),
    'actor': _change(action: 'register', actor: 'alice\nother'),
    'action': _change(action: 'purge'),
  }.entries) {
    test('invalid ${entry.key} causes no command', () async {
      final command = _CoreCommand();
      final adapter = _adapter(command);
      await expectLater(adapter.file(entry.value, hasAccessFile: true), throwsFormatException);
      expect(command.calls, isEmpty);
    });
  }

  // Harm: malformed or refused filing cannot become a published revision or leak private diagnostics.
  for (final answer in <String, Ran>{
    'nonzero exit': (code: 1, out: jsonEncode({'revision': _revision}), err: 'private diagnostic'),
    'missing revision': (code: 0, out: '{}', err: ''),
    'invalid revision': (code: 0, out: '{"revision":"--all"}', err: ''),
    'invalid JSON': (code: 0, out: 'not JSON', err: ''),
    'JSON array': (code: 0, out: '[]', err: ''),
  }.entries) {
    test('${answer.key} cannot confirm filing', () async {
      final command = _CoreCommand()..filingAnswer = answer.value;
      final adapter = _adapter(command);
      await expectLater(
        adapter.file(_change(), hasAccessFile: true),
        throwsA(anyOf(isA<WorkspaceRefused>(), isA<FormatException>())),
      );
      expect(command.filings.length, 1);
    });
  }

  // Harm: misreading verified persons can restore a revoked key or authorize a wrong project.
  test('verify retains the persons schema including revoked empty ssh and expiry', () async {
    final command = _CoreCommand();
    final adapter = _adapter(command);
    expect(await adapter.verify('demo'), command.verification);
    expect(command.calls.single.program, 'porelo');
    expect(command.calls.single.directory, '/workspace/demo');
    expect(command.calls.single.arguments, _verify);
  });

  // Harm: accepting a role that Core does not authorize can grant unintended authority.
  for (final role in ['owner', '', null, 1]) {
    test('verify refuses unsupported role $role', () async {
      final command = _CoreCommand();
      command.alice['role'] = role;
      final adapter = _adapter(command);
      await expectLater(adapter.verify('demo'), throwsA(isA<ProjectAccessRetry>()));
    });
  }

  // Harm: interpreting incomplete or inconsistent verified access can bypass revocation or project scope.
  for (final corrupt in <String, void Function(_CoreCommand)>{
    'legacy developers': (core) {
      core.verification.remove('persons');
      core.verification['developers'] = {};
    },
    'wrong project': (core) => core.verification['project'] = 'other',
    'invalid project commit': (core) => core.verification['commit'] = 'HEAD',
    'invalid access commit': (core) => core.verification['access_commit'] = '',
    'revoked with ssh': (core) => core.alice['revoked'] = true,
    'missing lock verdict': (core) => core.alice.remove('locked'),
    'unsafe host': (core) => core.alice['hosts'] = ['../other'],
    'missing hosts': (core) => core.alice.remove('hosts'),
    'unknown admin': (core) => core.verification['admins'] = ['mallory'],
    'locked admin': (core) => core.alice['locked'] = true,
    'invalid signer': (core) => core.verification['signers'] = ['bad key'],
    'missing certifiers': (core) => core.verification.remove('certifiers'),
    'duplicate person': (core) => (core.verification['persons'] as List).add(Map.of(core.alice)),
  }.entries) {
    test('verify refuses ${corrupt.key}', () async {
      final command = _CoreCommand();
      corrupt.value(command);
      final adapter = _adapter(command);
      await expectLater(adapter.verify('demo'), throwsA(isA<ProjectAccessRetry>()));
    });
  }

  // Harm: a verify without the project copy and pinned keys is wrong use that never answers who is admin.
  test('verify without a project copy sends nothing', () async {
    final command = _CoreCommand();
    final adapter = ProjectAccessCoreAdapter(directory: '/workspace/demo', run: command.run);
    await expectLater(adapter.verify('demo'), throwsA(isA<ProjectAccessRetry>()));
    expect(command.calls, isEmpty);
  });

  // Harm: a person who is no active admin here, or whose key the agent does not hold, must never send a change.
  for (final entry in <String, ({List<String> agent, void Function(_CoreCommand) state})>{
    'a non-admin': (
      agent: [hostKey],
      state: (core) {
        core.alice['role'] = 'developer';
        core.verification['admins'] = <String>[];
      },
    ),
    'a locked admin': (
      agent: [hostKey],
      state: (core) {
        core.alice['locked'] = true;
        core.verification['admins'] = <String>[];
      },
    ),
    'an admin whose key the agent does not hold': (agent: <String>[], state: (_) {}),
    'an admin whose agent holds another key': (
      agent: ['ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgY'],
      state: (_) {},
    ),
  }.entries) {
    for (final action in ['add', 'remove', 'lock', 'unlock', 'replace']) {
      test('${entry.key} sends no $action', () async {
        final command = _CoreCommand();
        entry.value.state(command);
        final adapter = _adapter(command, agentKeys: entry.value.agent);
        await expectLater(
          adapter.file(_change(action: action), hasAccessFile: true),
          throwsA(isA<ProjectAccessNotAdmin>()),
        );
        expect(command.filings, isEmpty);
      });
    }
  }

  // Harm: with several admin signers pinned, Core would sign alice's change with carol's key the agent holds.
  for (final action in ['add', 'remove', 'lock', 'unlock', 'replace']) {
    test('an admin whose own key the agent does not hold sends no $action though it holds another signer', () async {
      const carolKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgY';
      final command = _CoreCommand();
      (command.verification['persons'] as List).add(<String, Object?>{
        'login': 'carol',
        'ssh': carolKey,
        'role': 'admin',
        'hosts': ['orchard'],
        'expires': '2030-01-01T00:00:00Z',
        'revoked': false,
        'locked': false,
      });
      command.verification['admins'] = ['alice', 'carol'];
      command.verification['signers'] = [hostKey, carolKey];
      final adapter = _adapter(command, agentKeys: const [carolKey]);
      await expectLater(
        adapter.file(_change(action: action), hasAccessFile: true),
        throwsA(isA<ProjectAccessNotAdmin>()),
      );
      expect(command.filings, isEmpty);
    });
  }

  // Harm: an admin whose own key is held but not pinned for the project would have Core refuse or sign otherwise.
  test('an admin whose own key is not a pinned signer sends nothing', () async {
    final command = _CoreCommand();
    command.verification['signers'] = [
      'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgY',
    ];
    final adapter = _adapter(command);
    await expectLater(adapter.file(_change(), hasAccessFile: true), throwsA(isA<ProjectAccessNotAdmin>()));
    expect(command.filings, isEmpty);
  });

  // Harm: a refused admin must learn whom to ask rather than meet a silent dead end.
  test('a refused admin is told the active admins', () async {
    final command = _CoreCommand();
    final adapter = _adapter(command, agentKeys: const []);
    await expectLater(
      adapter.file(_change(), hasAccessFile: true),
      throwsA(isA<ProjectAccessNotAdmin>().having((error) => error.whoMay.single.login, 'who may', 'alice')),
    );
  });

  // Harm: a replacement without the base in force or a stable id could put a new key in twice or on stale access.
  test('replace sends the new card, the access commit in force and the durable id', () async {
    final command = _CoreCommand();
    final adapter = _adapter(command);

    expect(await adapter.file(_change(action: 'replace'), hasAccessFile: true), _revision);
    expect(command.filings.single, [
      'project',
      'access',
      'replace',
      '--project',
      'demo',
      '--person',
      'bob',
      '--card',
      path.join(_registry, 'people', 'bob.card'),
      '--base',
      _base,
      '--id',
      _id,
      '--json',
    ]);
  });

  // Harm: a retry after a lost reply that sends another id or base would file a second change.
  for (final action in ['add', 'replace']) {
    test('a retried $action after the reply was lost answers the same revision', () async {
      final command = _CoreCommand();
      final adapter = _adapter(command);
      expect(await adapter.file(_change(action: action), hasAccessFile: true), _revision);
      expect(command.head, _revision);
      expect(await adapter.file(_change(action: action), hasAccessFile: true), _revision);
      expect(command.filed.length, 1);
      expect(command.filings[1], command.filings[0]);
      expect(command.filings[1], containsAllInOrder(['--base', _base, '--id', _id]));
    });
  }

  // Harm: a 65 on a moved base must ask again, never file again on the old base.
  test('a conflicting replace rereads and is not sent again', () async {
    final command = _CoreCommand()..head = _revision;
    final adapter = _adapter(command);
    await expectLater(
      adapter.file(_change(action: 'replace'), hasAccessFile: true),
      throwsA(isA<ProjectAccessConflict>().having((error) => error.current['access_commit'], 'reread', _revision)),
    );
    expect(command.filings.length, 1);
    expect(command.filed, isEmpty);
  });

  // Harm: a refusal on the base in force is no conflict; offering a fresh decision would repeat the refused change.
  test('a 65 refusal on the base in force keeps Core typed reason and is no conflict', () async {
    final command = _CoreCommand()
      ..filingAnswer = (code: 65, out: jsonEncode({'reason': 'not-signer', 'words': 'Sign with alice key'}), err: '');
    final adapter = _adapter(command);
    await expectLater(
      adapter.file(_change(), hasAccessFile: true),
      throwsA(
        isA<ProjectAccessFilingRefused>()
            .having((error) => error.code, 'code', 65)
            .having((error) => error.reason, 'reason', 'not-signer')
            .having((error) => error.words, 'words', 'Sign with alice key'),
      ),
    );
  });

  // Harm: an exit code read as the wrong outcome hides a push failure or an unreached repository.
  for (final code in [64, 66, 69]) {
    test('exit $code is a typed filing refusal without diagnostics', () async {
      final command = _CoreCommand()..filingAnswer = (code: code, out: '', err: 'private diagnostic');
      final adapter = _adapter(command);
      await expectLater(
        adapter.file(_change(), hasAccessFile: true),
        throwsA(
          isA<ProjectAccessFilingRefused>()
              .having((error) => error.code, 'code', code)
              .having((error) => error.words, 'words', isNot(contains('private'))),
        ),
      );
      expect(command.filings.length, 1);
    });
  }
}
