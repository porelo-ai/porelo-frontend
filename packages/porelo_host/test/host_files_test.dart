// Linux only: private bundle publication invokes chmod and checks symbolic links.
@Tags(['linux'])
library;

import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

const signingKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAABAgMEBQYHCAkKCwwNDg8QERITFBUWFxgZGhscHR4f fixture';
const fingerprint = 'SHA256:ZkAslGjFiUHdGf/WUL8rQvkib4PTvQatUV0OUQSncCA';
void main() {
  late Directory scratch;
  late HostFiles files;
  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('host-files-');
    files = HostFiles();
  });
  tearDown(() => scratch.delete(recursive: true));
  // Harm: trusting a different signing key lets the host accept the wrong commits.
  test('signing fingerprint matches the fixed ssh-keygen output', () {
    expect(HostFiles.signingFingerprint(signingKey), fingerprint);
    expect(() => HostFiles.signingFingerprint('ssh-ed25519 malformed'), throwsA(isA<HostFilesRefused>()));
  });
  // Harm: a path-like project can escape its private bundle directory.
  test('own-account setup and publication refuse unsafe project names', () async {
    for (final project in ['', '.', '..', '../other', '/other', 'demo/other', 'demo\x00other']) {
      expect(() => HostAct.ownAccount.setupPlace(project: project), throwsA(isA<HostFilesRefused>()));
      await expectLater(
        files.publishBundle(
          project: project,
          folder: scratch.path,
          bytes: [1],
          ownFolder: true,
          act: HostAct.ownAccount,
        ),
        throwsA(isA<HostFilesRefused>()),
      );
    }
  });
  // Harm: publishing through a link writes a verified bundle outside its selected private tree.
  test('a linked host directory cannot redirect bundle publication', () async {
    final outside = await Directory('${scratch.path}/outside').create();
    await Directory('${scratch.path}/conf').create();
    await Link('${scratch.path}/conf/hosts').create(outside.path);
    await expectLater(
      files.publishBundle(
        project: 'demo',
        folder: '${scratch.path}/conf/hosts/demo',
        bytes: [1, 2, 3],
        ownFolder: true,
      ),
      throwsA(isA<HostFilesRefused>()),
    );
    expect(outside.listSync(recursive: true), isEmpty);
  });
  // Harm: an incomplete or public bundle can expose private project configuration.
  test('bundle publication leaves complete owner-only bytes', () async {
    await files.publishBundle(project: 'demo', folder: scratch.path, bytes: [1, 2, 3], ownFolder: true);
    final bundle = File('${scratch.path}/porelo-host/demo.bundle');
    expect(await bundle.readAsBytes(), [1, 2, 3]);
    expect((await bundle.stat()).mode & 0x1ff, 0x180);
  });
}
