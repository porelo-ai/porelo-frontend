import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/project_bring.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_host/porelo_host.dart';

import '../support/host_admin.dart';
import '../support/host_matrix_ca.dart';
import '../features/support/world.dart';

class _Following extends FakeBackend {
  _Following(this.project) : super(const []);
  final String project;
  @override
  Future<List<Followed>> following() async => [
    Followed(name: project, url: 'https://example.org/project.git', commit: 'a' * 40),
  ];
}

class _Source extends HostFiles {
  _Source() : super(MemorySecrets());
  var requests = 0;
  @override
  Future<({List<int> bytes, String projectYaml})> createProjectSetup({
    required String project,
    required String url,
    required String commit,
    required File signingKey,
  }) async {
    requests++;
    throw const WorkspaceRefused('source boundary reached');
  }
}

void main() {
  // Harm: unsafe project identifiers must stop before source construction, private Git, or host operations.
  for (final name in ['a..b', 'trailing.', 'a' * 65]) {
    test('invalid project $name is refused before constructing or publishing its setup', () async {
      final scratch = Directory.systemTemp.createTempSync('bring-preflight-');
      addTearDown(() => scratch.deleteSync(recursive: true));
      final public = File('${scratch.path}/signer.pub')..writeAsStringSync(hostValues()['ssh_host_key']! as String);
      File('${scratch.path}/identity').writeAsStringSync('identity fixture');
      final files = _Source();
      final bring = ProjectBring(
        project: name,
        backend: _Following(name),
        targetBackend: _Following(name),
        machine: Machine(
          name: 'own account',
          socketPath: '',
          kind: 'host',
          host: 'admin@10.73.7.1',
          identity: '${scratch.path}/identity',
        ),
        host: PreparedHost.read(matrixHostValues()),
        knownHosts: '${scratch.path}/known_hosts.orchard',
        secretsFile: '${scratch.path}/secrets.kdbx',
        signingKey: public,
        accessRoot: '${scratch.path}/access',
        remote: HelperRemote(),
        files: files,
        forgeCa: hostMatrixCa,
      );
      addTearDown(bring.dispose);
      await bring.bring();
      expect(files.requests, 0);
      expect(Directory('${scratch.path}/access').existsSync(), isFalse);
    });
  }

  // Harm: an unrelated preflight refusal must not make the unsafe-name guards pass without reaching source validation.
  test('a valid project with complete inputs reaches the signed source boundary', () async {
    final scratch = Directory.systemTemp.createTempSync('bring-valid-preflight-');
    addTearDown(() => scratch.deleteSync(recursive: true));
    final public = File('${scratch.path}/signer.pub')..writeAsStringSync(hostValues()['ssh_host_key']! as String);
    File('${scratch.path}/identity').writeAsStringSync('identity fixture');
    final files = _Source();
    final bring = ProjectBring(
      project: 'demo',
      backend: _Following('demo'),
      targetBackend: _Following('demo'),
      machine: Machine(
        name: 'own account',
        socketPath: '',
        host: 'admin@10.73.7.1',
        identity: '${scratch.path}/identity',
      ),
      host: PreparedHost.read(matrixHostValues()),
      knownHosts: '${scratch.path}/known_hosts.orchard',
      secretsFile: '${scratch.path}/secrets.kdbx',
      signingKey: public,
      accessRoot: '${scratch.path}/access',
      remote: HelperRemote(),
      files: files,
      forgeCa: hostMatrixCa,
    );
    addTearDown(bring.dispose);
    await bring.bring();
    expect(files.requests, 1);
    expect(bring.problem, 'source boundary reached');
  });
}
