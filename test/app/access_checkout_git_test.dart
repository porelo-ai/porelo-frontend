import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/access_checkout.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:yaml/yaml.dart';

import '../support/host_admin.dart';

void main() {
  late Directory scratch;
  late Directory source;
  late String central;
  late String signer;
  late Map<String, String> isolated;

  Future<Ran> git(
    String program,
    List<String> args, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) => runHere(
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
      ...args,
    ],
    inDirectory: inDirectory,
    environment: {...environment, ...isolated},
    input: input,
  );

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

  // Harm: a plausible command transcript can hide an unsigned, unpushed, or outdated bundle.
  test('own git publishes a verified access commit and the bundle carries exactly that commit', () async {
    final access = checkout();
    await access.open();
    await access.writeHost(PreparedHost.read(hostValues()), '#demo:matrix.orchard.porelo.internal');
    final bundle = '${scratch.path}/access.bundle';
    await access.commitPushAndBundle(bundle);
    final published = await checked(['rev-parse', 'main'], directory: central);
    final text = await checked(['show', 'main:access.yml'], directory: central);
    expect(loadYaml(text)['host']['ca_sha256'], hostValues()['ca_sha256']);
    expect(text, contains('# People'));
    final restored = '${scratch.path}/restored';
    await checked(['clone', '--', bundle, restored]);
    expect(await checked(['rev-parse', 'HEAD'], directory: restored), published);
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
    await access.writeHost(PreparedHost.read(hostValues()), '#demo:matrix.orchard.porelo.internal');
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
    await checked(['switch', '-c', 'side'], directory: access.folder);
    await expectLater(checkout().open(), throwsA(isA<WorkspaceRefused>()));
    expect(await checked(['symbolic-ref', '--short', 'HEAD'], directory: access.folder), 'side');
  });
}
