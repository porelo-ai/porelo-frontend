import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

import 'host_run_test.dart' show CountingProvider, ScriptedRemote;

void main() {
  const original = [1, 2, 3];
  final expected = sha256.convert(original).toString();
  late Directory folder;
  late File file;
  late CountingProvider provider;
  late ScriptedRemote remote;
  late List<Step> steps;
  late HostRun run;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('collection-');
    file = File(path.join(folder.path, hostCollection.fileName));
    provider = CountingProvider();
    remote = ScriptedRemote([]);
    steps = [];
    run = HostRun(
      environment: {'XDG_STATE_HOME': folder.path, 'LOCALAPPDATA': folder.path},
      provider: provider,
      remote: remote,
      emit: steps.add,
      resolvedExecutable: path.join(folder.path, 'porelo-host'),
      collectionRelease: (version: hostCollection.version, fileName: hostCollection.fileName, sha256: expected),
    );
  });
  tearDown(() => folder.delete(recursive: true));

  // Harm: a host is rented without the setup collection that the package must carry.
  test('up without an override copies the collection beside its executable', () async {
    await file.writeAsBytes(original);
    expect(
      await run.up(const HostPlan(project: 'demo', account: 'porelo', publicKey: 'ssh-ed25519 BBBB me')),
      Exit.done,
    );
    expect(remote.commands, contains('copy ${file.path} /var/tmp/porelo-host/collection.tar.gz'));
    expect(remote.inputs, contains('$expected  /var/tmp/porelo-host/collection.tar.gz\n'));
  });

  // Harm: a rented host keeps billing even though its missing collection prevents setup.
  test('a missing carried collection is refused with its path before rent', () async {
    expect(
      await run.up(const HostPlan(project: 'demo', account: 'porelo', publicKey: 'ssh-ed25519 BBBB me')),
      Exit.refused,
    );
    expect(provider.created, 0);
    expect(remote.commands, isEmpty);
    expect(steps.last.fix, contains(file.path));
  });

  // Harm: a modified collection reaches an installer that can write outside its target.
  test('a collection changed by one byte is refused before rent or a remote command', () async {
    final changed = [1, 2, 4];
    await file.writeAsBytes(changed);
    final code = await run.up(
      HostPlan(
        project: 'demo',
        account: 'porelo',
        publicKey: 'ssh-ed25519 BBBB me',
        collection: file.path,
        collectionSha256: expected,
      ),
    );
    expect(code, Exit.refused);
    expect(provider.created, 0);
    expect(remote.commands, isEmpty);
    expect(steps.last.fix, contains(expected));
    expect(steps.last.fix, contains(sha256.convert(changed).toString()));
  });

  // Harm: an arbitrary collection bypasses the pinned digest through an incomplete override.
  test('an override without its digest is refused before rent', () async {
    await file.writeAsBytes(original);
    expect(
      await run.up(HostPlan(project: 'demo', account: 'porelo', publicKey: 'key', collection: file.path)),
      Exit.refused,
    );
    expect(provider.created, 0);
    expect(remote.commands, isEmpty);
    expect(steps.last.fix, contains('--collection-sha256'));
  });

  // Harm: the command line bypasses the pinned digest by accepting an unpaired override.
  test('the CLI refuses a collection override without its digest', () async {
    final result = await Process.run(
      Platform.resolvedExecutable,
      ['bin/porelo_host.dart', 'up', '--collection', file.path],
      environment: {'DASH__SUPPRESS_ANALYTICS': 'true'},
    );
    expect(result.exitCode, Exit.refused, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stderr, contains('--collection-sha256'));
  });

  // Harm: a changed file on the host reaches ansible-galaxy despite passing the local check.
  for (final corrupt in [false, true]) {
    test(
      'the host checksum ${corrupt ? 'refuses changed bytes' : 'accepts the copied bytes'} before installation',
      () async {
        await file.writeAsBytes(original);
        final checkedRemote = _CheckingRemote(folder, corrupt: corrupt);
        final run = HostRun(
          environment: {'XDG_STATE_HOME': folder.path, 'LOCALAPPDATA': folder.path},
          provider: provider,
          remote: checkedRemote,
          emit: steps.add,
        );
        final code = await run.up(
          HostPlan(
            project: 'demo',
            account: 'porelo',
            publicKey: 'key',
            collection: file.path,
            collectionSha256: expected,
          ),
        );
        expect(code, corrupt ? Exit.refused : Exit.done);
        final installs = checkedRemote.commands.where((command) => command.contains('ansible-galaxy'));
        if (corrupt) {
          expect(installs, isEmpty);
          expect(steps.last.words, contains('FAILED'));
          expect(steps.last.words, contains(expected));
          expect(steps.last.words, contains(sha256.convert([1, 2, 2]).toString()));
        } else {
          expect(installs, hasLength(1));
        }
      },
      skip: Platform.isWindows ? 'The checksum probe executes the Linux host shell locally.' : false,
    );
  }
}

/// Executes the real checksum command in a local directory standing in for the host.
class _CheckingRemote extends ScriptedRemote {
  _CheckingRemote(this.folder, {required this.corrupt}) : super([]);
  final Directory folder;
  final bool corrupt;

  @override
  Future<RemoteResult> copy(String host, String user, String from, String to) async {
    final bytes = await File(from).readAsBytes();
    if (corrupt) bytes[bytes.length - 1] ^= 1;
    await File(path.join(folder.path, 'collection.tar.gz')).writeAsBytes(bytes);
    return super.copy(host, user, from, to);
  }

  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String line)? onLine,
  }) async {
    if (!command.startsWith('sha256sum')) return super.run(host, user, command, input: input, onLine: onLine);
    commands.add(command);
    final quotedFolder = "'${folder.path.replaceAll("'", r"'\''")}'";
    final process = await Process.start('sh', ['-c', command.replaceAll('/var/tmp/porelo-host', quotedFolder)]);
    final output = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => onLine?.call(line));
    final errors = process.stderr.transform(utf8.decoder).join();
    process.stdin.write(input!.replaceAll('/var/tmp/porelo-host', folder.path));
    await process.stdin.close();
    final code = await process.exitCode;
    await output;
    return RemoteResult(code, (await errors).trim());
  }
}
