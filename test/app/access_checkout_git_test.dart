// Real Git, a test-owned ssh-agent, ssh-keygen and the private checkout's chmod run as on Linux.
@Tags(['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/access_checkout.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:yaml/yaml.dart';

import '../support/fake_signer_policy.dart';

/// One process the checkout ran: the program, its arguments and the environment it ran in.
typedef _Call = ({String program, List<String> arguments, Map<String, String> environment, String? input});

/// The Git command among [arguments], past any `-c` options.
String _verb(List<String> arguments) {
  for (var i = 0; i < arguments.length; i++) {
    if (arguments[i] == '-c') {
      i++;
    } else if (!arguments[i].startsWith('-')) {
      return arguments[i];
    }
  }
  return '';
}

void main() {
  late Directory scratch;
  late Directory source;
  late String central;
  late String keys;
  late String agentSocket;
  late String hostileConfig;
  late FakeSignerPolicy core;
  late List<_Call> calls;
  int? agentPid;
  var failClone = false;
  var failPush = false;
  var failCommit = false;
  var accessPushes = 0;
  var changes = 0;

  String pub(String name) => File('$keys/$name.pub').readAsStringSync().trim().split(' ').take(2).join(' ');
  String cache() => '${scratch.path}/access/demo';
  String bundle(String name) => '${scratch.path}/$name.bundle';

  Future<void> tool(String program, List<String> arguments, {Map<String, String> environment = const {}}) async {
    final ran = await Process.run(program, arguments, environment: environment);
    expect(ran.exitCode, 0, reason: 'fixture $program ${arguments.first}: ${ran.stderr}');
  }

  Future<void> agent(List<String> arguments) => tool('ssh-add', arguments, environment: {'SSH_AUTH_SOCK': agentSocket});

  // The fixture's own Git signs with key files and no agent: how the origin's other signers committed, never the checkout.
  Future<ProcessResult> fixtureRun(
    List<String> arguments, {
    String? directory,
    Map<String, String> environment = const {},
  }) => Process.run(
    'git',
    ['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', ...arguments],
    workingDirectory: directory ?? source.path,
    environment: {
      'GIT_CONFIG_GLOBAL': '/dev/null',
      'GIT_CONFIG_NOSYSTEM': '1',
      'GIT_TERMINAL_PROMPT': '0',
      'SSH_AUTH_SOCK': '',
      ...environment,
    },
  );

  Future<String> fixture(
    List<String> arguments, {
    String? directory,
    Map<String, String> environment = const {},
  }) async {
    final ran = await fixtureRun(arguments, directory: directory, environment: environment);
    expect(ran.exitCode, 0, reason: 'fixture Git operation failed: ${ran.stderr}');
    return '${ran.stdout}'.trim();
  }

  /// Commits a change at the origin signed with the key file [key], claiming [date] when given, and pushes it.
  Future<String> originCommit(String key, {DateTime? date}) async {
    File('${source.path}/access.yml').writeAsStringSync('developers: {}\n# change ${++changes}\n');
    final claimed = date == null ? null : '@${date.millisecondsSinceEpoch ~/ 1000} +0000';
    await fixture(
      ['-c', 'gpg.format=ssh', '-c', 'user.signingkey=$keys/$key', 'commit', '-S', '-am', 'Change by $key'],
      environment: {
        if (claimed != null) ...{'GIT_COMMITTER_DATE': claimed, 'GIT_AUTHOR_DATE': claimed},
      },
    );
    await fixture(['push']);
    return fixture(['rev-parse', 'HEAD']);
  }

  /// What Git alone says of [revision] in the central repository, judged against Core's lines.
  Future<ProcessResult> gitVerifies(String revision, {String? directory}) {
    final lines = File('${scratch.path}/core-lines')..writeAsStringSync('${core.allowedSigners.join('\n')}\n');
    return fixtureRun([
      '-c',
      'gpg.ssh.allowedSignersFile=${lines.path}',
      'verify-commit',
      revision,
    ], directory: directory ?? central);
  }

  Future<Ran> machine(
    String program,
    List<String> arguments, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) {
    // The person's own configuration and agent are what this computer offers; the checkout's environment overrides it.
    final offered = {'SSH_AUTH_SOCK': agentSocket, 'GIT_CONFIG_GLOBAL': hostileConfig, ...environment};
    calls.add((program: program, arguments: List.of(arguments), environment: offered, input: input));
    if (program == 'git') {
      final verb = _verb(arguments);
      if (verb == 'clone' && failClone) {
        failClone = false;
        return Future.value((code: 1, out: '', err: 'clone refused'));
      }
      if (verb == 'commit' && failCommit) return Future.value((code: 1, out: '', err: 'commit refused'));
      if (verb == 'push') {
        accessPushes++;
        if (failPush) return Future.value((code: 1, out: '', err: 'push refused'));
      }
      arguments = ['-c', 'url.file://$central.insteadOf=https://example.org/team/access.git', ...arguments];
    }
    return runHere(program, arguments, inDirectory: inDirectory, environment: offered, input: input);
  }

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('access-git-');
    keys = '${scratch.path}/keys';
    Directory(keys).createSync();
    source = Directory('${scratch.path}/source')..createSync();
    central = '${scratch.path}/central.git';
    calls = [];
    failClone = failPush = failCommit = false;
    accessPushes = changes = 0;
    agentPid = null;
    for (final key in ['person', 'admin2', 'other', 'old', 'task']) {
      await tool('ssh-keygen', ['-q', '-t', 'ed25519', '-N', '', '-C', key, '-f', '$keys/$key']);
    }
    agentSocket = '${scratch.path}/agent.sock';
    final started = await Process.run('ssh-agent', ['-a', agentSocket]);
    expect(started.exitCode, 0, reason: 'fixture ssh-agent: ${started.stderr}');
    agentPid = int.parse(RegExp(r'SSH_AGENT_PID=(\d+)').firstMatch('${started.stdout}')!.group(1)!);
    await agent(['-q', '$keys/person']);
    final refuse = File('${scratch.path}/refuse-to-sign')..writeAsStringSync('#!/bin/sh\nexit 1\n');
    await tool('chmod', ['700', refuse.path]);
    hostileConfig = '${scratch.path}/hostile.gitconfig';
    File(hostileConfig).writeAsStringSync(
      '[user]\n\tname = Hostile\n\temail = hostile@example.invalid\n\tsigningkey = $keys/other\n'
      '[gpg]\n\tformat = openpgp\n[gpg "ssh"]\n\tprogram = ${refuse.path}\n'
      '[commit]\n\tgpgsign = false\n[log]\n\tshowSignature = true\n',
    );
    core = FakeSignerPolicy(
      login: 'alice',
      key: pub('person'),
      allowedSigners: [
        'alice namespaces="git" ${pub('person')}',
        'bob namespaces="git" ${pub('admin2')}',
        'task:demo:* cert-authority,namespaces="git" ${pub('person')}',
      ],
    );
    await fixture(['init', '--bare', '--initial-branch=main', central]);
    await fixture(['init', '--initial-branch=main']);
    File('${source.path}/access.yml').writeAsStringSync('# Keep this private\ndevelopers: {} # People\n');
    await fixture(['add', 'access.yml']);
    await fixture([
      '-c',
      'gpg.format=ssh',
      '-c',
      'user.signingkey=$keys/person',
      'commit',
      '-S',
      '-m',
      'Private access fixture',
    ]);
    await fixture(['remote', 'add', 'origin', central]);
    await fixture(['push', '-u', 'origin', 'main']);
  });
  tearDown(() async {
    if (agentPid case final pid?) Process.killPid(pid);
    await scratch.delete(recursive: true);
  });

  AccessCheckout checkout() => AccessCheckout(
    root: '${scratch.path}/access',
    project: 'demo',
    repository: 'https://example.org/team/access.git',
    signers: core,
    run: machine,
  );

  Future<void> change(AccessCheckout access) =>
      access.edit((source) => source.contains('# Changed access') ? source : '$source\n# Changed access\n');

  // Harm: an access change leaves signed with a key Core did not select, or through the person's own Git setup.
  test('publication signs with Core\'s person key through the agent, whatever Git is set to sign with', () async {
    final access = checkout();
    await access.open();
    await fixture(['config', 'user.signingkey', '$keys/other'], directory: cache());
    await fixture(['config', 'gpg.ssh.program', '${scratch.path}/refuse-to-sign'], directory: cache());
    await change(access);
    await access.commitPushAndBundle(bundle('access'));
    final published = await fixture(['rev-parse', 'main'], directory: central);
    final verified = await gitVerifies(published);
    expect(verified.exitCode, 0, reason: '${verified.stderr}');
    expect('${verified.stderr}', contains('Good "git" signature for alice with ED25519 key'));
    expect(await fixture(['log', '-1', '--format=%an', 'main'], directory: central), 'alice');
  });

  // Harm: without the person's key in the agent, a commit signed some other way is published.
  test('an agent without the person\'s key publishes nothing and leaves the remote unchanged', () async {
    final access = checkout();
    await access.open();
    await change(access);
    await agent(['-D']);
    await agent(['-q', '$keys/other']);
    final before = await fixture(['rev-parse', 'main'], directory: central);
    await expectLater(access.commitPushAndBundle(bundle('access')), throwsA(isA<WorkspaceRefused>()));
    expect(await fixture(['rev-parse', 'main'], directory: central), before);
    expect(accessPushes, 0);
    expect(File(bundle('access')).existsSync(), isFalse);
  });

  // Harm: a person Core no longer accepts publishes an access change because the interface still trusts them.
  test(
    'a person whose key Core no longer lists publishes nothing, though the history they read was accepted',
    () async {
      final tip = await fixture(['rev-parse', 'main'], directory: central);
      core.verdicts[tip] = 'accepted';
      core.allowedSigners = ['bob namespaces="git" ${pub('admin2')}'];
      final access = checkout();
      await access.open();
      await change(access);
      await expectLater(access.commitPushAndBundle(bundle('access')), throwsA(isA<WorkspaceRefused>()));
      expect(await fixture(['rev-parse', 'main'], directory: central), tip);
      expect(accessPushes, 0);
    },
  );

  group('an origin commit', () {
    late String before;

    setUp(() async {
      await checkout().open();
      before = await fixture(['rev-parse', 'HEAD'], directory: cache());
    });

    Future<void> advancesTo(String revision) async {
      await checkout().open();
      expect(await fixture(['rev-parse', 'HEAD'], directory: cache()), revision);
    }

    Future<void> isRefused() async {
      await expectLater(checkout().open(), throwsA(isA<WorkspaceRefused>()));
      expect(await fixture(['rev-parse', 'HEAD'], directory: cache()), before, reason: 'the checkout did not advance');
    }

    // Harm: a project with several admins cannot read the access file another admin signed.
    test('signed by another current signer is advanced to', () async {
      await advancesTo(await originCommit('admin2'));
    });

    // Harm: a task certified by an admitted person cannot change what it was started for.
    test('signed by a task key the person certified, with its principal and namespace, is advanced to', () async {
      await tool('ssh-keygen', [
        '-q',
        '-s',
        '$keys/person',
        '-I',
        'task',
        '-n',
        'task:demo:t1',
        '-V',
        '-5m:+1h',
        '$keys/task.pub',
      ]);
      await advancesTo(await originCommit('task-cert.pub'));
    });

    // Harm: a task of another project, or one certified for messages, changes this project's access.
    test('signed by a task certificate for another principal is refused', () async {
      await tool('ssh-keygen', [
        '-q',
        '-s',
        '$keys/person',
        '-I',
        'task',
        '-n',
        'task:other:t1',
        '-V',
        '-5m:+1h',
        '$keys/task.pub',
      ]);
      await originCommit('task-cert.pub');
      await isRefused();
    });

    test('signed by a key Core admits only for another namespace is refused', () async {
      core.allowedSigners = [
        'alice namespaces="git" ${pub('person')}',
        'task:demo:* cert-authority,namespaces="porelo-message" ${pub('person')}',
      ];
      await tool('ssh-keygen', [
        '-q',
        '-s',
        '$keys/person',
        '-I',
        'task',
        '-n',
        'task:demo:t1',
        '-V',
        '-5m:+1h',
        '$keys/task.pub',
      ]);
      await originCommit('task-cert.pub');
      await isRefused();
    });

    // Harm: anybody with write access to the repository changes who may reach the project.
    test('signed by a key Core does not list is refused', () async {
      await originCommit('other');
      await isRefused();
    });

    // Harm: a task's expired certificate signs on by claiming a time when it was valid.
    test('signed by an expired task certificate is refused even when it claims a time it was valid', () async {
      await tool('ssh-keygen', [
        '-q',
        '-s',
        '$keys/person',
        '-I',
        'task',
        '-n',
        'task:demo:t2',
        '-V',
        '-3h:-1h',
        '$keys/task.pub',
      ]);
      final revision = await originCommit('task-cert.pub', date: DateTime.now().subtract(const Duration(hours: 2)));
      expect((await gitVerifies(revision)).exitCode, 0, reason: 'Git alone believes the time the commit claims');
      await isRefused();
    });

    // Harm: a retired or stolen key signs new access changes by backdating them before its retirement.
    test('signed by a retired key and backdated is refused unless Core recorded it as accepted', () async {
      final retired = DateTime.now().toUtc().subtract(const Duration(days: 1));
      final stamp = '${retired.toIso8601String().replaceAll(RegExp(r'[-:T]'), '').split('.').first}Z';
      core.allowedSigners.add('alice namespaces="git",valid-before="$stamp" ${pub('old')}');
      final revision = await originCommit('old', date: DateTime.now().subtract(const Duration(days: 2)));
      expect((await gitVerifies(revision)).exitCode, 0, reason: 'Git alone believes the time the commit claims');
      await isRefused();
      core.verdicts[revision] = 'accepted';
      await advancesTo(revision);
    });

    // Harm: a commit Core refused when it arrived is read as good because its signature still checks.
    test('Core recorded as refused is refused though its signer is in force', () async {
      final revision = await originCommit('admin2');
      core.verdicts[revision] = 'refused';
      await isRefused();
    });

    // Harm: a verdict word Core adds later is read as acceptance.
    test('with a verdict this interface does not know is refused', () async {
      final revision = await originCommit('admin2');
      core.verdicts[revision] = 'accepted-later';
      await isRefused();
    });
  });

  // Harm: without Core's policy the interface falls back to a trust set of its own.
  for (final (name, answer) in [
    ('an unsupported method', const FeatureNotSupported('ProjectSigners') as Exception),
    ('an unreadable answer', const FormatException('The signer answer has no plain ssh-ed25519 key.')),
  ]) {
    test('Core answering $name clones, signs and pushes nothing', () async {
      core.refusal = answer;
      await expectLater(checkout().open(), throwsA(isA<WorkspaceRefused>()));
      expect(Directory(cache()).existsSync(), isFalse);
      expect(calls.where((call) => call.program == 'git' && _verb(call.arguments) == 'clone'), isEmpty);
    });
  }

  // Harm: a private key or the person's Git configuration takes part in signing, or a secret is recorded.
  test(
    'only public keys and paths reach a process, and every Git call ignores the person\'s Git configuration',
    () async {
      final access = checkout();
      await access.open();
      await change(access);
      await access.commitPushAndBundle(bundle('access'));
      final commits = calls.where((call) => call.program == 'git' && _verb(call.arguments) == 'commit').toList();
      expect(commits, hasLength(1));
      expect(
        commits.single.arguments,
        containsAll(['gpg.format=ssh', 'commit.gpgsign=true', 'user.signingkey=key::${pub('person')}']),
      );
      for (final call in calls) {
        expect(
          call.arguments.where((argument) => argument.contains(keys) || argument.contains('PRIVATE KEY')),
          isEmpty,
        );
        expect(call.input ?? '', isNot(contains('PRIVATE KEY')));
        if (call.program == 'git') {
          expect(call.environment['GIT_CONFIG_GLOBAL'], '/dev/null', reason: call.arguments.join(' '));
          expect(call.environment['GIT_CONFIG_NOSYSTEM'], '1', reason: call.arguments.join(' '));
        }
      }
      for (final entry in Directory('${scratch.path}/access').listSync(recursive: true, followLinks: false)) {
        expect(entry.path, isNot(contains('porelo-signers')), reason: 'no verification scratch is left behind');
        if (entry is File) {
          final text = latin1.decode(entry.readAsBytesSync());
          expect(text, isNot(contains('PRIVATE KEY')), reason: entry.path);
          expect(text, isNot(contains('namespaces=')), reason: '${entry.path} holds no signer list of its own');
        }
      }
    },
  );

  // Harm: a transient clone refusal must not poison every retry with an empty private directory.
  test('a failed initial clone leaves a later bring able to clone', () async {
    failClone = true;
    await expectLater(checkout().open(), throwsA(isA<WorkspaceRefused>()));
    await checkout().open();
  });

  // Harm: failed publication must not leave an unverified commit or dirty settings in the persistent checkout.
  for (final failure in ['commit', 'agent', 'push']) {
    test('a $failure refusal preserves the persistent access checkout and permits retry', () async {
      final access = checkout();
      await access.open();
      final before = await fixture(['rev-parse', 'HEAD'], directory: cache());
      await change(access);
      failCommit = failure == 'commit';
      failPush = failure == 'push';
      if (failure == 'agent') await agent(['-D']);
      await expectLater(access.commitPushAndBundle(bundle('access')), throwsA(isA<WorkspaceRefused>()));
      expect(await fixture(['status', '--porcelain'], directory: cache()), isEmpty);
      expect(await fixture(['rev-parse', 'HEAD'], directory: cache()), before);
      failCommit = failPush = false;
      if (failure == 'agent') await agent(['-q', '$keys/person']);
      final retry = checkout();
      await retry.open();
      await retry.edit((source) => '$source\n# Retried access\n');
      await retry.commitPushAndBundle(bundle('retry'));
      expect(File(bundle('retry')).existsSync(), isTrue);
    });
  }

  // Harm: a later write through a closed checkout lands unverified on the persistent default branch.
  test('a checkout whose publication failed refuses further writes until it is opened again', () async {
    final access = checkout();
    await access.open();
    await change(access);
    failPush = true;
    await expectLater(access.commitPushAndBundle(bundle('access')), throwsA(isA<WorkspaceRefused>()));
    failPush = false;
    final before = await fixture(['rev-parse', 'HEAD'], directory: cache());
    await expectLater(access.edit((source) => '$source\n# Changed access\n'), throwsA(isA<WorkspaceRefused>()));
    await expectLater(access.commitPushAndBundle(bundle('access')), throwsA(isA<WorkspaceRefused>()));
    expect(await fixture(['status', '--porcelain'], directory: cache()), isEmpty);
    expect(await fixture(['rev-parse', 'HEAD'], directory: cache()), before);
  });

  // Harm: fast-forwarding to an origin commit before checking its signature keeps an untrusted commit locally.
  test('an unsigned origin commit is refused without moving the persistent checkout', () async {
    await checkout().open();
    final before = await fixture(['rev-parse', 'HEAD'], directory: cache());
    File('${source.path}/access.yml').writeAsStringSync('developers: {}\n');
    await fixture(['commit', '--no-gpg-sign', '-am', 'Unsigned change']);
    await fixture(['push']);
    await expectLater(checkout().open(), throwsA(isA<WorkspaceRefused>()));
    expect(await fixture(['rev-parse', 'HEAD'], directory: cache()), before);
  });

  // Harm: a first clone of an untrusted tip leaves its files in the persistent checkout and blocks later opens.
  test('a first clone whose tip is unsigned leaves no persistent checkout behind', () async {
    File('${source.path}/access.yml').writeAsStringSync('developers: {}\n');
    await fixture(['commit', '--no-gpg-sign', '-am', 'Unsigned change']);
    await fixture(['push']);
    await expectLater(checkout().open(), throwsA(isA<WorkspaceRefused>()));
    expect(Directory(cache()).existsSync(), isFalse);
  });

  // Harm: a tag named like the origin branch would keep the checkout and its bundle on older access settings.
  test('a tag named like the origin branch does not shadow the published commit', () async {
    await checkout().open();
    await fixture(['tag', 'origin/main']);
    await fixture(['push', 'origin', 'refs/tags/origin/main']);
    final newer = await originCommit('person');
    await checkout().open();
    expect(await fixture(['rev-parse', 'HEAD'], directory: cache()), newer);
  });

  // Harm: retrying an interrupted host upload must not publish the same access update twice.
  test('an identical published access block produces a bundle without another push', () async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final access = checkout();
      await access.open();
      await change(access);
      await access.commitPushAndBundle(bundle('access-$attempt'));
    }
    expect(accessPushes, 1);
  });

  // Harm: a plausible command transcript can hide an unsigned, unpushed, or outdated bundle.
  test('a published access commit is verifiable and the bundle carries exactly that commit', () async {
    final access = checkout();
    await access.open();
    await change(access);
    await access.commitPushAndBundle(bundle('access'));
    final published = await fixture(['rev-parse', 'main'], directory: central);
    final text = await fixture(['show', 'main:access.yml'], directory: central);
    expect(text, contains('# Changed access'));
    expect(loadYaml(text)['developers'], isEmpty);
    expect(text, contains('# People'));
    final restored = '${scratch.path}/restored';
    final heads = await fixture(['bundle', 'list-heads', bundle('access')]);
    expect(heads.split('\n').map((line) => line.split(' ')).toList(), [
      [published, 'refs/heads/main'],
      [published, 'HEAD'],
    ], reason: 'a follow finds the access commit by the default branch or by HEAD');
    await fixture(['clone', '--', bundle('access'), restored]);
    expect(await fixture(['rev-parse', 'HEAD'], directory: restored), published);
    expect(await fixture(['rev-parse', 'main'], directory: restored), published);
    expect((await File(bundle('access')).stat()).mode & 0x1ff, 0x180);
    expect((await gitVerifies('HEAD', directory: restored)).exitCode, 0);
  });

  // Harm: editing a signed symbolic link overwrites a file outside the private checkout.
  test('a linked access file is refused without changing its target', () async {
    final outside = File('${scratch.path}/outside')..writeAsStringSync('preserved');
    File('${source.path}/access.yml').deleteSync();
    Link('${source.path}/access.yml').createSync(outside.path);
    await fixture(['add', 'access.yml']);
    await fixture([
      '-c',
      'gpg.format=ssh',
      '-c',
      'user.signingkey=$keys/person',
      'commit',
      '-S',
      '-m',
      'Linked fixture',
    ]);
    await fixture(['push']);
    await expectLater(checkout().open(), throwsA(isA<WorkspaceRefused>()));
    expect(outside.readAsStringSync(), 'preserved');
  });

  // Harm: publishing from another local branch bundles a stale default branch beside the pushed HEAD.
  test('an access checkout on another branch is preserved rather than published', () async {
    await checkout().open();
    await fixture(['switch', '-c', 'side'], directory: cache());
    await expectLater(checkout().open(), throwsA(isA<WorkspaceRefused>()));
    expect(await fixture(['symbolic-ref', '--short', 'HEAD'], directory: cache()), 'side');
  });
}
