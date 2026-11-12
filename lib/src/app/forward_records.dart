import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// What a path is, read without following a link.
@immutable
class PathFacts {
  /// Constructor taking its owner, its permission bits and its type.
  const PathFacts({required this.owner, required this.permissions, required this.type});

  /// The uid that owns it.
  final int owner;

  /// Its permission bits, `0777` at most.
  final int permissions;

  /// What it is; a link is a link, never what it points at.
  final FileSystemEntityType type;
}

/// Reads [PathFacts] of [path] without following a link, or of the open [descriptor] where one is given (then [path]
/// only names it), or null where it cannot.
typedef ReadPathFacts = PathFacts? Function(String path, int? descriptor);

/// One process held by a handle of its own (a pidfd): the handle refers to that very process, so a signal sent
/// through it never reaches another that took its pid later.
abstract interface class PinnedProcess {
  /// Asks it to end with SIGTERM through the handle, and answers whether the signal was sent.
  bool terminate();

  /// Lets go of the handle.
  void release();
}

/// What this computer says about its processes, read through a seam of its own so a test can say what the real one
/// would.
abstract interface class ProcessTable {
  /// The table of [operatingSystem]: `/proc` on Linux; elsewhere one that knows nothing, so nothing is ended there.
  factory ProcessTable.of(String operatingSystem) =>
      operatingSystem == 'linux' ? const LinuxProcessTable() : const _NoProcessTable();

  /// The uid this interface runs as, or null where it cannot say.
  int? get myUid;

  /// This boot's id, or null where it cannot say: a pid of another boot is no process of this one.
  String? get bootId;

  /// The one uid [pid] runs as, or null where it is gone or runs as several.
  int? ownerOf(int pid);

  /// When [pid] started, field 22 of its `stat`, or null where it is gone.
  String? startTimeOf(int pid);

  /// [pid]'s arguments, its program first, or null where it is gone or they are no text.
  List<String>? argumentsOf(int pid);

  /// Holds [pid] by a handle of its own, or null where it is gone or no such handle can be had here.
  PinnedProcess? pin(int pid);

  /// Whether [pid] is provably gone: the process table can be read, and holds no such pid.
  bool isGone(int pid);
}

class _NoProcessTable implements ProcessTable {
  const _NoProcessTable();

  @override
  int? get myUid => null;

  @override
  String? get bootId => null;

  @override
  int? ownerOf(int pid) => null;

  @override
  String? startTimeOf(int pid) => null;

  @override
  List<String>? argumentsOf(int pid) => null;

  @override
  PinnedProcess? pin(int pid) => null;

  @override
  bool isGone(int pid) => false;
}

/// `/proc`, read as it is now, and a pidfd to signal through.
class LinuxProcessTable implements ProcessTable {
  /// Constructor.
  const LinuxProcessTable();

  @override
  int? get myUid => _uidIn('/proc/self/status');

  @override
  String? get bootId {
    try {
      final id = File('/proc/sys/kernel/random/boot_id').readAsStringSync().trim();
      return id.isEmpty ? null : id;
    } on FileSystemException {
      return null;
    }
  }

  @override
  int? ownerOf(int pid) => _uidIn('/proc/$pid/status');

  // Real, effective, saved and file-system uid: one that differs is no plain process of one account.
  static int? _uidIn(String status) {
    try {
      final line = File(status).readAsLinesSync().firstWhere((each) => each.startsWith('Uid:'), orElse: () => '');
      final uids = line.substring(line.isEmpty ? 0 : 4).trim().split(RegExp(r'\s+')).map(int.tryParse).toSet();
      return uids.length == 1 ? uids.single : null;
    } on FileSystemException {
      return null;
    }
  }

  @override
  String? startTimeOf(int pid) {
    try {
      final stat = File('/proc/$pid/stat').readAsStringSync();
      // The name in parentheses may hold spaces and parentheses itself; field 3 follows its last one.
      final fields = stat.substring(stat.lastIndexOf(')') + 1).trim().split(' ');
      final start = fields.length > 19 ? fields[19] : '';
      return RegExp(r'^[0-9]+$').hasMatch(start) ? start : null;
    } on FileSystemException {
      return null;
    }
  }

  @override
  List<String>? argumentsOf(int pid) {
    try {
      final arguments = utf8.decode(File('/proc/$pid/cmdline').readAsBytesSync()).split('\x00');
      // Every argument ends with a NUL, so the last piece is empty; one that is not was rewritten by its process.
      if (arguments.length < 2 || arguments.last.isNotEmpty) return null;
      return arguments.sublist(0, arguments.length - 1);
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  @override
  bool isGone(int pid) =>
      FileSystemEntity.typeSync('/proc/self', followLinks: false) != FileSystemEntityType.notFound &&
      FileSystemEntity.typeSync('/proc/$pid', followLinks: false) == FileSystemEntityType.notFound;

  @override
  PinnedProcess? pin(int pid) {
    final pidfd = _Pidfd.instance;
    if (pidfd == null) return null;
    final handle = pidfd.open(pid, 0);
    return handle < 0 ? null : _PinnedByPidfd(pidfd, handle);
  }
}

class _PinnedByPidfd implements PinnedProcess {
  _PinnedByPidfd(this._pidfd, this._handle);

  final _Pidfd _pidfd;
  final int _handle;

  @override
  bool terminate() => _pidfd.sendSignal(_handle, ProcessSignal.sigterm.signalNumber, nullptr, 0) == 0;

  @override
  void release() => _pidfd.close(_handle);
}

/// glibc's pidfd calls, or none where this C library has none: then nothing is ended, never by a bare pid.
class _Pidfd {
  _Pidfd._(DynamicLibrary library)
    : open = library.lookupFunction<Int32 Function(Int32, Uint32), int Function(int, int)>('pidfd_open'),
      sendSignal = library
          .lookupFunction<
            Int32 Function(Int32, Int32, Pointer<Void>, Uint32),
            int Function(int, int, Pointer<Void>, int)
          >('pidfd_send_signal'),
      close = library.lookupFunction<Int32 Function(Int32), int Function(int)>('close');

  static final _Pidfd? instance = () {
    try {
      return _Pidfd._(DynamicLibrary.process());
    } on ArgumentError {
      return null;
    }
  }();

  final int Function(int, int) open;
  final int Function(int, int, Pointer<Void>, int) sendSignal;
  final int Function(int) close;
}

/// Whether [command] forwards the unix socket [socket] here.
bool forwardsSocket(List<String> command, String socket) => _forwards(command, (spec) => spec.startsWith('$socket:'));

/// Whether [command] forwards port [port] here to the same port on the far end, as a login forward does.
bool forwardsPort(List<String> command, int port) => _forwards(command, (spec) => spec == '$port:localhost:$port');

bool _forwards(List<String> command, bool Function(String spec) matches) {
  for (var i = 0; i + 1 < command.length; i++) {
    if (command[i] == '-L' && matches(command[i + 1])) return true;
  }
  return false;
}

/// The forwards this interface raised, each recorded by pid, start time, boot and arguments in a directory of this
/// account's own, so one a run that ended without asking left behind is found again at the next start.
///
/// A watched signal lets go of every forward at once; a SIGKILL or a crash leaves them to this, at the next start.
/// **Only what is provably that very forward is ended**: a recorded pid of this boot, held by a pidfd first, then
/// still of this account, with the recorded start time and exactly the recorded arguments, which forward the endpoint
/// asked about, and signalled through that pidfd. A record or directory anybody else could have written is not read,
/// and a pid this run holds is never ended. Every read, write, rename and removal goes through the descriptor of the
/// directory once it was checked, and a record is checked on the descriptor it is read from.
class ForwardRecords {
  /// Constructor taking the directory, and for a test the process table and how a path is read.
  ///
  /// The directory's parent must be this account's alone (`0700`), as `XDG_RUNTIME_DIR` is; else nothing is recorded,
  /// read or ended.
  ForwardRecords(this.directory, {ProcessTable? table, ReadPathFacts? facts})
    : table = table ?? ProcessTable.of(Platform.operatingSystem),
      _facts = facts ?? (Platform.isLinux ? pathFactsOf : (_, _) => null);

  /// The records of this desktop session, in `porelo-forwards` under [runtime], the session's `XDG_RUNTIME_DIR`; null
  /// where there is none, or it is no absolute path.
  static ForwardRecords? inRuntime(String? runtime) =>
      runtime == null || !runtime.startsWith('/') ? null : ForwardRecords('$runtime/porelo-forwards');

  /// Where the records lie.
  final String directory;

  /// Where the processes are read.
  final ProcessTable table;

  final ReadPathFacts _facts;

  /// Told the name of each record once it was checked and before it is read, so a test can replace it in between.
  @visibleForTesting
  void Function(String name)? afterChecking;

  /// The pids this run started and has not let go of yet.
  final Set<int> _holding = <int>{};

  static String _nameOf(int pid) => '$pid.forward';

  /// Records [pid], just started from [command]. A forward without a record is only not found again; nothing is
  /// written where the directory is not this account's alone.
  void record(int pid, List<String> command) {
    _holding.add(pid);
    final boot = table.bootId;
    final start = table.startTimeOf(pid);
    if (boot == null || start == null) return;
    final body = utf8.encode(
      jsonEncode(<String, Object>{'pid': pid, 'boot': boot, 'start': start, 'command': command}),
    );
    _inDirectory(create: true, (folder, _) {
      final temporary = '.$pid.${DateTime.now().microsecondsSinceEpoch}';
      if (!_writeNew(folder, temporary, body) || !_rename(folder, temporary, _nameOf(pid))) _unlink(folder, temporary);
    });
  }

  /// Lets go of [pid], whose forward is seen gone, and removes its record.
  void forget(int pid) {
    _holding.remove(pid);
    _inDirectory((folder, _) => _unlink(folder, _nameOf(pid)));
  }

  /// Ends every forward an earlier run of this interface left that [forwardsIt] says serves the endpoint, and answers
  /// whether it sent any an end. A record stays until its process is seen gone, so one that ignores the end is still
  /// found; a record of a forward that is gone is removed.
  bool endLeftovers(bool Function(List<String> command) forwardsIt) {
    final boot = table.bootId;
    if (boot == null) return false;
    return _inDirectory((folder, me) {
          var ended = false;
          for (final record in _records(folder, me)) {
            if (record.boot != boot || _holding.contains(record.pid) || record.pid == pid) continue;
            if (!forwardsIt(record.command)) continue;
            // Held first, then checked: what is checked is then the process the signal reaches, never one that took
            // the pid in between.
            final pinned = table.pin(record.pid);
            if (pinned == null) {
              if (table.isGone(record.pid)) _unlink(folder, _nameOf(record.pid));
              continue;
            }
            try {
              if (!_stillThat(record)) {
                if (_provenStale(record)) _unlink(folder, _nameOf(record.pid));
                continue;
              }
              if (table.ownerOf(record.pid) != me) continue;
              if (pinned.terminate()) ended = true;
            } finally {
              pinned.release();
            }
          }
          return ended;
        }) ??
        false;
  }

  /// Removes the records of forwards that are provably gone or of another boot; one that cannot be told stays.
  void removeStale() {
    final boot = table.bootId;
    if (boot == null) return;
    _inDirectory((folder, me) {
      for (final record in _records(folder, me)) {
        if (!_holding.contains(record.pid) && (record.boot != boot || _provenStale(record))) {
          _unlink(folder, _nameOf(record.pid));
        }
      }
    });
  }

  // Provably not that process any more: gone, or readably started at another time or running other arguments. One
  // whose start time or arguments cannot be read is not.
  bool _provenStale(_Recorded record) {
    if (table.isGone(record.pid)) return true;
    final start = table.startTimeOf(record.pid);
    if (start == null) return false;
    if (start != record.start) return true;
    final running = table.argumentsOf(record.pid);
    return running != null && !listEquals(running, record.command);
  }

  // The same process: alive, started at the recorded time, and running exactly the recorded arguments.
  bool _stillThat(_Recorded record) {
    if (table.startTimeOf(record.pid) != record.start) return false;
    final running = table.argumentsOf(record.pid);
    return running != null && listEquals(running, record.command);
  }

  /// Runs [work] with the descriptor of the directory, once it and its parent are this account's alone (`0700`).
  T? _inDirectory<T>(T Function(int folder, int me) work, {bool create = false}) {
    final me = table.myUid;
    final flags = _Flags.here;
    final cut = directory.lastIndexOf('/');
    final name = directory.substring(cut + 1);
    if (me == null || flags == null || cut < 0 || name.isEmpty || name == '.' || name == '..') return null;
    final parentPath = directory.substring(0, cut);
    final parent = _openChain(parentPath, flags);
    if (parent == null) return null;
    final libc = _Libc.instance;
    final int folder;
    try {
      final facts = _facts(parentPath, parent);
      if (facts == null ||
          facts.type != FileSystemEntityType.directory ||
          facts.owner != me ||
          facts.permissions != 0x1c0) {
        return null;
      }
      if (create) _native((libc, arena) => libc.mkdirat(parent, arena.string(name), 0x1c0));
      folder = _native(
        (libc, arena) => libc.openat(parent, arena.string(name), flags.directory | flags.noFollow | _oCloexec, 0),
      );
    } finally {
      libc.close(parent);
    }
    if (folder < 0) return null;
    try {
      final facts = _facts(directory, folder);
      if (facts == null ||
          facts.type != FileSystemEntityType.directory ||
          facts.owner != me ||
          facts.permissions != 0x1c0) {
        return null;
      }
      return work(folder, me);
    } finally {
      libc.close(folder);
    }
  }

  /// Opens the directory at the absolute [path] one component at a time from `/`, following no link on the way, or
  /// null where that cannot be done.
  static int? _openChain(String path, _Flags flags) {
    if (!path.startsWith('/')) return null;
    final libc = _Libc.instance;
    var at = _native((libc, arena) => libc.open(arena.string('/'), flags.directory | _oCloexec, 0));
    if (at < 0) return null;
    for (final part in path.split('/').where((each) => each.isNotEmpty)) {
      if (part == '.' || part == '..') {
        libc.close(at);
        return null;
      }
      final next = _native(
        (libc, arena) => libc.openat(at, arena.string(part), flags.directory | flags.noFollow | _oCloexec, 0),
      );
      libc.close(at);
      if (next < 0) return null;
      at = next;
    }
    return at;
  }

  /// The records this account alone wrote: regular files, owned by [me], readable and writable by nobody else, each
  /// checked and read on one descriptor.
  Iterable<_Recorded> _records(int folder, int me) {
    final List<FileSystemEntity> entries;
    try {
      entries = Directory('/proc/self/fd/$folder').listSync(followLinks: false);
    } on FileSystemException {
      return const <_Recorded>[];
    }
    final records = <_Recorded>[];
    for (final entry in entries) {
      final name = entry.path.substring(entry.path.lastIndexOf('/') + 1);
      if (!name.endsWith('.forward')) continue;
      final bytes = _readRecord(folder, name, me);
      final record = bytes == null ? null : _parse(name, bytes);
      if (record != null) records.add(record);
    }
    return records;
  }

  List<int>? _readRecord(int folder, String name, int me) {
    final flags = _Flags.here!;
    final libc = _Libc.instance;
    final file = _native(
      (libc, arena) => libc.openat(folder, arena.string(name), flags.noFollow | _oNonblock | _oCloexec, 0),
    );
    if (file < 0) return null;
    try {
      final facts = _facts(name, file);
      if (facts == null ||
          facts.type != FileSystemEntityType.file ||
          facts.owner != me ||
          facts.permissions & 0x3f != 0) {
        return null; // wider than 0600
      }
      afterChecking?.call(name);
      return _native((libc, arena) {
        final buffer = arena.allocate(_mostBytes + 1).cast<Uint8>();
        var done = 0;
        while (done <= _mostBytes) {
          final read = libc.read(file, Pointer<Uint8>.fromAddress(buffer.address + done), _mostBytes + 1 - done);
          if (read < 0) return null;
          if (read == 0) break;
          done += read;
        }
        return done > _mostBytes ? null : List<int>.of(buffer.asTypedList(done));
      });
    } finally {
      libc.close(file);
    }
  }

  static bool _writeNew(int folder, String name, List<int> bytes) => _native((libc, arena) {
    // Everything allocated before the open, so nothing can throw while the descriptor is held.
    final buffer = arena.bytes(bytes);
    final named = arena.string(name);
    // O_WRONLY | O_CREAT | O_EXCL, 0600: with O_EXCL a link at the name is never followed.
    final descriptor = libc.openat(folder, named, 0x1 | 0x40 | 0x80 | _oCloexec, 0x180);
    if (descriptor < 0) return false;
    var done = 0;
    var failed = false;
    while (done < bytes.length) {
      final wrote = libc.write(descriptor, Pointer<Uint8>.fromAddress(buffer.address + done), bytes.length - done);
      if (wrote <= 0) {
        failed = true;
        break;
      }
      done += wrote;
    }
    return libc.close(descriptor) == 0 && !failed;
  });

  static bool _rename(int folder, String from, String to) =>
      _native((libc, arena) => libc.renameat(folder, arena.string(from), folder, arena.string(to)) == 0);

  static void _unlink(int folder, String name) =>
      _native((libc, arena) => libc.unlinkat(folder, arena.string(name), 0));

  static const _mostBytes = 64 * 1024;
}

const _oCloexec = 0x80000;
const _oNonblock = 0x800;

/// The open flags whose values differ between the architectures this runs on; null on any other.
class _Flags {
  const _Flags(this.directory, this.noFollow);

  final int directory;
  final int noFollow;

  static final _Flags? here = switch (Abi.current()) {
    Abi.linuxX64 => const _Flags(0x10000, 0x20000),
    Abi.linuxArm64 => const _Flags(0x4000, 0x8000),
    _ => null,
  };
}

/// One record, as read.
@immutable
class _Recorded {
  const _Recorded(this.pid, this.boot, this.start, this.command);

  final int pid;
  final String boot;
  final String start;
  final List<String> command;
}

_Recorded? _parse(String name, List<int> bytes) {
  final pid = int.tryParse(name.substring(0, name.length - '.forward'.length));
  if (pid == null || pid <= 1) return null;
  try {
    final read = jsonDecode(utf8.decode(bytes));
    if (read
        case {
          'pid': final int recorded,
          'boot': final String boot,
          'start': final String start,
          'command': final List<Object?> command,
        }
        when recorded == pid &&
            RegExp(r'^[0-9]+$').hasMatch(start) &&
            command.isNotEmpty &&
            command.every((each) => each is String)) {
      return _Recorded(pid, boot, start, command.cast<String>());
    }
  } on FormatException {
    return null;
  }
  return null;
}

/// What [path] is on Linux, read with `statx` without following a link, or what the open [descriptor] is where one is
/// given; null where it cannot be read.
PathFacts? pathFactsOf(String path, int? descriptor) => _native((libc, arena) {
  final buffer = arena.allocate(256);
  // AT_FDCWD or the descriptor with AT_EMPTY_PATH, AT_SYMLINK_NOFOLLOW, STATX_TYPE | STATX_MODE | STATX_UID; the layout
  // of struct statx is the same on every architecture: stx_uid at 20, stx_mode at 28.
  final asked = descriptor == null
      ? libc.statx(-100, arena.string(path), 0x100, 0x1 | 0x2 | 0x8, buffer)
      : libc.statx(descriptor, arena.string(''), 0x1000 | 0x100, 0x1 | 0x2 | 0x8, buffer);
  if (asked != 0) return null;
  final data = ByteData.sublistView(buffer.cast<Uint8>().asTypedList(256));
  final mode = data.getUint16(28, Endian.host);
  final type = switch (mode & 0xf000) {
    0x4000 => FileSystemEntityType.directory,
    0x8000 => FileSystemEntityType.file,
    0xa000 => FileSystemEntityType.link,
    _ => FileSystemEntityType.unixDomainSock,
  };
  return PathFacts(owner: data.getUint32(20, Endian.host), permissions: mode & 0x1ff, type: type);
});

T _native<T>(T Function(_Libc libc, _Arena arena) work) {
  final libc = _Libc.instance;
  final arena = _Arena(libc);
  try {
    return work(libc, arena);
  } finally {
    arena.release();
  }
}

class _Arena {
  _Arena(this._libc);

  final _Libc _libc;
  final List<Pointer<Void>> _held = <Pointer<Void>>[];

  Pointer<Void> allocate(int bytes) {
    final pointer = _libc.malloc(bytes);
    if (pointer.address == 0) throw const FileSystemException('Out of memory');
    _held.add(pointer);
    pointer.cast<Uint8>().asTypedList(bytes).fillRange(0, bytes, 0);
    return pointer;
  }

  Pointer<Uint8> bytes(List<int> bytes) {
    final pointer = allocate(bytes.isEmpty ? 1 : bytes.length).cast<Uint8>();
    pointer.asTypedList(bytes.length).setAll(0, bytes);
    return pointer;
  }

  Pointer<Uint8> string(String text) => bytes([...utf8.encode(text), 0]);

  void release() {
    for (final pointer in _held) {
      _libc.free(pointer);
    }
  }
}

class _Libc {
  _Libc._(DynamicLibrary library)
    : malloc = library.lookupFunction<Pointer<Void> Function(IntPtr), Pointer<Void> Function(int)>('malloc'),
      free = library.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('free'),
      mkdirat = library
          .lookupFunction<Int32 Function(Int32, Pointer<Uint8>, Uint32), int Function(int, Pointer<Uint8>, int)>(
            'mkdirat',
          ),
      open = library
          .lookupFunction<Int32 Function(Pointer<Uint8>, Int32, Uint32), int Function(Pointer<Uint8>, int, int)>(
            'open',
          ),
      openat = library
          .lookupFunction<
            Int32 Function(Int32, Pointer<Uint8>, Int32, Uint32),
            int Function(int, Pointer<Uint8>, int, int)
          >('openat'),
      renameat = library
          .lookupFunction<
            Int32 Function(Int32, Pointer<Uint8>, Int32, Pointer<Uint8>),
            int Function(int, Pointer<Uint8>, int, Pointer<Uint8>)
          >('renameat'),
      unlinkat = library
          .lookupFunction<Int32 Function(Int32, Pointer<Uint8>, Int32), int Function(int, Pointer<Uint8>, int)>(
            'unlinkat',
          ),
      read = library
          .lookupFunction<IntPtr Function(Int32, Pointer<Uint8>, IntPtr), int Function(int, Pointer<Uint8>, int)>(
            'read',
          ),
      write = library
          .lookupFunction<IntPtr Function(Int32, Pointer<Uint8>, IntPtr), int Function(int, Pointer<Uint8>, int)>(
            'write',
          ),
      close = library.lookupFunction<Int32 Function(Int32), int Function(int)>('close'),
      statx = library
          .lookupFunction<
            Int32 Function(Int32, Pointer<Uint8>, Int32, Uint32, Pointer<Void>),
            int Function(int, Pointer<Uint8>, int, int, Pointer<Void>)
          >('statx');

  static final _Libc instance = _Libc._(DynamicLibrary.process());

  final Pointer<Void> Function(int) malloc;
  final void Function(Pointer<Void>) free;
  final int Function(int, Pointer<Uint8>, int) mkdirat;
  final int Function(Pointer<Uint8>, int, int) open;
  final int Function(int, Pointer<Uint8>, int, int) openat;
  final int Function(int, Pointer<Uint8>, int, Pointer<Uint8>) renameat;
  final int Function(int, Pointer<Uint8>, int) unlinkat;
  final int Function(int, Pointer<Uint8>, int) read;
  final int Function(int, Pointer<Uint8>, int) write;
  final int Function(int) close;
  final int Function(int, Pointer<Uint8>, int, int, Pointer<Void>) statx;
}

/// The records of this run, set once it took charge of the window: until then, and in a run that is turned away,
/// nothing is recorded or ended.
ForwardRecords? forwardRecords;
