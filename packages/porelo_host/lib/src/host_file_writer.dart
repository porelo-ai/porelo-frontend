import 'dart:io';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;
import 'package:win32/win32.dart';

import 'host_files.dart';

/// Runs permission tools without passing file contents as arguments.
typedef HostPermissionCommand = Future<ProcessResult> Function(String executable, List<String> arguments);

/// Writes through the same handle that the publisher flushes and closes.
typedef HostBytesWriter = Future<void> Function(File file, RandomAccessFile handle, List<int> bytes);

/// Writes a host file without replacing different existing contents.
class HostFileWriter {
  /// Permission and byte-writing seams let tests observe a write before publication.
  HostFileWriter({String? operatingSystem, HostPermissionCommand? run, HostBytesWriter? writeBytes})
    : operatingSystem = operatingSystem ?? Platform.operatingSystem,
      run = run ?? Process.run,
      writeBytes = writeBytes ?? _bytes;

  /// The platform whose permissions apply.
  final String operatingSystem;

  /// How permission tools run, without a shell.
  final HostPermissionCommand run;

  /// Writes bytes to the open file, before its flush and close.
  final HostBytesWriter writeBytes;

  /// Whether Windows destination naming rules apply.
  bool get isWindows => operatingSystem == 'windows';

  static Future<void> _bytes(File file, RandomAccessFile handle, List<int> bytes) async => handle.writeFrom(bytes);

  /// Refuses a nonregular file or different content; accepts identical bytes.
  Future<bool> check(File file, List<int> bytes) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return false;
    if (type != FileSystemEntityType.file) conflict(file.path);
    final kept = await file.readAsBytes();
    if (kept.length != bytes.length) conflict(file.path);
    for (var i = 0; i < bytes.length; i++) {
      if (kept[i] != bytes[i]) conflict(file.path);
    }
    return true;
  }

  /// Names a conflicting destination without its contents.
  static Never conflict(String path) => throw HostFilesRefused(
    '$path already exists and differs or is not a regular file. Remove it or choose another folder.',
  );

  Future<void> _windowsPrivate(String path, {bool directory = false}) async {
    const identityFailure = HostFilesRefused('Cannot identify the current Windows user to restrict host files.');
    ProcessResult identity;
    try {
      identity = await run('whoami', ['/user', '/fo', 'csv', '/nh']);
    } on Exception {
      throw identityFailure;
    }
    final row = RegExp(r'^"[^"\r\n]+","(S-1-[0-9]+(?:-[0-9]+)+)"$').firstMatch('${identity.stdout}'.trim());
    if (identity.exitCode != 0 || row == null) throw identityFailure;
    final grant = '*${row.group(1)}:${directory ? '(OI)(CI)F' : 'F'}';
    ProcessResult result;
    try {
      result = await run('icacls', [path, '/inheritance:r', '/grant:r', grant]);
    } on Exception {
      throw HostFilesRefused('Cannot restrict $path to the current Windows user.');
    }
    if (result.exitCode != 0) throw HostFilesRefused('Cannot restrict $path to the current Windows user.');
  }

  /// Keeps a directory this desktop made for itself to the current user alone (`0700`, or the Windows user's ACL).
  Future<void> protectDirectory(Directory directory) async {
    if (isWindows) {
      await _windowsPrivate(directory.absolute.path, directory: true);
      return;
    }
    ProcessResult result;
    try {
      result = await run('chmod', ['700', '--', directory.absolute.path]);
    } on Exception {
      throw HostFilesRefused('Cannot keep ${directory.path} private (0700).');
    }
    if (result.exitCode != 0 || ((await directory.stat()).mode & 0x1ff) != 0x1c0) {
      throw HostFilesRefused('Cannot keep ${directory.path} private (0700).');
    }
  }

  /// Applies and checks the platform's private-file protection.
  Future<void> protect(File file) async {
    if (isWindows) {
      await _windowsPrivate(file.absolute.path);
    } else if (operatingSystem == 'linux') {
      ProcessResult result;
      try {
        result = await run('chmod', ['600', '--', file.absolute.path]);
      } on Exception {
        throw HostFilesRefused('Cannot keep ${file.path} private (0600).');
      }
      if (result.exitCode != 0 || ((await file.stat()).mode & 0x1ff) != 0x180) {
        throw HostFilesRefused('Cannot keep ${file.path} private (0600).');
      }
    } else {
      throw const HostFilesRefused('Private host files require Linux or Windows.');
    }
  }

  /// Creates a staging directory on the destination filesystem.
  Future<Directory> createTemporary(Directory parent) async {
    if (!Platform.isLinux) return parent.createTemp('.porelo-writing-');
    // Dart createTemp uses the process umask; mkdtemp makes the directory private at creation.
    return using((arena) {
      final make = DynamicLibrary.process()
          .lookupFunction<Pointer<Utf8> Function(Pointer<Utf8>), Pointer<Utf8> Function(Pointer<Utf8>)>('mkdtemp');
      final template = path.join(parent.absolute.path, '.porelo-writing-XXXXXX').toNativeUtf8(allocator: arena);
      final made = make(template);
      if (made == nullptr) throw FileSystemException('Cannot create a private staging directory', parent.path);
      return Directory(made.toDartString());
    });
  }

  /// Restricts a scratch directory before any project history is placed inside it.
  Future<Directory> createPrivateTemporary(Directory parent) async {
    final temporary = await createTemporary(parent);
    try {
      if (isWindows) {
        await _windowsPrivate(temporary.absolute.path, directory: true);
      } else if (operatingSystem != 'linux' || ((await temporary.stat()).mode & 0x1ff) != 0x1c0) {
        throw HostFilesRefused('Cannot keep ${temporary.path} private (0700).');
      }
      return temporary;
    } catch (_) {
      await temporary.delete(recursive: true);
      rethrow;
    }
  }

  /// Publishes with an atomic rename that refuses an existing destination.
  Future<void> publish(File prepared, File destination) async {
    final moved = using((arena) {
      if (Platform.isWindows) {
        return MoveFile(
          PCWSTR(prepared.absolute.path.toNativeUtf16(allocator: arena)),
          PCWSTR(destination.absolute.path.toNativeUtf16(allocator: arena)),
        ).value;
      }
      if (Platform.isLinux) {
        try {
          final rename = DynamicLibrary.process()
              .lookupFunction<
                Int32 Function(Int32, Pointer<Utf8>, Int32, Pointer<Utf8>, Uint32),
                int Function(int, Pointer<Utf8>, int, Pointer<Utf8>, int)
              >('renameat2');
          // RENAME_NOREPLACE closes the absence-check race without replacing another writer's file.
          return rename(
                -100,
                prepared.absolute.path.toNativeUtf8(allocator: arena),
                -100,
                destination.absolute.path.toNativeUtf8(allocator: arena),
                1,
              ) ==
              0;
        } on ArgumentError {
          throw const HostFilesRefused('The system does not support publishing host files without replacement.');
        }
      }
      throw const HostFilesRefused('Private host files require Linux or Windows.');
    });
    if (!moved) {
      if (await FileSystemEntity.type(destination.path, followLinks: false) != FileSystemEntityType.notFound) {
        conflict(destination.path);
      }
      throw HostFilesRefused('Cannot publish ${destination.path} without replacing an existing file.');
    }
  }

  /// Stages private, complete contents before making the destination visible.
  Future<void> write(File file, List<int> bytes) async {
    if (await check(file, bytes)) {
      await protect(file);
      return;
    }
    final temporary = await createTemporary(file.parent);
    try {
      if (operatingSystem == 'linux') {
        if (((await temporary.stat()).mode & 0x1ff) != 0x1c0) {
          throw HostFilesRefused('Cannot keep ${temporary.path} private (0700).');
        }
      } else if (isWindows) {
        await _windowsPrivate(temporary.absolute.path, directory: true);
      } else {
        throw const HostFilesRefused('Private host files require Linux or Windows.');
      }
      final prepared = File(path.join(temporary.path, 'contents'));
      if (operatingSystem == 'linux') {
        using((arena) {
          final libc = DynamicLibrary.process();
          final open = libc
              .lookupFunction<Int32 Function(Pointer<Utf8>, Int32, Uint32), int Function(Pointer<Utf8>, int, int)>(
                'open',
              );
          final close = libc.lookupFunction<Int32 Function(Int32), int Function(int)>('close');
          // O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW: the key is private from creation.
          final descriptor = open(prepared.path.toNativeUtf8(allocator: arena), 1 | 64 | 128 | 131072, 0x180);
          if (descriptor < 0) throw const HostFilesRefused('Cannot create the private host file exclusively.');
          if (close(descriptor) != 0) throw const HostFilesRefused('Cannot close the private host file.');
        });
      } else {
        await prepared.create(exclusive: true);
      }
      if (!isWindows) await protect(prepared);
      final handle = await prepared.open(mode: FileMode.writeOnly);
      try {
        await writeBytes(prepared, handle, bytes);
        await handle.flush();
      } finally {
        await handle.close();
      }
      if (isWindows) await protect(prepared);
      if (await FileSystemEntity.type(file.path, followLinks: false) != FileSystemEntityType.notFound) {
        if (await check(file, bytes)) {
          await protect(file);
          return;
        }
      }
      await publish(prepared, file);
    } finally {
      await temporary.delete(recursive: true);
    }
  }
}
