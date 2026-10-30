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
      environment: environment,
      input: input,
    );
  }

  Future<void> run(List<String> args, String inDirectory) async {
    final result = await Process.run('git', args, workingDirectory: inDirectory);
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
    expect(environments, everyElement(containsPair('GIT_TERMINAL_PROMPT', '0')));
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
    await expectLater(checkout().publish(), throwsA(isA<WorkspaceRefused>()));
  });
}
