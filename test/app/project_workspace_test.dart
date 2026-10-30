// Linux only: it runs chmod, ssh-agent and ssh-keygen as on Linux.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/project_workspace.dart';

/// The workspace against a real git and a real ssh agent: a bare repository stands in for the forge,
/// a throwaway key in a throwaway agent for the person's own.
void main() {
  late Directory here;
  late String agentSocket;
  late int agentPid;
  final seen = <List<String>>[];

  Future<Ran> recording(
    String program,
    List<String> arguments, {
    String? inDirectory,
    Map<String, String> environment = const <String, String>{},
    String? input,
  }) {
    seen.add(<String>[program, ...arguments]);
    return runHere(
      program,
      arguments,
      inDirectory: inDirectory,
      environment: <String, String>{...environment, 'SSH_AUTH_SOCK': agentSocket, ..._alone(here.path)},
      input: input,
    );
  }

  setUp(() async {
    seen.clear();
    here = await Directory.systemTemp.createTemp('porelo-workspace-');
    // The forge: a bare repository with a first commit on main.
    Future<void> git(List<String> args, [String? dir]) async {
      final ran = await Process.run('git', args, workingDirectory: dir, environment: _alone(here.path));
      expect(ran.exitCode, 0, reason: '${ran.stderr}');
    }

    await git(<String>['init', '-q', '--bare', '-b', 'main', '${here.path}/forge.git']);
    await git(<String>['clone', '-q', '${here.path}/forge.git', '${here.path}/seed']);
    await File('${here.path}/seed/README.md').writeAsString('hello\n');
    await git(<String>[
      '-c',
      'user.name=seed',
      '-c',
      'user.email=seed@example.invalid',
      'commit',
      '-q',
      '--allow-empty',
      '-m',
      'first',
    ], '${here.path}/seed');
    await git(<String>['push', '-q', 'origin', 'HEAD:main'], '${here.path}/seed');
    // The person's key, in an agent of this test's own.
    _ran(
      await Process.run('ssh-keygen', <String>[
        '-q',
        '-t',
        'ed25519',
        '-N',
        '',
        '-C',
        'person@test',
        '-f',
        '${here.path}/key',
      ]),
    );
    agentSocket = '${here.path}/agent.sock';
    final agent = await Process.run('ssh-agent', <String>['-a', agentSocket]);
    agentPid = int.parse(RegExp(r'SSH_AGENT_PID=(\d+)').firstMatch('${agent.stdout}')!.group(1)!);
    _ran(
      await Process.run(
        'ssh-add',
        <String>['${here.path}/key'],
        environment: <String, String>{'SSH_AUTH_SOCK': agentSocket},
      ),
    );
  });

  tearDown(() async {
    Process.killPid(agentPid);
    await here.delete(recursive: true);
  });

  ProjectWorkspace workspace() => ProjectWorkspace(
    ForgeRepository(
      fullName: 'acme/api',
      sshUrl: '',
      httpsUrl: '${here.path}/forge.git',
      defaultBranch: 'main',
      admin: true,
      push: true,
      private: true,
    ),
    'ghp_never-on-a-command-line',
    root: '${here.path}/work',
    run: recording,
    sshDirectory: '${here.path}/.ssh',
  );

  test('a repository name that would leave the working folders gets no folder', () {
    final outside = ProjectWorkspace(
      const ForgeRepository(
        fullName: '../../outside',
        sshUrl: '',
        httpsUrl: '',
        defaultBranch: 'main',
        admin: false,
        push: false,
        private: true,
      ),
      'ghp_never-on-a-command-line',
      root: '${here.path}/work',
      run: recording,
    );
    expect(() => outside.folder, throwsA(isA<ForgeRefused>()));
    expect(outside.open(), throwsA(isA<ForgeRefused>()));
  });

  test('project.yml is committed signed with the person’s key and pushed to the default branch', () async {
    final work = workspace();
    await work.open();
    expect(await work.read(), isNull, reason: 'no project.yml yet');
    await work.write('project:\n  name: "api"\n');
    expect(await work.diff(), contains('+  name: "api"'));

    final keys = await work.signingKeys();
    expect(keys.single.comment, 'person@test');
    expect(keys.single.fingerprint, startsWith('SHA256:'));

    final commit = await work.commitAndPush('Make api a Porelo project', keys.single, login: 'alice');

    // On the forge, signed by exactly that key.
    await File('${here.path}/allowed').writeAsString('person@test ${keys.single.publicKey}\n');
    final verified = await Process.run(
      'git',
      <String>['-c', 'gpg.ssh.allowedSignersFile=${here.path}/allowed', 'verify-commit', commit],
      workingDirectory: '${here.path}/forge.git',
      environment: _alone(here.path),
    );
    expect(verified.exitCode, 0, reason: '${verified.stderr}');
    expect('${verified.stderr}', contains('Good "git" signature for person@test'));
    final onMain = await Process.run(
      'git',
      <String>['rev-parse', 'main'],
      workingDirectory: '${here.path}/forge.git',
      environment: _alone(here.path),
    );
    expect('${onMain.stdout}'.trim(), commit);
  });

  // The first push went to a token without the right to write; the second, after the
  // right was given, was refused as nothing to commit.
  test('a commit whose push was refused is pushed when tried again, made over itself', () async {
    final hook = File('${here.path}/forge.git/hooks/pre-receive');
    await hook.writeAsString('#!/bin/sh\necho "Write access to repository not granted." >&2\nexit 1\n');
    await Process.run('chmod', <String>['+x', hook.path]);
    final work = workspace();
    await work.open();
    await work.write('project:\n  name: "api"\n');
    final key = (await work.signingKeys()).single;
    // Which right is missing, and where it is given, rather than git's words alone (walk: "Write access").
    await expectLater(
      work.commitAndPush('First words', key, login: 'alice'),
      throwsA(isA<WorkspaceRefused>().having((each) => each.words, 'words', contains('Contents: Read and write'))),
    );

    await hook.delete();
    final commit = await work.commitAndPush('Make api a Porelo project', key, login: 'alice');

    final onMain = await Process.run(
      'git',
      <String>['log', '--format=%H %s', 'main'],
      workingDirectory: '${here.path}/forge.git',
      environment: _alone(here.path),
    );
    expect('${onMain.stdout}'.trim().split('\n').first, '$commit Make api a Porelo project');
    expect('${onMain.stdout}', isNot(contains('First words')));
  });

  test('the token never appears on a command line', () async {
    final work = workspace();
    await work.open();
    await work.write('project:\n  name: "api"\n');
    await work.commitAndPush('x', (await work.signingKeys()).single, login: 'alice');

    expect(seen.expand((each) => each).where((each) => each.contains('ghp_never')), isEmpty);
  });

  test('an agent with no key is said as that, not as a failure of git', () async {
    _ran(await Process.run('ssh-add', <String>['-D'], environment: <String, String>{'SSH_AUTH_SOCK': agentSocket}));

    await expectLater(
      workspace().signingKeys(),
      throwsA(isA<WorkspaceRefused>().having((it) => it.words, 'words', contains('Your ssh agent holds no key'))),
    );
  });

  // What a machine that only reads the project's repository hands over: its pending work as a bundle,
  // merged here signed with the person's key and pushed.
  test('pending work from a gate is taken as a bundle, merged signed and pushed', () async {
    Future<ProcessResult> git(List<String> args, String dir) =>
        Process.run('git', args, workingDirectory: dir, environment: _alone(here.path));
    // What a machine's task made: one commit on top of main, handed over as a bundle.
    await git(<String>['checkout', '-q', '-b', 'task'], '${here.path}/seed');
    await File('${here.path}/seed/project.yml').writeAsString('project:\n  name: "api"\n');
    await git(<String>['add', 'project.yml'], '${here.path}/seed');
    await git(<String>[
      '-c',
      'user.name=task',
      '-c',
      'user.email=task@example.invalid',
      'commit',
      '-q',
      '-m',
      'Add the project file',
    ], '${here.path}/seed');
    await git(<String>['bundle', 'create', '${here.path}/pending.bundle', 'main..task'], '${here.path}/seed');
    // The bundle names the task branch; the gate's names the pending ref, as the machine makes it.
    await git(<String>['update-ref', 'refs/porelo/incoming/work', 'task'], '${here.path}/seed');
    await git(<String>[
      'bundle',
      'create',
      '${here.path}/pending.bundle',
      'main..refs/porelo/incoming/work',
    ], '${here.path}/seed');

    final work = workspace();
    await work.open();
    final diff = await work.takeBundle(await File('${here.path}/pending.bundle').readAsBytes(), 'work');
    expect(diff, contains('+  name: "api"'));

    final key = (await work.signingKeys()).single;
    final merged = await work.mergeAndPush('work', 'Take the planning task’s project file', key, login: 'alice');

    await File('${here.path}/allowed').writeAsString('person@test ${key.publicKey}\n');
    final verified = await Process.run(
      'git',
      <String>['-c', 'gpg.ssh.allowedSignersFile=${here.path}/allowed', 'verify-commit', merged],
      workingDirectory: '${here.path}/forge.git',
      environment: _alone(here.path),
    );
    expect(verified.exitCode, 0, reason: '${verified.stderr}');
    final onMain = await Process.run(
      'git',
      <String>['show', 'main:project.yml'],
      workingDirectory: '${here.path}/forge.git',
      environment: _alone(here.path),
    );
    expect('${onMain.stdout}', contains('name: "api"'));
  });
}

/// The environment git and ssh run in here: the test's own home, and none of the host's git
/// configuration, neither `/etc/gitconfig` nor `$XDG_CONFIG_HOME/git/config`, which would sign, rewrite
/// or refuse as the host says.
Map<String, String> _alone(String home) => <String, String>{
  'HOME': home,
  'XDG_CONFIG_HOME': '$home/.config',
  'GIT_CONFIG_NOSYSTEM': '1',
};

/// [ran]'s exit code held to 0: a key not made, or not added to the agent, would make every test
/// after it pass for the wrong reason.
void _ran(ProcessResult ran) => expect(ran.exitCode, 0, reason: '${ran.stderr}');
