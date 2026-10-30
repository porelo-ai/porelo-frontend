// Linux only: private file publication invokes chmod and inspects POSIX file modes.
@Tags(['linux'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

void main() {
  late Directory scratch;
  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('host-security-');
  });
  tearDown(() => scratch.delete(recursive: true));
  Future<List<String>> temporaries() async => [
    await for (final e in scratch.list(recursive: true))
      if (e is Directory && e.uri.pathSegments.any((p) => p.startsWith('.porelo-writing-'))) e.path,
  ];

  // Harm: a file created readable before chmod exposes a credential file to an already open descriptor.
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
    for (final name in ['credential.data', 'copied-key', 'export.data']) {
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
    final destination = File(path.join(scratch.path, 'credential.data'));
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
    final destination = File(path.join(scratch.path, 'credential.data'));
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
    final file = await File(path.join(scratch.path, 'credential.data')).writeAsBytes(bytes);
    final changed = await Process.run('chmod', ['644', '--', file.path]);
    expect(changed.exitCode, 0);
    expect((await file.stat()).mode & 0x1ff, 0x1a4, reason: 'start with a deliberately readable file');
    await HostFileWriter().write(file, bytes);
    expect((await file.stat()).mode & 0x1ff, 0x180);
    expect(await file.readAsBytes(), bytes);
    expect(await temporaries(), isEmpty);
  }, skip: Platform.isLinux ? false : 'Linux mode checks require Linux.');

  // Harm: a writer wins the check-to-rename race and its file is silently overwritten.
  // Red: publish with ordinary File.rename instead of atomic no-replace rename.
  test('a destination appearing immediately before rename is never replaced', () async {
    final destination = File(path.join(scratch.path, 'credential.data'));
    await expectLater(_ArrivingFile().write(destination, [1, 2, 3]), throwsA(isA<HostFilesRefused>()));
    expect(await destination.readAsString(), 'keep');
    expect(await temporaries(), isEmpty);
  });

  // Harm: secret bytes are written when a permission tool failed or lied about the mode.
  // Red: ignore chmod exit code or its measured mode; omit failure cleanup.
  for (final code in [0, 1]) {
    test('chmod exit $code ${code == 0 ? 'without' : 'despite'} a private mode refuses before writing', () async {
      var wrote = false;
      final destination = File(path.join(scratch.path, 'credential.data'));
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
    final destination = File(path.join(scratch.path, 'credential.data'));
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
    final destination = File(path.join(scratch.path, 'credential.data'));
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
      final destination = File(path.join(scratch.path, 'credential.data'));
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

  // Harm: inconsistent Windows destinations can miss a conflict or name a different file.
  test('Windows host destinations use backslashes for every joined segment', () {
    final files = HostFiles(pathContext: path.Context(style: path.Style.windows));
    for (final folder in [r'C:\host-files-x', 'C:/host-files-x/']) {
      expect(files.destinationPath(folder, 'machine.yml'), r'C:\host-files-x\porelo-host\machine.yml');
      expect(files.destinationPath(folder, 'credential.data'), r'C:\host-files-x\porelo-host\credential.data');
      expect(files.destinationPath(folder, 'vault-input', key: true), r'C:\host-files-x\porelo-host\keys\vault-input');
    }
    expect(() => files.destinationPath(r'C:\host-files-x', 'a:b', key: true), throwsA(isA<HostFilesRefused>()));
  });

  // Harm: an equal-length comparison can silently accept and replace different private data.
  // Red: compare file lengths alone instead of every byte.
  test('same-length conflicts leave private files unchanged', () async {
    for (final name in ['machine.yml', 'credential.data', 'export.data']) {
      final file = await File(path.join(scratch.path, name)).writeAsString('keep');
      await expectLater(
        HostFileWriter().write(file, utf8.encode('lost')),
        throwsA(isA<HostFilesRefused>().having((e) => e.message, 'path', contains(file.path))),
      );
      expect(await file.readAsString(), 'keep');
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
