// Real Git and the private checkout use chmod and the system SSH signing tools.
@Tags(['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/access_checkout.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:yaml/yaml.dart';

import '../support/host_matrix_ca.dart';

void main() {
  late Directory scratch;
  late Directory source;
  late String central;
  late String signer;
  late Map<String, String> isolated;
  var failClone = false;
  var failPush = false;
  var failCommit = false;
  var showSignature = false;
  var accessPushes = 0;

  Future<Ran> git(
    String program,
    List<String> args, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) {
    if (args.first == 'clone' && failClone) {
      failClone = false;
      return Future.value((code: 1, out: '', err: 'clone refused'));
    }
    if (args.first == 'commit' && failCommit) {
      return Future.value((code: 1, out: '', err: 'signer unavailable'));
    }
    if (args.first == 'push' && inDirectory != source.path) {
      accessPushes++;
      if (failPush) return Future.value((code: 1, out: '', err: 'push refused'));
    }
    return runHere(
      program,
      [
        '-c',
        'url.file://${scratch.path}/central.git.insteadOf=https://example.org/team/access.git',
        '-c',
        'commit.gpgsign=true',
        '-c',
        'gpg.format=ssh',
        '-c',
        'user.signingkey=$signer',
        '-c',
        'user.name=Fixture',
        '-c',
        'user.email=fixture@example.invalid',
        '-c',
        'log.showSignature=$showSignature',
        ...args,
      ],
      inDirectory: inDirectory,
      environment: {...environment, ...isolated},
      input: input,
    );
  }

  Future<String> checked(List<String> args, {String? directory}) async {
    final result = await git('git', args, inDirectory: directory ?? source.path);
    expect(result.code, 0, reason: 'fixture Git operation failed: ${result.err}');
    return result.out.trim();
  }

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('access-own-git-');
    source = Directory('${scratch.path}/source')..createSync();
    central = '${scratch.path}/central.git';
    signer = '${scratch.path}/signer';
    isolated = {'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_NOSYSTEM': '1', 'GIT_TERMINAL_PROMPT': '0'};
    failClone = failPush = failCommit = showSignature = false;
    accessPushes = 0;
    for (final key in ['signer', 'other']) {
      final generated = await Process.run('ssh-keygen', [
        '-q',
        '-t',
        'ed25519',
        '-N',
        '',
        '-f',
        '${scratch.path}/$key',
      ]);
      expect(generated.exitCode, 0, reason: 'fixture signing key generation');
    }
    await checked(['init', '--bare', '--initial-branch=main', central]);
    await checked(['init', '--initial-branch=main']);
    File('${source.path}/access.yml').writeAsStringSync('# Keep this private\ndevelopers: {} # People\n');
    await checked(['add', 'access.yml']);
    await checked(['commit', '-S', '-m', 'Private access fixture']);
    await checked(['remote', 'add', 'origin', central]);
    await checked(['push', '-u', 'origin', 'main']);
  });
  tearDown(() => scratch.delete(recursive: true));

  AccessCheckout checkout() => AccessCheckout(
    root: '${scratch.path}/access',
    project: 'demo',
    repository: 'https://example.org/team/access.git',
    signingKey: File('${scratch.path}/signer.pub'),
    run: git,
  );

  // Harm: a transient clone refusal must not poison every retry with an empty private directory.
  test('a failed initial clone leaves a later bring able to clone', () async {
    failClone = true;
    await expectLater(checkout().open(), throwsA(isA<WorkspaceRefused>()));
    await checkout().open();
  });

  // Harm: a person's signature display preference must not reject a valid trusted commit.
  test('signature display in the own Git configuration does not prevent verification', () async {
    showSignature = true;
    await checkout().open();
  });

  // Harm: failed publication must not leave an unverified commit or dirty settings in the persistent checkout.
  for (final failure in ['commit', 'signer', 'push']) {
    test('a $failure refusal preserves the persistent access checkout and permits retry', () async {
      final access = checkout();
      await access.open();
      final cache = '${scratch.path}/access/demo';
      final before = await checked(['rev-parse', 'HEAD'], directory: cache);
      await access.writeHost(PreparedHost.read(matrixHostValues()), hostMatrixCa);
      failCommit = failure == 'commit';
      failPush = failure == 'push';
      if (failure == 'signer') signer = '${scratch.path}/other';
      await expectLater(access.commitPushAndBundle('${scratch.path}/access.bundle'), throwsA(isA<WorkspaceRefused>()));
      expect(await checked(['status', '--porcelain'], directory: cache), isEmpty);
      expect(await checked(['rev-parse', 'HEAD'], directory: cache), before);
      failCommit = failPush = false;
      signer = '${scratch.path}/signer';
      final retry = checkout();
      await retry.open();
      await retry.writeHost(PreparedHost.read(matrixHostValues()), hostMatrixCa);
      await retry.commitPushAndBundle('${scratch.path}/retry.bundle');
      expect(File('${scratch.path}/retry.bundle').existsSync(), isTrue);
    });
  }

  // Harm: a later write through a closed checkout lands unverified on the persistent default branch.
  test('a checkout whose publication failed refuses further writes until it is opened again', () async {
    final access = checkout();
    await access.open();
    await access.writeHost(PreparedHost.read(matrixHostValues()), hostMatrixCa);
    failPush = true;
    await expectLater(access.commitPushAndBundle('${scratch.path}/access.bundle'), throwsA(isA<WorkspaceRefused>()));
    failPush = false;
    final cache = '${scratch.path}/access/demo';
    final before = await checked(['rev-parse', 'HEAD'], directory: cache);
    await expectLater(
      access.writeHost(PreparedHost.read(matrixHostValues()), hostMatrixCa),
      throwsA(isA<WorkspaceRefused>()),
    );
    await expectLater(access.edit((source) => '$source# changed\n'), throwsA(isA<WorkspaceRefused>()));
    await expectLater(access.commitPushAndBundle('${scratch.path}/access.bundle'), throwsA(isA<WorkspaceRefused>()));
    expect(await checked(['status', '--porcelain'], directory: cache), isEmpty);
    expect(await checked(['rev-parse', 'HEAD'], directory: cache), before);
  });

  // Harm: fast-forwarding to an origin commit before checking its signature keeps an untrusted commit locally.
  test('an unsigned origin commit is refused without moving the persistent checkout', () async {
    await checkout().open();
    final cache = '${scratch.path}/access/demo';
    final before = await checked(['rev-parse', 'HEAD'], directory: cache);
    File('${source.path}/access.yml').writeAsStringSync('developers: {}\n');
    await checked(['-c', 'commit.gpgsign=false', 'commit', '--no-gpg-sign', '-am', 'Unsigned change']);
    await checked(['push']);
    await expectLater(checkout().open(), throwsA(isA<WorkspaceRefused>()));
    expect(await checked(['rev-parse', 'HEAD'], directory: cache), before);
  });

  // Harm: a first clone of an untrusted tip leaves its files in the persistent checkout and blocks later opens.
  test('a first clone whose tip is unsigned leaves no persistent checkout behind', () async {
    File('${source.path}/access.yml').writeAsStringSync('developers: {}\n');
    await checked(['-c', 'commit.gpgsign=false', 'commit', '--no-gpg-sign', '-am', 'Unsigned change']);
    await checked(['push']);
    await expectLater(checkout().open(), throwsA(isA<WorkspaceRefused>()));
    expect(Directory('${scratch.path}/access/demo').existsSync(), isFalse);
  });

  // Harm: a tag named like the origin branch would keep the checkout and its bundle on older access settings.
  test('a tag named like the origin branch does not shadow the published commit', () async {
    await checkout().open();
    await checked(['tag', 'origin/main']);
    await checked(['push', 'origin', 'refs/tags/origin/main']);
    File('${source.path}/access.yml').writeAsStringSync('# Keep this private\ndevelopers: {} # Everyone\n');
    await checked(['commit', '-S', '-am', 'Newer signed access']);
    await checked(['push']);
    await checkout().open();
    expect(
      await checked(['rev-parse', 'HEAD'], directory: '${scratch.path}/access/demo'),
      await checked(['rev-parse', 'main'], directory: central),
    );
  });

  // Harm: retrying an interrupted host upload must not publish the same access update twice.
  test('an identical published access block produces a bundle without another push', () async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final access = checkout();
      await access.open();
      await access.writeHost(PreparedHost.read(matrixHostValues()), hostMatrixCa);
      await access.commitPushAndBundle('${scratch.path}/access-$attempt.bundle');
    }
    expect(accessPushes, 1);
  });

  // Harm: a plausible command transcript can hide an unsigned, unpushed, or outdated bundle.
  test('own git publishes a verified access commit and the bundle carries exactly that commit', () async {
    final access = checkout();
    await access.open();
    await access.writeHost(PreparedHost.read(matrixHostValues()), hostMatrixCa);
    final bundle = '${scratch.path}/access.bundle';
    await access.commitPushAndBundle(bundle);
    final published = await checked(['rev-parse', 'main'], directory: central);
    final text = await checked(['show', 'main:access.yml'], directory: central);
    expect(loadYaml(text)['host']['ca_sha256'], hostMatrixCaSha256);
    expect(loadYaml(text)['transports']['matrix']['ca_certificate'], hostMatrixCa);
    expect(text, contains('# People'));
    final restored = '${scratch.path}/restored';
    final heads = await checked(['bundle', 'list-heads', bundle]);
    expect(heads.split('\n').map((line) => line.split(' ')).toList(), [
      [published, 'refs/heads/main'],
      [published, 'HEAD'],
    ], reason: 'a follow finds the access commit by the default branch or by HEAD');
    await checked(['clone', '--', bundle, restored]);
    expect(await checked(['rev-parse', 'HEAD'], directory: restored), published);
    expect(await checked(['rev-parse', 'main'], directory: restored), published);
    expect((await File(bundle).stat()).mode & 0x1ff, 0x180);
    final signature = await checked([
      '-c',
      'gpg.ssh.allowedSignersFile=${access.folder}/.git/porelo-bring-signers',
      'log',
      '-1',
      '--format=%G?%n%GF',
      'HEAD',
    ], directory: restored);
    expect(signature.split('\n'), [
      'G',
      HostFiles.signingFingerprint(File('${scratch.path}/signer.pub').readAsStringSync()),
    ]);
  });

  // Harm: successful signing with another key publishes settings the project's machines cannot trust.
  test('a different configured signer cannot push or produce an access bundle', () async {
    final access = checkout();
    await access.open();
    await access.writeHost(PreparedHost.read(matrixHostValues()), hostMatrixCa);
    final before = await checked(['rev-parse', 'main'], directory: central);
    signer = '${scratch.path}/other';
    await expectLater(access.commitPushAndBundle('${scratch.path}/access.bundle'), throwsA(isA<WorkspaceRefused>()));
    expect(await checked(['rev-parse', 'main'], directory: central), before);
    expect(File('${scratch.path}/access.bundle').existsSync(), isFalse);
  });

  // Harm: editing a signed symbolic link overwrites a file outside the private checkout.
  test('a linked access file is refused without changing its target', () async {
    final outside = File('${scratch.path}/outside')..writeAsStringSync('preserved');
    File('${source.path}/access.yml').deleteSync();
    Link('${source.path}/access.yml').createSync(outside.path);
    await checked(['add', 'access.yml']);
    await checked(['commit', '-S', '-m', 'Linked fixture']);
    await checked(['push']);
    await expectLater(checkout().open(), throwsA(isA<WorkspaceRefused>()));
    expect(outside.readAsStringSync(), 'preserved');
  });

  // Harm: publishing from another local branch bundles a stale default branch beside the pushed HEAD.
  test('an access checkout on another branch is preserved rather than published', () async {
    final access = checkout();
    await access.open();
    final cache = '${scratch.path}/access/demo';
    await checked(['switch', '-c', 'side'], directory: cache);
    await expectLater(checkout().open(), throwsA(isA<WorkspaceRefused>()));
    expect(await checked(['symbolic-ref', '--short', 'HEAD'], directory: cache), 'side');
  });
}
