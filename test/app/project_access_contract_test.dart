import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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

class _CoreCommand {
  final calls = <({String program, List<String> arguments, String? directory})>[];
  final filed = <String, String>{};
  Ran? filingAnswer;
  Ran? verificationAnswer;
  Map<String, Object?> verification = {
    'project': 'demo',
    'commit': projectRevision,
    'access_commit': _revision,
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

  Map<String, Object?> get alice => (verification['persons'] as List).first as Map<String, Object?>;

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
    if (filed.containsKey(id) && filed[id] != request) {
      return (code: 64, out: '', err: 'ID already used for another change');
    }
    filed[id] = request;
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
    final adapter = ProjectAccessCoreAdapter(directory: '/workspace/demo', run: command.run);
    await expectLater(adapter.verify('demo'), throwsA(isA<ProjectAccessRetry>()));
  });

  // Harm: an incorrectly scoped command can grant access on the wrong host or duplicate a signed edit.
  test('add sends the person host base and durable id as separate arguments', () async {
    final command = _CoreCommand();
    final adapter = ProjectAccessCoreAdapter(directory: '/workspace/demo', run: command.run);

    expect(await adapter.file(_change(), hasAccessFile: true), _revision);
    expect(command.calls.single.program, 'porelo');
    expect(command.calls.single.directory, '/workspace/demo');
    expect(command.calls.single.arguments, [
      'project',
      'access',
      'add',
      '--project',
      'demo',
      '--person',
      'bob',
      '--host',
      'orchard',
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
      final adapter = ProjectAccessCoreAdapter(directory: '/workspace/demo', run: command.run);

      expect(await adapter.file(_change(action: 'register'), hasAccessFile: exists), _revision);
      expect(command.calls.single.arguments, [
        'project',
        'access',
        exists ? 'add' : 'init',
        '--project',
        'demo',
        '--person',
        'alice',
        '--host',
        'orchard',
        if (exists) ...['--base', _base],
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
      final adapter = ProjectAccessCoreAdapter(directory: '/workspace/demo', run: command.run);

      expect(await adapter.file(_change(action: action), hasAccessFile: true), _revision);
      expect(command.calls.single.arguments, [
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
    final adapter = ProjectAccessCoreAdapter(directory: '/workspace/demo', run: command.run);
    expect(await adapter.file(_change(), hasAccessFile: true), _revision);
    expect(await adapter.file(_change(), hasAccessFile: true), _revision);
    await expectLater(adapter.file(_change(action: 'remove'), hasAccessFile: true), throwsA(isA<WorkspaceRefused>()));
    expect(command.filed.length, 1);
    expect(command.calls[0].arguments, command.calls[1].arguments);
  });

  // Harm: automatically rebasing a refused access edit applies a grant the person never approved.
  test('a stale base rereads and requires another decision without retrying the edit', () async {
    final command = _CoreCommand()..filingAnswer = (code: 65, out: '', err: 'Base $_base is not head $_revision');
    final adapter = ProjectAccessCoreAdapter(directory: '/workspace/demo', run: command.run);

    await expectLater(
      adapter.file(_change(), hasAccessFile: true),
      throwsA(
        isA<ProjectAccessConflict>()
            .having((error) => error.words, 'both revisions', allOf(contains(_base), contains(_revision)))
            .having((error) => error.current['persons'], 'reread persons', command.verification['persons']),
      ),
    );
    expect(command.calls.map((call) => call.arguments[1]), ['access', 'verify']);
    expect(command.filed, isEmpty);
  });

  // Harm: stale-base refresh failure must not allow an automatic edit against an unknown head.
  test('a failed stale-base refresh refuses without retry', () async {
    final command = _CoreCommand()
      ..filingAnswer = (code: 65, out: '', err: 'Base $_base is not head $_revision')
      ..verificationAnswer = (code: 1, out: '', err: 'refused');
    final adapter = ProjectAccessCoreAdapter(directory: '/workspace/demo', run: command.run);
    await expectLater(adapter.file(_change(), hasAccessFile: true), throwsA(isA<ProjectAccessRetry>()));
    expect(command.calls.length, 2);
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
      final adapter = ProjectAccessCoreAdapter(directory: '/workspace/demo', run: command.run);
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
      final adapter = ProjectAccessCoreAdapter(directory: '/workspace/demo', run: command.run);
      await expectLater(
        adapter.file(_change(), hasAccessFile: true),
        throwsA(anyOf(isA<WorkspaceRefused>(), isA<FormatException>())),
      );
      expect(command.calls.length, 1);
    });
  }

  // Harm: misreading verified persons can restore a revoked key or authorize a wrong project.
  test('verify retains the persons schema including revoked empty ssh and expiry', () async {
    final command = _CoreCommand();
    final adapter = ProjectAccessCoreAdapter(directory: '/workspace/demo', run: command.run);
    expect(await adapter.verify('demo'), command.verification);
    expect(command.calls.single.program, 'porelo');
    expect(command.calls.single.directory, '/workspace/demo');
    expect(command.calls.single.arguments, ['project', 'verify', '--json']);
  });

  // Harm: accepting a role that Core does not authorize can grant unintended authority.
  for (final role in ['owner', '', null, 1]) {
    test('verify refuses unsupported role $role', () async {
      final command = _CoreCommand();
      command.alice['role'] = role;
      final adapter = ProjectAccessCoreAdapter(directory: '/workspace/demo', run: command.run);
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
      final adapter = ProjectAccessCoreAdapter(directory: '/workspace/demo', run: command.run);
      await expectLater(adapter.verify('demo'), throwsA(isA<ProjectAccessRetry>()));
    });
  }
}
