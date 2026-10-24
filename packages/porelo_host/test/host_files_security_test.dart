import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

const _signing = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAABAgMEBQYHCAkKCwwNDg8QERITFBUWFxgZGhscHR4f fixture';

void main() {
  late Directory scratch;
  late File signing;
  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('host-security-');
    signing = await File(path.join(scratch.path, 'signing.pub')).writeAsString(_signing);
  });
  tearDown(() => scratch.delete(recursive: true));
  Future<List<String>> temporaries() async => [
    await for (final e in scratch.list(recursive: true))
      if (e is Directory && e.uri.pathSegments.any((p) => p.startsWith('.porelo-writing-'))) e.path,
  ];

  // Harm: a file created readable before chmod exposes a WireGuard key to an already open descriptor.
  test('a private file is created at 0600 before any permission command', () async {
    final script = File(path.join(scratch.path, 'creation.dart'));
    await script.writeAsString(r'''
import 'dart:io';
import 'package:porelo_host/porelo_host.dart';
Future<void> main(List<String> arguments) async {
  final writer = HostFileWriter(run: (executable, args) async {
    stdout.writeln((await File(args.last).stat()).mode & 0x1ff);
    return Process.run(executable, args);
  });
  await writer.write(File(arguments.single), [1, 2, 3]);
}
''');
    final config = (await Isolate.packageConfig)!;
    final result = await Process.run('/bin/sh', [
      '-c',
      r'umask 022; exec "$@"',
      'private-file-check',
      path.join(path.dirname(Platform.resolvedExecutable), 'dart'),
      '--packages=${config.toFilePath()}',
      script.path,
      path.join(scratch.path, 'private-file'),
    ]);
    expect(result.exitCode, 0, reason: 'the private writer must finish under the explicit umask: ${result.stderr}');
    expect('${result.stdout}'.trim(), '384', reason: 'the initial file mode is 0600, before chmod');
  }, skip: Platform.isLinux ? false : 'Creation modes require Linux.');

  // Harm: another user can keep a descriptor to a secret or observe partial destination bytes.
  // Red: create the destination directly instead of staging in a checked 0700 directory.
  test('secret destinations appear only complete and private', () async {
    for (final name in ['wireguard.key', 'copied-key', 'wg-quick.conf']) {
      final destination = File(path.join(scratch.path, name));
      final writer = HostFileWriter(
        writeBytes: (file, handle, bytes) async {
          expect(await destination.exists(), isFalse, reason: 'no destination before publication');
          expect(file.parent.parent.path, scratch.path, reason: 'staging stays on the destination filesystem');
          if (Platform.isLinux) {
            expect((await file.parent.stat()).mode & 0x1ff, 0x1c0, reason: 'staging is 0700');
            expect((await file.stat()).mode & 0x1ff, 0x180, reason: 'first byte is written at 0600');
          }
          await handle.writeFrom(bytes, 0, 1);
          expect(await destination.exists(), isFalse, reason: 'partial contents stay private');
          await handle.writeFrom(bytes, 1);
        },
      );
      await writer.write(destination, utf8.encode('complete test bytes'));
      expect(await destination.readAsString(), 'complete test bytes');
      if (Platform.isLinux) expect((await destination.stat()).mode & 0x1ff, 0x180);
      expect(await temporaries(), isEmpty, reason: 'no staging directory after success');
    }
  });

  // Harm: a failed write leaves a partial secret published or an abandoned private file.
  // Red: omit finally cleanup or write directly to the destination.
  test('partial write failures leave neither destination nor staging directory', () async {
    final destination = File(path.join(scratch.path, 'wireguard.key'));
    final writer = HostFileWriter(
      writeBytes: (_, handle, bytes) async {
        await handle.writeFrom(bytes, 0, 1);
        throw const FileSystemException('controlled write failure');
      },
    );
    await expectLater(writer.write(destination, [1, 2, 3]), throwsA(isA<FileSystemException>()));
    expect(await destination.exists(), isFalse);
    expect(await temporaries(), isEmpty);
  });

  // Harm: a link swapped into the final path receives private bytes.
  // Red: follow links in both checks, or attempt publication without the pre-publish link check.
  test('a destination swapped for a symlink during writing is kept and refused', () async {
    final bytes = [1, 2, 3];
    final outside = await File(path.join(scratch.path, 'outside')).writeAsBytes(bytes);
    final destination = File(path.join(scratch.path, 'wireguard.key'));
    final writer = _ObservedPublisher(
      writeBytes: (_, handle, bytes) async {
        if (await destination.exists()) await destination.delete();
        await Link(destination.path).create(outside.path);
        await handle.writeFrom(bytes);
      },
    );
    await expectLater(writer.write(destination, bytes), throwsA(isA<HostFilesRefused>()));
    expect(writer.publications, 0, reason: 'a known symlink must be refused before attempting publication');
    expect(await outside.readAsBytes(), bytes);
    expect(await FileSystemEntity.type(destination.path, followLinks: false), FileSystemEntityType.link);
    expect(await temporaries(), isEmpty);
  }, skip: Platform.isWindows ? 'Creating symlinks needs Windows privileges.' : false);

  // Harm: an identical secret synced with broad permissions remains readable by another user.
  // Red: omit protect(file) in the existing-identical branch of write().
  test('write makes an identical existing 0644 file private without changing its bytes', () async {
    final bytes = utf8.encode('fixture secret bytes');
    final file = await File(path.join(scratch.path, 'wireguard.key')).writeAsBytes(bytes);
    final changed = await Process.run('chmod', ['644', '--', file.path]);
    expect(changed.exitCode, 0);
    expect((await file.stat()).mode & 0x1ff, 0x1a4, reason: 'start with a deliberately readable file');
    await HostFileWriter().write(file, bytes);
    expect((await file.stat()).mode & 0x1ff, 0x180);
    expect(await file.readAsBytes(), bytes);
    expect(await temporaries(), isEmpty);
  }, skip: Platform.isLinux ? false : 'Linux mode checks require Linux.');

  // Harm: repeated setup accepts a host key or copied credential synced back as world-readable.
  // Red: omit protect(file) in the existing-identical branch used by prepare().
  test('prepare restores 0600 on identical host and copied keys synced as 0644', () async {
    final credential = await File(path.join(scratch.path, 'credential')).writeAsString('fixture credential bytes');
    final files = HostFiles(_Secrets());
    Future<HostTunnel> prepare() => files.prepare(
      project: 'demo',
      folder: scratch.path,
      url: 'url',
      signingKey: signing,
      keys: [HostKeyFile('credential', credential)],
    );
    final first = await prepare();
    final destinations = [
      File(path.join(scratch.path, 'porelo-host', 'wireguard.key')),
      File(path.join(scratch.path, 'porelo-host', 'keys', 'credential')),
    ];
    final originalBytes = <List<int>>[];
    for (final file in destinations) {
      originalBytes.add(await file.readAsBytes());
      final changed = await Process.run('chmod', ['644', '--', file.path]);
      expect(changed.exitCode, 0);
      expect((await file.stat()).mode & 0x1ff, 0x1a4);
    }
    final repeated = await prepare();
    for (var i = 0; i < destinations.length; i++) {
      expect((await destinations[i].stat()).mode & 0x1ff, 0x180, reason: destinations[i].path);
      expect(await destinations[i].readAsBytes(), originalBytes[i]);
    }
    expect(repeated.hostPublicKey, first.hostPublicKey);
    expect(repeated.peerPublicKey, first.peerPublicKey);
    expect(await temporaries(), isEmpty);
  }, skip: Platform.isLinux ? false : 'Linux mode checks require Linux.');

  // Harm: bypassing the private writer publishes a copied credential with broad permissions.
  // Red: write keys/ entries directly in prepare instead of calling the injected writer.
  test('prepare copies a credential through the private writer at 0600', () async {
    final bytes = utf8.encode('fixture credential bytes');
    final source = await File(path.join(scratch.path, 'credential')).writeAsBytes(bytes);
    final keyDirectory = path.join(scratch.path, 'porelo-host', 'keys');
    final observed = <List<int>>[];
    final writer = HostFileWriter(
      writeBytes: (file, handle, contents) async {
        if (file.parent.parent.path == keyDirectory) {
          expect((await file.parent.stat()).mode & 0x1ff, 0x1c0);
          expect((await file.stat()).mode & 0x1ff, 0x180, reason: 'the credential first reaches a 0600 staged file');
          observed.add(List.of(contents));
        }
        await handle.writeFrom(contents);
      },
    );
    await HostFiles(_Secrets(), writer: writer).prepare(
      project: 'demo',
      folder: scratch.path,
      url: 'url',
      signingKey: signing,
      keys: [HostKeyFile('credential', source)],
    );
    expect(observed, [bytes], reason: 'the selected credential must actually pass through the writer');
    final copied = File(path.join(keyDirectory, 'credential'));
    expect(await copied.readAsBytes(), bytes);
    expect((await copied.stat()).mode & 0x1ff, 0x180);
    expect(await temporaries(), isEmpty);
  }, skip: Platform.isLinux ? false : 'Linux mode checks require Linux.');

  // Harm: a writer wins the check-to-rename race and its file is silently overwritten.
  // Red: publish with ordinary File.rename instead of atomic no-replace rename.
  test('a destination appearing immediately before rename is never replaced', () async {
    final destination = File(path.join(scratch.path, 'wireguard.key'));
    await expectLater(_ArrivingFile().write(destination, [1, 2, 3]), throwsA(isA<HostFilesRefused>()));
    expect(await destination.readAsString(), 'keep');
    expect(await temporaries(), isEmpty);
  });

  // Harm: secret bytes are written when a permission tool failed or lied about the mode.
  // Red: ignore chmod exit code or its measured mode; omit failure cleanup.
  for (final code in [0, 1]) {
    test('chmod exit $code ${code == 0 ? 'without' : 'despite'} a private mode refuses before writing', () async {
      var wrote = false;
      final destination = File(path.join(scratch.path, 'wireguard.key'));
      final writer = HostFileWriter(
        operatingSystem: 'linux',
        run: (program, args) async {
          expect(program, 'chmod');
          expect(args.take(2), ['600', '--']);
          final mode = code == 0 ? '644' : '600';
          final changed = await Process.run('chmod', [mode, '--', args.last]);
          expect(changed.exitCode, 0, reason: 'the seam must establish its mode regardless of umask');
          expect((await File(args.last).stat()).mode & 0x1ff, code == 0 ? 0x1a4 : 0x180);
          return ProcessResult(0, code, '', '');
        },
        writeBytes: (_, _, _) async {
          wrote = true;
        },
      );
      await expectLater(writer.write(destination, [1]), throwsA(isA<HostFilesRefused>()));
      expect(wrote, isFalse);
      expect(await destination.exists(), isFalse);
      expect(await temporaries(), isEmpty);
    }, skip: Platform.isLinux ? false : 'Linux mode checks require Linux.');
  }

  // Harm: an unexpectedly accessible temporary directory exposes a file before chmod.
  // Red: omit the measured 0700 directory check.
  test('a nonprivate staging directory is refused and removed', () async {
    final destination = File(path.join(scratch.path, 'wireguard.key'));
    await expectLater(_PublicTemporary().write(destination, [1]), throwsA(isA<HostFilesRefused>()));
    expect(await destination.exists(), isFalse);
    expect(await temporaries(), isEmpty);
  }, skip: Platform.isLinux ? false : 'Linux mode checks require Linux.');

  // Harm: Windows publishes secret files with inherited access for other accounts.
  // Red: omit icacls, inheritance removal, or the current-user-only grant.
  test('Windows ACL commands restrict the staged directory and written file to the current SID', () async {
    final calls = <(String, List<String>)>[];
    var directoryProtected = false;
    var wrote = false;
    final destination = File(path.join(scratch.path, 'wireguard.key'));
    final writer = HostFileWriter(
      operatingSystem: 'windows',
      run: (program, args) async {
        calls.add((program, List.of(args)));
        if (program == 'whoami') return ProcessResult(0, 0, '"DESKTOP\\person","S-1-5-21-111-222-333-1001"\r\n', '');
        expect(await destination.exists(), isFalse, reason: 'ACLs must precede publication');
        if (await FileSystemEntity.type(args.first, followLinks: false) == FileSystemEntityType.directory) {
          directoryProtected = true;
        } else {
          expect(wrote, isTrue, reason: 'the completed file is restricted after writing');
          expect(await File(args.first).readAsString(), 'test bytes');
        }
        return ProcessResult(0, 0, '', '');
      },
      writeBytes: (_, handle, bytes) async {
        expect(directoryProtected, isTrue, reason: 'the directory ACL must protect the first byte');
        wrote = true;
        await handle.writeFrom(bytes);
      },
    );
    await writer.write(destination, utf8.encode('test bytes'));
    expect(calls.where((c) => c.$1 == 'whoami'), isNotEmpty);
    for (final call in calls.where((c) => c.$1 == 'whoami')) {
      expect(call.$2, ['/user', '/fo', 'csv', '/nh']);
    }
    final acl = calls.where((c) => c.$1 == 'icacls').map((c) => c.$2).toList();
    expect(acl.length, 2, reason: 'protect both the temporary directory and its completed file');
    expect(acl.first.sublist(1), ['/inheritance:r', '/grant:r', '*S-1-5-21-111-222-333-1001:(OI)(CI)F']);
    expect(acl.last.sublist(1), ['/inheritance:r', '/grant:r', '*S-1-5-21-111-222-333-1001:F']);
    expect(File(acl.last.first).parent.path, acl.first.first);
    expect(await temporaries(), isEmpty);
  });

  // Harm: a failed ACL or identity query still publishes private material.
  // Red: ignore whoami/icacls exit status, accept an invalid SID, or omit failure cleanup.
  for (final failure in ['whoami', 'invalid SID', 'directory ACL', 'file ACL']) {
    test('Windows $failure failure refuses without publishing or leaking tool output', () async {
      var aclCalls = 0;
      final destination = File(path.join(scratch.path, 'wireguard.key'));
      final writer = HostFileWriter(
        operatingSystem: 'windows',
        run: (program, _) async {
          if (program == 'whoami') {
            return ProcessResult(
              0,
              failure == 'whoami' ? 1 : 0,
              failure == 'invalid SID' ? 'private-value' : '"person","S-1-5-21-111-1001"',
              'private-value',
            );
          }
          aclCalls++;
          return ProcessResult(
            0,
            failure == (aclCalls == 1 ? 'directory ACL' : 'file ACL') ? 1 : 0,
            'private-value',
            'private-value',
          );
        },
      );
      await expectLater(
        writer.write(destination, [1, 2]),
        throwsA(isA<HostFilesRefused>().having((e) => e.message, 'safe refusal', isNot(contains('private-value')))),
      );
      expect(await destination.exists(), isFalse);
      expect(await temporaries(), isEmpty);
    });
  }

  // Harm: selecting a linked folder redirects credentials to an unintended tree.
  // Red: follow links for either the selected folder or its porelo-host child.
  for (final child in [false, true]) {
    test('${child ? 'porelo-host child' : 'chosen folder'} symlink is named and refused', () async {
      final real = await Directory(path.join(scratch.path, 'real')).create();
      final chosen = child
          ? await Directory(path.join(scratch.path, 'chosen')).create()
          : Directory(path.join(scratch.path, 'chosen'));
      final linked = child ? path.join(chosen.path, 'porelo-host') : chosen.path;
      await Link(linked).create(real.path);
      await expectLater(
        HostFiles(_Secrets()).prepare(project: 'demo', folder: chosen.path, url: 'url', signingKey: signing),
        throwsA(isA<HostFilesRefused>().having((e) => e.message, 'path', contains(linked))),
      );
      expect(await real.list().toList(), isEmpty);
    }, skip: Platform.isWindows ? 'Creating symlinks needs Windows privileges.' : false);
  }

  // Harm: a malformed SSH blob makes a meaningless fingerprint look like trusted signing identity.
  // Red: validate only the type prefix or ignore trailing/truncated key fields.
  test('signing key parsing consumes exact supported fields and refuses malformed blobs', () {
    List<int> field(List<int> bytes) => [
      bytes.length >> 24,
      bytes.length >> 16 & 255,
      bytes.length >> 8 & 255,
      bytes.length & 255,
      ...bytes,
    ];
    final edType = field(utf8.encode('ssh-ed25519'));
    final rsaType = field(utf8.encode('ssh-rsa'));
    final ed = [...edType, ...field(List.generate(32, (i) => i))];
    final rsa = [
      ...rsaType,
      ...field([1, 0, 1]),
      ...field([0, ...List.filled(256, 0xc3)]),
    ];
    String key(String type, List<int> blob) => '$type ${base64Encode(blob)} fixture';
    // ssh-keygen -lf: 256 SHA256:ZkAslGjFiUHdGf/WUL8rQvkib4PTvQatUV0OUQSncCA fixture (ED25519)
    expect(HostFiles.signingFingerprint(key('ssh-ed25519', ed)), 'SHA256:ZkAslGjFiUHdGf/WUL8rQvkib4PTvQatUV0OUQSncCA');
    // ssh-keygen -lf: 2048 SHA256:8ROUSqL0R5n/cMDBLPdIpCN5lsMbCdt8d98/gJ6qowY fixture (RSA)
    expect(HostFiles.signingFingerprint(key('ssh-rsa', rsa)), 'SHA256:8ROUSqL0R5n/cMDBLPdIpCN5lsMbCdt8d98/gJ6qowY');
    final malformed = <String>[
      key('ssh-ed25519', [
        ...edType,
        ...field([1]),
      ]),
      key('ssh-ed25519', [...edType, 0, 0, 0]),
      key('ssh-ed25519', ed.sublist(0, ed.length - 1)),
      key('ssh-ed25519', [...ed, 0]),
      key('ssh-rsa', [
        ...rsaType,
        ...field([1, 0, 1]),
      ]),
      key('ssh-rsa', rsa.sublist(0, rsa.length - 1)),
      key('ssh-rsa', [...rsa, 0]),
      key('ssh-rsa', [
        ...rsaType,
        ...field([0x80]),
        ...field([1]),
      ]),
      key('ssh-rsa', [
        ...rsaType,
        ...field([0, 1]),
        ...field([1]),
      ]),
      key('ssh-rsa', [
        ...rsaType,
        ...field([]),
        ...field([1]),
      ]),
    ];
    for (var i = 0; i < malformed.length; i++) {
      expect(
        () => HostFiles.signingFingerprint(malformed[i]),
        throwsA(isA<HostFilesRefused>()),
        reason: 'malformed fixture $i',
      );
    }
    expect(
      () => HostFiles.signingFingerprint(
        key('ssh-dss', [
          ...field(utf8.encode('ssh-dss')),
          ...field([1]),
        ]),
      ),
      throwsA(
        isA<HostFilesRefused>().having(
          (e) => e.message,
          'supported types',
          allOf(contains('ssh-ed25519'), contains('ssh-rsa')),
        ),
      ),
    );
  });

  // Harm: URI conversion crashes the dialog before an unsafe selected name can be refused.
  test('Windows stream names are refused without converting the selected file to a URI', () {
    final windows = path.Context(style: path.Style.windows);
    final key = HostKeyFile('entry', _NoUriFile(r'C:\input\a:b'), pathContext: windows);
    expect(
      () => HostFiles.machineYaml(project: 'demo', url: 'url', fingerprint: 'fp', windows: true, keys: [key]),
      throwsA(isA<HostFilesRefused>()),
    );
    expect(HostKeyFile('entry', _NoUriFile(r'C:\input\key.pem'), pathContext: windows).basename, 'key.pem');
  });

  // Harm: inconsistent Windows destinations can miss a conflict or name a different file.
  test('Windows host destinations use backslashes for every joined segment', () {
    final files = HostFiles(_Secrets(), pathContext: path.Context(style: path.Style.windows));
    for (final folder in [r'C:\host-files-x', 'C:/host-files-x/']) {
      expect(files.destinationPath(folder, 'machine.yml'), r'C:\host-files-x\porelo-host\machine.yml');
      expect(files.destinationPath(folder, 'wireguard.key'), r'C:\host-files-x\porelo-host\wireguard.key');
      expect(files.destinationPath(folder, 'vault-input', key: true), r'C:\host-files-x\porelo-host\keys\vault-input');
    }
    expect(() => files.destinationPath(r'C:\host-files-x', 'a:b', key: true), throwsA(isA<HostFilesRefused>()));
  });

  // Harm: Windows resolves a key filename as a device/stream or merges two destinations.
  // Red: omit Windows basename rules or compare duplicate filenames case-sensitively.
  test('Windows names refuse streams devices trailing characters and folded duplicates', () {
    for (final name in [
      'a:b',
      'CON',
      'con.txt',
      'PrN.pem',
      'aux',
      'NUL.key',
      for (var n = 1; n <= 9; n++) ...['CoM$n.txt', 'lpt$n'],
      'tail.',
      'tail ',
    ]) {
      expect(
        () => HostFiles.machineYaml(
          project: 'demo',
          url: 'url',
          fingerprint: 'fp',
          windows: true,
          keys: [HostKeyFile('entry', File('/input/$name'))],
        ),
        throwsA(isA<HostFilesRefused>()),
        reason: name,
      );
    }
    expect(
      () => HostFiles.machineYaml(
        project: 'demo',
        url: 'url',
        fingerprint: 'fp',
        windows: true,
        keys: [HostKeyFile('first', File('/a/Key')), HostKeyFile('second', File('/b/key'))],
      ),
      throwsA(isA<HostFilesRefused>()),
    );
    expect(
      HostFiles.machineYaml(
        project: 'demo',
        url: 'url',
        fingerprint: 'fp',
        windows: true,
        keys: [HostKeyFile('entry', File('/input/COM10.key'))],
      ),
      contains('COM10.key'),
    );
  });

  // Harm: unescaped control bytes produce an unreadable machine contract.
  // Red: keep JSON's short escapes or let DEL/C1 controls pass through raw.
  test('all C0 DEL and C1 controls are Unicode escapes and parse back exactly', () {
    final codes = [...List.generate(32, (i) => i), ...List.generate(33, (i) => i + 127)];
    final value = String.fromCharCodes(codes);
    final yaml = HostFiles.machineYaml(project: 'demo', url: value, fingerprint: 'fp');
    for (final code in codes) {
      expect(yaml, contains('\\u${code.toRadixString(16).padLeft(4, '0')}'), reason: 'control $code');
    }
    expect(((loadYaml(yaml) as YamlMap)['project'] as YamlMap)['url'], value);
  });

  // Harm: an equal-length comparison can silently accept and replace different private data.
  // Red: compare file lengths alone instead of every byte.
  test('same-length conflicts in machine key and export remain unchanged', () async {
    for (final name in ['machine.yml', 'wireguard.key', 'wg-quick.conf']) {
      final file = await File(path.join(scratch.path, name)).writeAsString('keep');
      await expectLater(
        HostFileWriter().write(file, utf8.encode('lost')),
        throwsA(isA<HostFilesRefused>().having((e) => e.message, 'path', contains(file.path))),
      );
      expect(await file.readAsString(), 'keep');
    }
  });

  // Harm: raw store exceptions can disclose values or leave setup/export without a refusal.
  // Red: return the store's SocketException instead of a sanitized refusal.
  for (final operation in ['read', 'write', 'export']) {
    test('store SocketException during $operation becomes a safe refusal', () async {
      final store = _Secrets();
      final files = HostFiles(store);
      HostTunnel? tunnel;
      if (operation == 'export') {
        tunnel = await files.prepare(project: 'demo', folder: scratch.path, url: 'url', signingKey: signing);
      }
      store.fail = operation == 'export' ? 'read' : operation;
      final action = operation == 'export'
          ? files.exportTunnel(
              project: 'demo',
              tunnel: tunnel!,
              address: 'host',
              destination: File(path.join(scratch.path, 'out.conf')),
            )
          : files.prepare(project: 'demo', url: '', signingKey: File(''));
      await expectLater(
        action,
        throwsA(isA<SecretStoreFailed>().having((e) => e.message, 'safe refusal', isNot(contains('private-value')))),
      );
    });
  }

  // Harm: setup starts with a private key that the store did not actually retain.
  // Red: omit or weaken the read-back equality check.
  for (final altered in [false, true]) {
    test('a ${altered ? 'different read-back' : 'dropped write'} prevents setup', () async {
      final store = _Secrets()
        ..drop = !altered
        ..alter = altered;
      await expectLater(
        HostFiles(store).prepare(project: 'demo', url: '', signingKey: File('')),
        throwsA(isA<HostFilesRefused>()),
      );
    });
  }

  // Harm: logging on reuse/export discloses private material after initial preparation was safe.
  // Red: emit a private key with print, stdout.write or stderr.writeln in reuse/export.
  test('stdout stderr and print during reuse and export contain neither private half', () async {
    final store = _Secrets();
    final files = HostFiles(store);
    final tunnel = await files.prepare(project: 'demo', folder: scratch.path, url: 'url', signingKey: signing);
    final host = (await File(path.join(scratch.path, 'porelo-host', 'wireguard.key')).readAsString()).trim();
    final person = store.values.values.single;
    final out = _Output();
    final err = _Output();
    final printed = <String>[];
    await runZoned(
      () => IOOverrides.runZoned(
        () async {
          print('print control');
          stdout.write('stdout control');
          stderr.writeln('stderr control');
          await files.prepare(project: 'demo', folder: scratch.path, url: 'url', signingKey: signing);
          await files.exportTunnel(
            project: 'demo',
            tunnel: tunnel,
            address: 'host',
            destination: File(path.join(scratch.path, 'asked.conf')),
          );
        },
        stdout: () => out,
        stderr: () => err,
      ),
      zoneSpecification: ZoneSpecification(print: (_, _, _, value) => printed.add(value)),
    );
    expect(printed, ['print control']);
    expect(out.text.toString(), 'stdout control');
    expect(err.text.toString(), 'stderr control\n');
    for (final secret in [host, person]) {
      expect('${printed.join()}${out.text}${err.text}', isNot(contains(secret)));
    }
  });
}

class _ArrivingFile extends HostFileWriter {
  @override
  Future<void> publish(File prepared, File destination) async {
    await destination.writeAsString('keep');
    await super.publish(prepared, destination);
  }
}

class _PublicTemporary extends HostFileWriter {
  @override
  Future<Directory> createTemporary(Directory parent) async {
    final directory = await super.createTemporary(parent);
    await Process.run('chmod', ['755', directory.path]);
    return directory;
  }
}

class _Secrets implements SecretStore {
  final values = <String, String>{};
  String? fail;
  bool drop = false;
  bool alter = false;
  @override
  Future<String?> read(String name) async {
    if (fail == 'read') throw const SocketException('private-value');
    return values[name];
  }

  @override
  Future<void> write(String name, String value) async {
    if (fail == 'write') throw const SocketException('private-value');
    if (!drop) values[name] = alter ? base64Encode(List.filled(32, 7)) : value;
  }

  @override
  Future<void> remove(String name) async => values.remove(name);
  @override
  Future<void> close() async {}
}

class _Output implements Stdout {
  final text = StringBuffer();
  @override
  void write(Object? value) => text.write(value);
  @override
  void writeln([Object? value = '']) => text.writeln(value);
  @override
  void add(List<int> bytes) => text.write(utf8.decode(bytes));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ObservedPublisher extends HostFileWriter {
  _ObservedPublisher({super.writeBytes});
  int publications = 0;
  @override
  Future<void> publish(File prepared, File destination) async {
    publications++;
    await super.publish(prepared, destination);
  }
}

// Models Windows File.uri rejecting an alternate-stream path, independently of the test host.
class _NoUriFile implements File {
  _NoUriFile(this.path);
  @override
  final String path;
  @override
  Uri get uri => throw ArgumentError('Illegal character in path');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
