// Real Git against a local bare repository, and the private checkout uses chmod.
@Tags(['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/registry_checkout.dart';
import 'package:porelo_frontend/src/app/run_here.dart';

void main() {
  const address = 'https://example.org/team/registry.git';
  late Directory scratch;
  late String central;
  late String author;
  var failFetch = false;
  final environments = <Map<String, String>>[];

  Future<Ran> git(
    String program,
    List<String> args, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) {
    environments.add(environment);
    if (failFetch && (args.first == 'fetch' || args.first == 'clone')) {
      return Future.value((code: 128, out: '', err: 'fatal: Authentication failed for $address token=hidden-v4lue'));
    }
    return runHere(
      program,
      ['-c', 'url.file://$central.insteadOf=$address', ...args],
      inDirectory: inDirectory,
      environment: {'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_NOSYSTEM': '1', ...environment},
      input: input,
    );
  }

  Future<void> run(List<String> args, String inDirectory) async {
    final result = await Process.run(
      'git',
      args,
      workingDirectory: inDirectory,
      environment: {'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_NOSYSTEM': '1'},
    );
    if (result.exitCode != 0) fail('git ${args.join(' ')}: ${result.stderr}');
  }

  Future<void> commitCentral(String file, String text) async {
    File('$author/$file')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(text);
    await run(['add', file], author);
    await run(['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', file], author);
    await run(['push', '-q', 'origin', 'HEAD:main'], author);
  }

  Future<String> commitCheckout(String folder, String name) async {
    File('$folder/$name').writeAsStringSync('$name\n');
    await run(['add', name], folder);
    await run(['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', name], folder);
    final revision = await Process.run(
      'git',
      ['rev-parse', 'HEAD'],
      workingDirectory: folder,
      environment: {'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_NOSYSTEM': '1'},
    );
    expect(revision.exitCode, 0);
    return (revision.stdout as String).trim();
  }

  Future<String> centralRevision() async {
    final revision = await Process.run(
      'git',
      ['--git-dir=$central', 'rev-parse', 'HEAD'],
      environment: {'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_NOSYSTEM': '1'},
    );
    expect(revision.exitCode, 0);
    return (revision.stdout as String).trim();
  }

  RegistryCheckout checkout([String repository = address]) =>
      RegistryCheckout(root: '${scratch.path}/private', repository: repository, run: git);

  setUp(() async {
    failFetch = false;
    environments.clear();
    scratch = await Directory.systemTemp.createTemp('registry-checkout');
    central = '${scratch.path}/central.git';
    author = '${scratch.path}/author';
    await run(['init', '-q', '--bare', '-b', 'main', central], scratch.path);
    await run(['clone', '-q', central, author], scratch.path);
    await commitCentral('owners.yml', 'owners: [alice]\n');
  });

  tearDown(() => scratch.delete(recursive: true));

  // Harm: the registry is fetched with a credential the interface asked for, or Git stops to prompt for one.
  test('a first fetch clones privately and Git never prompts', () async {
    final registry = checkout();

    final revision = await registry.fetch();

    expect(revision, matches(RegExp(r'^[0-9a-f]{40}$')));
    expect(File('${registry.folder}/owners.yml').readAsStringSync(), 'owners: [alice]\n');
    expect((await Directory('${scratch.path}/private').stat()).mode & 0x3f, 0, reason: 'nobody else reads it');
    for (final environment in environments) {
      expect(environment, containsPair('GIT_TERMINAL_PROMPT', '0'));
      expect(environment, containsPair('GIT_ASKPASS', ''), reason: 'an inherited askpass must never prompt');
      expect(environment, containsPair('SSH_ASKPASS', ''));
      expect(environment, containsPair('GCM_INTERACTIVE', 'never'));
      expect(environment['GIT_SSH_COMMAND'], Platform.environment['GIT_SSH_COMMAND'] ?? 'ssh -o BatchMode=yes');
    }
  });

  // Harm: inherited or configured askpass runs a credential UI despite terminal prompting being disabled.
  test('credential lookup cannot invoke inherited or configured askpass', () async {
    final marker = File('${scratch.path}/asked');
    final askpass = File('${scratch.path}/askpass')
      ..writeAsStringSync("#!/bin/sh\nprintf asked > '${marker.path}'\nexit 1\n");
    final mode = await Process.run('chmod', ['700', askpass.path]);
    expect(mode.exitCode, 0);
    var lookups = 0;
    final registry = RegistryCheckout(
      root: '${scratch.path}/private',
      repository: address,
      run: (program, args, {inDirectory, environment = const {}, input}) async {
        lookups++;
        return runHere(
          'git',
          ['-c', 'credential.helper=', '-c', 'core.askPass=${askpass.path}', 'credential', 'fill'],
          environment: {
            'GIT_CONFIG_GLOBAL': '/dev/null',
            'GIT_CONFIG_NOSYSTEM': '1',
            'GIT_ASKPASS': askpass.path,
            'SSH_ASKPASS': askpass.path,
            ...environment,
          },
          input: 'protocol=https\nhost=example.org\n\n',
        );
      },
    );
    await expectLater(registry.fetch(), throwsA(isA<WorkspaceRefused>()));
    expect(lookups, 1, reason: 'the credential lookup must actually have run');
    expect(marker.existsSync(), isFalse, reason: 'no askpass program may be invoked');
  });

  test('a later fetch moves the checkout to the new commit', () async {
    final registry = checkout();
    final first = await registry.fetch();
    await commitCentral('people/bob.card', 'login: bob\n');

    final second = await registry.fetch();

    expect(second, isNot(first));
    expect(File('${registry.folder}/people/bob.card').existsSync(), isTrue);
  });

  // Harm: a refused fetch wipes what was read, or Git's words carry a credential into the interface.
  test('a refused fetch keeps the checkout and says nothing of Git\'s output', () async {
    final registry = checkout();
    await registry.fetch();
    await commitCentral('people/bob.card', 'login: bob\n');
    failFetch = true;

    final refusal = await registry.fetch().then<Object?>((_) => null, onError: (Object e) => e);

    expect(refusal, isA<WorkspaceRefused>());
    expect('$refusal', isNot(contains('hidden-v4lue')));
    expect(File('${registry.folder}/owners.yml').existsSync(), isTrue);
    expect(File('${registry.folder}/people/bob.card').existsSync(), isFalse);
  });

  test('a refused first clone leaves nothing behind', () async {
    final registry = checkout();
    failFetch = true;

    await expectLater(registry.fetch(), throwsA(isA<WorkspaceRefused>()));

    expect(Directory(registry.folder).existsSync(), isFalse);
  });

  // Harm: a fetch overwrites a change the person made in the checkout by hand.
  test('a checkout with a change of its own is refused, never reset', () async {
    final registry = checkout();
    await registry.fetch();
    File('${registry.folder}/owners.yml').writeAsStringSync('owners: [mallory]\n');

    await expectLater(registry.fetch(), throwsA(isA<WorkspaceRefused>()));

    expect(File('${registry.folder}/owners.yml').readAsStringSync(), 'owners: [mallory]\n');
  });

  // Harm: dirty or unpublished work gets pushed without the person's review.
  for (final committed in [false, true]) {
    test('publishing refuses pre-existing work, committed=$committed', () async {
      final registry = checkout();
      await registry.fetch();
      File('${registry.folder}/owners.yml').writeAsStringSync('owners: [mallory]\n');
      if (committed) {
        await run(['add', 'owners.yml'], registry.folder);
        await run([
          '-c',
          'user.name=Fixture',
          '-c',
          'user.email=fixture@example.invalid',
          'commit',
          '-qm',
          'local',
        ], registry.folder);
      }
      await expectLater(registry.prepareFiling(), throwsA(isA<WorkspaceRefused>()));
      final centralText = await Process.run(
        'git',
        ['--git-dir=$central', 'show', 'main:owners.yml'],
        environment: {'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_NOSYSTEM': '1'},
      );
      expect(centralText.exitCode, 0);
      expect(centralText.stdout, 'owners: [alice]\n', reason: 'no unreviewed work may leave the checkout');
    });
  }

  // Harm: publication sends a different commit than the one Core filed or includes unrelated work.
  test("publication sends exactly Core's one commit above the checked base", () async {
    final registry = checkout();
    final base = await registry.fetch();
    await registry.prepareFiling();
    final filed = await commitCheckout(registry.folder, 'person.card');
    expect(await centralRevision(), base);
    await registry.publish(filed);
    expect(await centralRevision(), filed);
  });

  for (final interference in ['dirty file', 'extra commit', 'different HEAD']) {
    test('publication refuses $interference after the checkout was checked', () async {
      final registry = checkout();
      final base = await registry.fetch();
      await registry.prepareFiling();
      if (interference == 'extra commit') await commitCheckout(registry.folder, 'unreviewed.card');
      final filed = await commitCheckout(registry.folder, 'person.card');
      if (interference == 'dirty file') File('${registry.folder}/unreviewed.card').writeAsStringSync('unreviewed');
      if (interference == 'different HEAD') await commitCheckout(registry.folder, 'unreviewed.card');
      await expectLater(registry.publish(filed), throwsA(isA<WorkspaceRefused>()));
      expect(await centralRevision(), base, reason: 'unreviewed work must never reach the central repository');
    });
  }

  // Harm: a successful empty clone leaves an unusable folder and permanently prevents recovery.
  test('a failed post-clone check removes only its fresh checkout so a later fetch can recover', () async {
    await run(['update-ref', '-d', 'refs/heads/main'], central);
    final registry = checkout();
    await expectLater(registry.fetch(), throwsA(isA<WorkspaceRefused>()));
    expect(Directory(registry.folder).existsSync(), isFalse, reason: 'a fresh incomplete clone must not block a retry');
    await run(['push', '-q', 'origin', 'HEAD:main'], author);
    expect(await registry.fetch(), matches(RegExp(r'^[0-9a-f]{40}$')));
    expect(File('${registry.folder}/owners.yml').readAsStringSync(), 'owners: [alice]\n');
  });

  // Harm: a pasted address with a token is kept or echoed back.
  test('an address with credentials is refused without repeating it', () async {
    final refusal = await checkout('https://bob:s3cret@example.org/team/registry.git')
        .fetch()
        .then<Object?>((_) => null, onError: (Object e) => e);

    expect(refusal, isA<WorkspaceRefused>());
    expect('$refusal', isNot(contains('s3cret')));
    expect(Directory('${scratch.path}/private').existsSync(), isFalse);
  });

  test('another address gets a checkout of its own', () {
    expect(checkout().folder, isNot(checkout('git@example.org:team/registry.git').folder));
  });

  test('publishing before a fetch is refused', () async {
    await expectLater(checkout().publish('1' * 40), throwsA(isA<WorkspaceRefused>()));
  });
}
