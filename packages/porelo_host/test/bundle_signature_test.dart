import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

import 'host_files_test.dart' show MemorySecrets;

const _gitEnvironment = {'GIT_TERMINAL_PROMPT': '0', 'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_NOSYSTEM': '1'};

Future<String> _run(String executable, List<String> arguments, Directory directory) async {
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: directory.path,
    environment: _gitEnvironment,
  );
  expect(result.exitCode, 0, reason: '$executable $arguments: ${result.stderr}');
  return '${result.stdout}'.trim();
}

void main() {
  late Directory scratch;
  late Directory source;
  late File signer;
  late File other;
  late HostFiles files;

  Future<File> key(String name) async {
    final private = path.join(scratch.path, name);
    await _run('ssh-keygen', ['-q', '-t', 'ed25519', '-N', '', '-C', name, '-f', private], scratch);
    return File('$private.pub');
  }

  Future<String> commit(String message, {File? signedWith}) async {
    await File(path.join(source.path, 'project.yml')).writeAsString('name: $message\n');
    await _run('git', ['add', 'project.yml'], source);
    await _run('git', [
      if (signedWith != null) ...[
        '-c',
        'gpg.format=ssh',
        '-c',
        'user.signingkey=${path.withoutExtension(signedWith.path)}',
      ],
      'commit',
      if (signedWith != null) '-S' else '--no-gpg-sign',
      '-m',
      message,
    ], source);
    return _run('git', ['rev-parse', 'HEAD'], source);
  }

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('bundle-signature-');
    source = await Directory(path.join(scratch.path, 'source')).create();
    await _run('git', ['init', '--initial-branch=main'], source);
    await _run('git', ['config', 'user.email', 'fixture@example.invalid'], source);
    await _run('git', ['config', 'user.name', 'Fixture'], source);
    signer = await key('signer');
    other = await key('other');
    files = HostFiles(MemorySecrets(), gitEnvironment: _gitEnvironment);
  });
  tearDown(() => scratch.delete(recursive: true));

  Future<List<int>> bundle(String commit, File signingKey) =>
      files.createBundle(project: 'demo', url: source.path, commit: commit, signingKey: signingKey);

  Future<String> fingerprint(File key) async => HostFiles.signingFingerprint(await key.readAsString());

  test('the key that signed the commit puts it on the drive', () async {
    final signed = await commit('signed', signedWith: signer);
    expect(await bundle(signed, signer), isNotEmpty);
  });

  // Harm: the host refuses machine.yml only after a server is rented and set up for about 20 minutes.
  test('a key that did not sign the commit is refused, naming both fingerprints', () async {
    final signed = await commit('signed', signedWith: signer);
    await expectLater(
      bundle(signed, other),
      throwsA(
        isA<HostFilesRefused>().having(
          (refusal) => refusal.message,
          'message',
          allOf(contains('signed by ${await fingerprint(signer)}'), contains('not by ${await fingerprint(other)}')),
        ),
      ),
    );
  });

  // Harm: an unsigned commit pinned to any key rents a server the host then refuses.
  test('an unsigned commit is refused', () async {
    final unsigned = await commit('unsigned');
    await expectLater(
      bundle(unsigned, signer),
      throwsA(isA<HostFilesRefused>().having((refusal) => refusal.message, 'message', contains('not signed'))),
    );
  });
}
