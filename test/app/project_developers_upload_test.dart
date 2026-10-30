// Linux: the reused own-account upload scripts run in Bash and set private file modes.
@Tags(['linux'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/access_developers.dart';
import 'package:porelo_frontend/src/app/project_developers.dart';
import 'package:porelo_host/porelo_host.dart';

import 'project_developers_test.dart' show FixtureAccess, ssh, wg;

class _Host implements Remote {
  _Host(this.home, this.access);

  final Directory home;
  final FixtureAccess access;
  final users = <String>[];
  final hosts = <String>[];
  final uploaded = <String>[];
  int syncs = 0;
  bool refuseCopy = false;
  bool corruptCopy = false;
  Completer<void>? copyStarted;
  Completer<void>? finishCopy;
  Future<void> Function()? afterSync;

  File get installed => File('${home.path}/${HostAct.ownAccount.setupPlace(project: 'demo')}/access.bundle');

  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String)? onLine,
  }) async {
    users.add(user);
    hosts.add(host);
    if (command.contains('/usr/local/sbin/porelo-host-person sync')) {
      syncs++;
      if (!await installed.exists() || await installed.readAsString() != access.bundleContents) {
        return const RemoteResult(1, 'The published access bundle has not arrived.');
      }
      onLine?.call(
        jsonEncode({
          'project': 'demo',
          'commit': 'a' * 40,
          'access_commit': access.publishedCommit,
          'added': <String>[],
          'dropped': <String>[],
          'laptops_added': <String>[],
          'laptops_dropped': <String>[],
          'unchanged': false,
        }),
      );
      await afterSync?.call();
      return const RemoteResult(0, '');
    }
    final process = await Process.start(
      '/bin/bash',
      ['-c', command],
      workingDirectory: home.path,
      environment: {'HOME': home.path, 'PATH': '/usr/bin:/bin', 'LC_ALL': 'C'},
      includeParentEnvironment: false,
    );
    final output = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => onLine?.call(line));
    final error = process.stderr.transform(utf8.decoder).join();
    if (input != null) process.stdin.write(input);
    await process.stdin.close();
    final code = await process.exitCode;
    await output;
    return RemoteResult(code, await error);
  }

  @override
  Future<RemoteResult> copy(String host, String user, String from, String to) async {
    users.add(user);
    hosts.add(host);
    copyStarted?.complete();
    await finishCopy?.future;
    if (refuseCopy) return const RemoteResult(1, 'The bundle upload was refused.');
    final bytes = await File(from).readAsString();
    await File(from).copy(to);
    if (corruptCopy) await File(to).writeAsString('incomplete upload');
    uploaded.add(bytes);
    return const RemoteResult(0, '');
  }
}

void main() {
  late Directory scratch;
  late FixtureAccess access;
  late _Host host;
  late ProjectDevelopers model;
  var disposed = false;
  void disposeModel() {
    disposed = true;
    model.dispose();
  }

  setUp(() async {
    disposed = false;
    scratch = await Directory.systemTemp.createTemp('developer-upload-');
    final checkout = await Directory('${scratch.path}/checkout').create();
    access = FixtureAccess(checkout);
    await File('${checkout.path}/access.yml')
        .writeAsString('host: {network: 10.77.0.0/24, ssh_host_key: "$ssh"}\ndevelopers: {}\n');
    final home = await Directory('${scratch.path}/host home').create();
    host = _Host(home, access);
    final machine = await File('${scratch.path}/machine.yml').writeAsString('keep machine');
    final projectBundle = await File('${scratch.path}/project.bundle').writeAsString('keep project');
    final accessBundle = await File('${scratch.path}/access.bundle').writeAsString('previous bundle');
    expect(
      await HostRun(
        provider: GivenMachine(address: '10.77.0.1', hostKey: ssh),
        remote: host,
        emit: (_) {},
      ).uploadSetupFiles(
        act: HostAct.ownAccount,
        address: '10.77.0.1',
        user: 'admin',
        project: 'demo',
        machineFile: machine.path,
        bundle: projectBundle.path,
        accessBundle: accessBundle.path,
      ),
      isNull,
    );
    host.uploaded.clear();
    model = ProjectDevelopers(
      access: access,
      forge: null,
      repository: 'team/access',
      sync: DeveloperHostSync(remote: host, account: 'admin').call,
    );
  });
  tearDown(() async {
    if (!disposed) disposeModel();
    await scratch.delete(recursive: true);
  });

  // Harm: a sync can apply stale signed access and falsely confirm a developer or laptop removal.
  test('every published access change arrives privately before its host sync', () async {
    final laptops = [
      for (final address in ['10.77.0.2', '10.77.0.3']) AccessLaptop(ssh, wg, address),
    ];
    await model.addDeveloper(AccessDeveloper('developer', null, laptops));
    expect(host.uploaded, [access.bundleContents]);
    expect(model.problem, isNull);
    expect(model.lastSync!.accessCommit, access.publishedCommit);
    access.publishedCommit = 'c' * 40;
    await model.removeLaptop('developer', '10.77.0.3');
    expect(model.problem, isNull);
    expect(model.lastSync!.accessCommit, access.publishedCommit);
    access.publishedCommit = 'd' * 40;
    await model.remove('developer');
    expect(model.problem, isNull);
    expect(model.lastSync!.accessCommit, access.publishedCommit);
    expect(host.uploaded, [
      for (final revision in ['b', 'c', 'd']) 'bundle for ${revision * 40}',
    ]);
    expect(host.syncs, 3);
    expect(host.users, everyElement('admin'));
    expect(host.hosts, everyElement('10.77.0.1'));
    expect((await host.installed.stat()).mode & 0x1ff, 0x180);
    expect(await File('${host.installed.parent.path}/machine.yml').readAsString(), 'keep machine');
    expect(await File('${host.installed.parent.path}/project.bundle').readAsString(), 'keep project');
    expect(await File(access.bundlePath!).exists(), isFalse, reason: 'the temporary bundle is deleted only after use');
  });

  // Harm: a refused upload must not sync stale access or lose the exact published bundle needed by Retry.
  test('a refused upload keeps Retry and repeats upload before syncing', () async {
    host.refuseCopy = true;
    await model.add('developer', '', 'ssh_public_key: "$ssh"\nwireguard_public_key: "$wg"', '10.77.0.2');
    expect(host.syncs, 0);
    expect(model.problem, contains('upload was refused'));
    expect(model.needsRetry, isTrue);
    expect(await File(access.bundlePath!).readAsString(), access.bundleContents);
    expect(await host.installed.readAsString(), 'previous bundle');
    host.refuseCopy = false;
    await model.retry();
    expect(model.problem, isNull);
    expect(model.needsRetry, isFalse);
    expect(host.syncs, 1);
    expect(access.published, 1);
    expect(host.uploaded, [access.bundleContents]);
    expect(await File(access.bundlePath!).exists(), isFalse);
  });

  // Harm: losing a retained bundle must not strand a published access change or sync stale access.
  for (final removeDirectory in [false, true]) {
    test('Retry rebuilds a missing bundle ${removeDirectory ? 'directory' : 'file'} before uploading', () async {
      host.refuseCopy = true;
      await model.add('developer', '', 'ssh_public_key: "$ssh"\nwireguard_public_key: "$wg"', '10.77.0.2');
      final bundle = File(access.bundlePath!);
      if (removeDirectory) {
        await bundle.parent.delete(recursive: true);
      } else {
        await bundle.delete();
      }
      host.refuseCopy = false;
      await model.retry();
      expect(model.problem, isNull);
      expect(model.needsRetry, isFalse);
      expect(model.lastSync!.accessCommit, access.publishedCommit);
      expect(host.uploaded, [access.bundleContents]);
      expect(host.syncs, 1);
      expect(access.published, 1, reason: 'Retry must not publish again');
    });
  }

  // Harm: local cleanup must not erase the host's confirmed application of a published change.
  for (final removeDirectory in [false, true]) {
    test('sync stays confirmed when its bundle ${removeDirectory ? 'directory' : 'file'} disappears', () async {
      host.afterSync = () async {
        final bundle = File(access.bundlePath!);
        if (removeDirectory) {
          await bundle.parent.delete(recursive: true);
        } else {
          await bundle.delete();
        }
      };
      await model.add('developer', '', 'ssh_public_key: "$ssh"\nwireguard_public_key: "$wg"', '10.77.0.2');
      expect(model.problem, isNull);
      expect(model.needsRetry, isFalse);
      expect(model.lastSync!.accessCommit, access.publishedCommit);
      await model.retry();
      expect(host.syncs, 1, reason: 'cleanup must not cause an already confirmed sync to repeat');
    });
  }

  // Harm: a local checkout refusal must not send the person toward SSH repairs or sync stale access.
  test('Retry preserves the checkout refusal when rebuilding the bundle fails', () async {
    access.bundleFails = true;
    await model.add('developer', '', 'ssh_public_key: "$ssh"\nwireguard_public_key: "$wg"', '10.77.0.2');
    await model.retry();
    expect(model.problem, 'The signed access file was published. The local bundle could not be created.');
    expect(model.needsRetry, isTrue);
    expect(host.syncs, 0);
    expect(host.uploaded, isEmpty);
  });

  // Harm: a damaged transfer must not replace the host's access bundle or trigger sync.
  test('a damaged upload preserves the installed bundle until Retry succeeds', () async {
    host.corruptCopy = true;
    await model.add('developer', '', 'ssh_public_key: "$ssh"\nwireguard_public_key: "$wg"', '10.77.0.2');
    expect(model.needsRetry, isTrue);
    expect(host.syncs, 0);
    expect(await host.installed.readAsString(), 'previous bundle');
    expect(await File(access.bundlePath!).exists(), isTrue);
    host.corruptCopy = false;
    await model.retry();
    expect(model.problem, isNull);
    expect(host.syncs, 1);
    expect(await host.installed.readAsString(), access.bundleContents);
  });

  // Harm: following a setup link could replace files outside this project's setup.
  test('a linked access destination is preserved and never synced', () async {
    final elsewhere = await File('${scratch.path}/other.bundle').writeAsString('keep other access');
    await host.installed.delete();
    await Link(host.installed.path).create(elsewhere.path);
    await model.add('developer', '', 'ssh_public_key: "$ssh"\nwireguard_public_key: "$wg"', '10.77.0.2');
    expect(model.needsRetry, isTrue);
    expect(host.syncs, 0);
    expect(await Link(host.installed.path).target(), elsewhere.path);
    expect(await elsewhere.readAsString(), 'keep other access');
  });

  // Harm: closing a failed session must not orphan its private access history in system temp.
  test('disposing a pending upload removes only its retained private bundle', () async {
    host.refuseCopy = true;
    await model.add('developer', '', 'ssh_public_key: "$ssh"\nwireguard_public_key: "$wg"', '10.77.0.2');
    expect(model.needsRetry, isTrue);
    final bundle = File(access.bundlePath!);
    expect(await bundle.exists(), isTrue);
    disposeModel();
    expect(await bundle.parent.exists(), isFalse);
    expect(await host.installed.readAsString(), 'previous bundle');
  });

  // Harm: cleanup of an already removed temporary directory must not crash a closing session.
  test('disposing a pending upload tolerates an already removed bundle directory', () async {
    host.refuseCopy = true;
    await model.add('developer', '', 'ssh_public_key: "$ssh"\nwireguard_public_key: "$wg"', '10.77.0.2');
    await File(access.bundlePath!).parent.delete(recursive: true);
    expect(disposeModel, returnsNormally);
    expect(await host.installed.readAsString(), 'previous bundle');
  });

  // Harm: a late cleanup exception can escape the operation when the session closes during upload.
  test('disposal during upload tolerates a bundle directory removed before finally', () async {
    host.refuseCopy = true;
    host.copyStarted = Completer<void>();
    host.finishCopy = Completer<void>();
    final operation = model.add('developer', '', 'ssh_public_key: "$ssh"\nwireguard_public_key: "$wg"', '10.77.0.2');
    await host.copyStarted!.future;
    disposeModel();
    await File(access.bundlePath!).parent.delete(recursive: true);
    host.finishCopy!.complete();
    await expectLater(operation, completes);
    expect(model.busy, isFalse);
    expect(host.syncs, 0);
  });

  // Harm: disposing during a copy must neither delete its source mid-transfer nor leave it behind afterward.
  test('disposal during an upload waits for the copy before removing its private source', () async {
    host.refuseCopy = true;
    host.copyStarted = Completer<void>();
    host.finishCopy = Completer<void>();
    final operation = model.add('developer', '', 'ssh_public_key: "$ssh"\nwireguard_public_key: "$wg"', '10.77.0.2');
    await host.copyStarted!.future;
    final bundle = File(access.bundlePath!);
    disposeModel();
    expect(await bundle.exists(), isTrue);
    host.finishCopy!.complete();
    await operation;
    expect(await bundle.parent.exists(), isFalse);
    expect(host.syncs, 0);
  });
}
