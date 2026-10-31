// Real Git against a local bare repository, and the private checkout uses chmod.
@Tags(['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
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
    final verb = args.firstWhere((arg) => !arg.startsWith('-') && !arg.contains('='), orElse: () => '');
    if (failFetch && (verb == 'fetch' || verb == 'clone')) {
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

  // Harm: a commit Core made earlier pushed again after a restart with unrelated work, or on another base.
  for (final interference in ['none', 'extra commit', 'different HEAD', 'other base']) {
    test('pushing a made commit again sends only it on its base, interference: $interference', () async {
      final first = checkout();
      final base = await first.fetch();
      await first.prepareFiling();
      if (interference == 'extra commit') await commitCheckout(first.folder, 'unreviewed.card');
      final made = await commitCheckout(first.folder, 'owners-change.yml');
      if (interference == 'different HEAD') await commitCheckout(first.folder, 'unreviewed.card');
      final again = checkout();
      final pushed = again.publishMade(made, base: interference == 'other base' ? made : base);
      if (interference == 'none') {
        await pushed;
        expect(await centralRevision(), made);
      } else {
        await expectLater(pushed, throwsA(isA<WorkspaceRefused>()));
        expect(await centralRevision(), base, reason: 'unreviewed work must never reach the central repository');
      }
    });
  }

  // Harm: a request's own commit that reached the registry already (its push went through before a crash or a lost
  // answer, or was made by hand) refused for good, so the hosts are never told; or a published branch that moved on
  // without it taken as holding it.
  for (final after in ['nothing', 'a fetch', 'a later commit', 'another commit instead']) {
    test('a made commit the registry holds already is taken as pushed, after $after', () async {
      final first = checkout();
      final base = await first.fetch();
      await first.prepareFiling();
      final made = await commitCheckout(first.folder, 'owners-change.yml');
      if (after != 'another commit instead') await run(['push', '-q', central, '$made:refs/heads/main'], first.folder);
      if (after == 'a fetch') await first.fetch();
      if (after == 'a later commit') {
        await run(['pull', '-q', '--ff-only', 'origin', 'main'], author);
        await commitCentral('later.yml', 'later\n');
        await first.fetch();
      }
      if (after == 'another commit instead') await commitCentral('other.yml', 'other\n');
      final tip = await centralRevision();

      final publishing = checkout().publishMade(made, base: base);

      if (after == 'another commit instead') {
        await expectLater(publishing, throwsA(isA<WorkspaceRefused>()));
      } else {
        await publishing;
      }
      expect(await centralRevision(), tip, reason: 'nothing is pushed anew');
    });
  }

  // Harm: a commit that is not the request's own taken as pushed, so the hosts are told of a replacement the registry
  // never got: the base itself, a commit before it, one Core never reads as merged in beside the first-parent line, or
  // one with a commit of the checkout above it that the next push would take along.
  for (final named in ['the base', 'a commit before the base', 'a merged side commit', 'one with a commit above it']) {
    test('a made commit is never taken as pushed when it is $named', () async {
      final first = checkout();
      final start = await first.fetch();
      if (named == 'a commit before the base') {
        await run(['pull', '-q', '--ff-only', 'origin', 'main'], author);
        await commitCentral('next.yml', 'next\n');
        final base = await first.fetch();
        final publishing = checkout().publishMade(start, base: base);
        await expectLater(publishing, throwsA(isA<WorkspaceRefused>()));
        return;
      }
      if (named == 'the base') {
        await expectLater(checkout().publishMade(start, base: start), throwsA(isA<WorkspaceRefused>()));
        return;
      }
      await first.prepareFiling();
      final made = await commitCheckout(first.folder, 'owners-change.yml');
      if (named == 'a merged side commit') {
        await run(['pull', '-q', '--ff-only', 'origin', 'main'], author);
        await commitCentral('beside.yml', 'beside\n');
        await run(['fetch', '-q', first.folder, made], author);
        await run([
          '-c',
          'user.name=Fixture',
          '-c',
          'user.email=fixture@example.invalid',
          'merge',
          '-q',
          '--no-ff',
          '-m',
          'merge',
          'FETCH_HEAD',
        ], author);
        await run(['push', '-q', 'origin', 'HEAD:main'], author);
      } else {
        await run(['push', '-q', central, '$made:refs/heads/main'], first.folder);
        await commitCheckout(first.folder, 'unreviewed.card');
      }
      final tip = await centralRevision();

      await expectLater(checkout().publishMade(made, base: start), throwsA(isA<WorkspaceRefused>()));
      expect(await centralRevision(), tip, reason: 'nothing is pushed anew');
    });
  }

  // Harm: a filing whose answer was lost never retried under its request, because the checkout refuses the commit that
  // request made; or a retry passing anyone else's unpublished work, or a fresh filing passing that commit.
  for (final held in ['nothing', 'its own commit', 'other content', 'another file too', 'a commit before it', 'two']) {
    test('a retry accepts only the commit its own request made, holding $held', () async {
      final first = checkout();
      final base = await first.fetch();
      const content = 'owners: [alice, bob]\n';
      Future<void> commit(Map<String, String> files) async {
        for (final MapEntry(:key, :value) in files.entries) {
          File(path.join(first.folder, key)).writeAsStringSync(value);
          await run(['add', key], first.folder);
        }
        await run([
          '-c',
          'user.name=Core',
          '-c',
          'user.email=core@example.invalid',
          'commit',
          '-qm',
          'filed',
        ], first.folder);
      }

      if (held == 'a commit before it') await commit({'unreviewed.card': 'x\n'});
      if (held != 'nothing') {
        await commit({
          'owners.yml': held == 'other content' ? 'owners: [mallory]\n' : content,
          if (held == 'another file too') 'unreviewed.card': 'x\n',
        });
      }
      if (held == 'two') await commit({'unreviewed.card': 'x\n'});
      // As after a restart: nothing fetched in this run.
      final retry = checkout().prepareRetry(base: base, file: 'owners.yml', content: content);

      if (held == 'nothing' || held == 'its own commit') {
        await retry;
      } else {
        await expectLater(retry, throwsA(isA<WorkspaceRefused>()));
      }
      if (held != 'nothing') {
        await expectLater(
          first.prepareFiling(),
          throwsA(isA<WorkspaceRefused>()),
          reason: 'a fresh filing passes none',
        );
      }
      expect(await centralRevision(), base);
    });
  }

  // Harm: a retry handing Core a commit that is not its request's own, on a base the repository does not hold, under
  // another name that trims to the file, or as a link or program whose text is the file's: Core's answer then stands
  // for a change nobody reviewed, or pushes an unreviewed commit beside it.
  for (final held in ['on an unpublished base', 'a name with a trailing space', 'a link', 'a program']) {
    test('a retry refuses a commit that only looks like its own, $held', () async {
      final first = checkout();
      var base = await first.fetch();
      // The name with a trailing space leaves owners.yml as it is, so its text is the content asked for.
      final content = held == 'a name with a trailing space' ? 'owners: [alice]\n' : 'owners: [alice, bob]\n';
      Future<String> commit(String message) async {
        await run([
          '-c',
          'user.name=Core',
          '-c',
          'user.email=core@example.invalid',
          'commit',
          '-qm',
          message,
        ], first.folder);
        final head = await Process.run(
          'git',
          ['rev-parse', 'HEAD'],
          workingDirectory: first.folder,
          environment: {'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_NOSYSTEM': '1'},
        );
        return (head.stdout as String).trim();
      }

      final owners = File(path.join(first.folder, 'owners.yml'));
      switch (held) {
        case 'on an unpublished base':
          File(path.join(first.folder, 'unreviewed.card')).writeAsStringSync('x\n');
          await run(['add', 'unreviewed.card'], first.folder);
          base = await commit('unreviewed');
          owners.writeAsStringSync(content);
        case 'a name with a trailing space':
          File(path.join(first.folder, 'owners.yml ')).writeAsStringSync('owners: [mallory]\n');
        case 'a link':
          owners.deleteSync();
          Link(owners.path).createSync(content);
        case 'a program':
          owners.writeAsStringSync(content);
          expect((await Process.run('chmod', ['755', owners.path])).exitCode, 0);
      }
      await run(['add', '-A'], first.folder);
      await commit('filed');

      await expectLater(
        checkout().prepareRetry(base: base, file: 'owners.yml', content: content),
        throwsA(isA<WorkspaceRefused>()),
      );
    });
  }

  // Harm: a made commit pushed on a base the repository does not hold, which pushes that unreviewed base with it.
  test('pushing a made commit again refuses a base the repository does not hold', () async {
    final first = checkout();
    final published = await first.fetch();
    final base = await commitCheckout(first.folder, 'unreviewed.card');
    final made = await commitCheckout(first.folder, 'owners-change.yml');

    await expectLater(checkout().publishMade(made, base: base), throwsA(isA<WorkspaceRefused>()));
    expect(await centralRevision(), published, reason: 'unreviewed work must never reach the central repository');
  });

  // Harm: on a computer whose Git turns line ends, the checkout holds other bytes than the repository, so the file a
  // replacement is made from never matches the commit its own request made, and its retry is refused for good.
  test('the checkout holds the bytes the repository holds, whatever Git is told about line ends', () async {
    final registry = checkout();
    await registry.fetch();
    await run(['config', 'core.autocrlf', 'true'], registry.folder);
    await commitCentral('owners.yml', 'owners:\n  - alice\n');

    await registry.fetch();

    expect(File(path.join(registry.folder, 'owners.yml')).readAsBytesSync(), 'owners:\n  - alice\n'.codeUnits);
  });

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
