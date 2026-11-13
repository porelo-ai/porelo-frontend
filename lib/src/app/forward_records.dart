import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

/// What a path is, read without following a link.
@immutable
class PathFacts {
  /// Constructor taking its owner, its permission bits and its type.
  const PathFacts({required this.owner, required this.permissions, required this.type, this.group = -1});

  /// The uid that owns it.
  final int owner;

  /// The gid that owns it, or -1 where it was not read.
  final int group;

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
  /// Constructor; [throughSyscall] takes the kernel's pidfd calls by their numbers even where the C library has them,
  /// as one older than glibc 2.36 must.
  const LinuxProcessTable({@visibleForTesting this.throughSyscall = false, @visibleForTesting this.statOf});

  /// Whether the pidfd calls go through `syscall` rather than the C library's own functions.
  final bool throughSyscall;

  /// For a test: what a `stat` of a path answers, 0 or its errno; the kernel's own where null.
  final int Function(String path)? statOf;

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

  // Only ENOENT or ESRCH says the pid is not in a table that can be read; any other failure of the lookup proves
  // nothing, so the record stays.
  @override
  bool isGone(int pid) {
    final stat = statOf ?? _statErrno;
    if (stat('/proc/self') != 0) return false;
    final failure = stat('/proc/$pid');
    return failure == _enoent || failure == _esrch;
  }

  static const _enoent = 2;
  static const _esrch = 3;

  static int _statErrno(String path) => _native((libc, arena) {
    final buffer = arena.allocate(256);
    return libc.statx(-100, arena.string(path), 0x100, 0, buffer) == 0 ? 0 : _errno();
  });

  @override
  PinnedProcess? pin(int pid) {
    final pidfd = throughSyscall ? _Pidfd.bySyscall : _Pidfd.instance;
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

/// The C library's pidfd calls, or the kernel's by their numbers where it has none (glibc before 2.36, as on Ubuntu
/// 22.04); none where neither can be reached: then nothing is ended, never by a bare pid.
class _Pidfd {
  _Pidfd._(DynamicLibrary library)
    : open = library.lookupFunction<Int32 Function(Int32, Uint32), int Function(int, int)>('pidfd_open'),
      sendSignal = library
          .lookupFunction<
            Int32 Function(Int32, Int32, Pointer<Void>, Uint32),
            int Function(int, int, Pointer<Void>, int)
          >('pidfd_send_signal'),
      close = library.lookupFunction<Int32 Function(Int32), int Function(int)>('close');

  _Pidfd._byNumber(DynamicLibrary library)
    : open = _numbered(
        library.lookupFunction<Int64 Function(Int64, VarArgs<(Int32, Uint32)>), int Function(int, int, int)>('syscall'),
        _pidfdOpen,
      ),
      sendSignal = _numberedSignal(
        library.lookupFunction<
          Int64 Function(Int64, VarArgs<(Int32, Int32, Pointer<Void>, Uint32)>),
          int Function(int, int, int, Pointer<Void>, int)
        >('syscall'),
      ),
      close = library.lookupFunction<Int32 Function(Int32), int Function(int)>('close');

  // The same numbers on x86-64 and arm64, the two Linux machines this window is built for.
  static const _pidfdOpen = 434;
  static const _pidfdSendSignal = 424;

  static int Function(int, int) _numbered(int Function(int, int, int) call, int number) =>
      (a, b) => call(number, a, b);

  static int Function(int, int, Pointer<Void>, int) _numberedSignal(
    int Function(int, int, int, Pointer<Void>, int) call,
  ) =>
      (a, b, c, d) => call(_pidfdSendSignal, a, b, c, d);

  static final _Pidfd? instance = () {
    try {
      return _Pidfd._(DynamicLibrary.process());
    } on ArgumentError {
      return bySyscall;
    }
  }();

  static final _Pidfd? bySyscall = () {
    if (Abi.current() != Abi.linuxX64 && Abi.current() != Abi.linuxArm64) return null;
    try {
      return _Pidfd._byNumber(DynamicLibrary.process());
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

/// Whether [command] forwards port [port] here to the same port on the far end, as a login forward does: from the port
/// itself, or from a socket of its own the window relays the port to.
bool forwardsPort(List<String> command, int port) => _forwards(
  command,
  (spec) => spec == '$port:localhost:$port' || (spec.startsWith('/') && spec.endsWith('/l-$port:localhost:$port')),
);

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
      var renamed = false;
      try {
        renamed = _writeNew(folder, temporary, body) && _rename(folder, temporary, _nameOf(pid));
      } finally {
        if (!renamed) _removeTemporary(folder, temporary);
      }
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
  /// null where that cannot be done. Each is opened only to be passed through (`O_PATH`), so a directory that may be
  /// searched and not read is passed as well; the answer serves as the directory of a call, never to list it.
  static int? _openChain(String path, _Flags flags) {
    if (!path.startsWith('/')) return null;
    final libc = _Libc.instance;
    var at = _native((libc, arena) => libc.open(arena.string('/'), _oPath | flags.directory | _oCloexec, 0));
    if (at < 0) return null;
    for (final part in path.split('/').where((each) => each.isNotEmpty)) {
      if (part == '.' || part == '..') {
        libc.close(at);
        return null;
      }
      final int next;
      try {
        next = _native(
          (libc, arena) =>
              libc.openat(at, arena.string(part), _oPath | flags.directory | flags.noFollow | _oCloexec, 0),
        );
      } finally {
        libc.close(at);
      }
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

  // A temporary left is never read, as only a name ending in `.forward` is: its removal failing must not hide what
  // failed before it.
  static void _removeTemporary(int folder, String name) {
    try {
      _unlink(folder, name);
    } on FileSystemException {
      // Left in place.
    }
  }

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
  // AT_FDCWD or the descriptor with AT_EMPTY_PATH, AT_SYMLINK_NOFOLLOW, STATX_TYPE | STATX_MODE | STATX_UID |
  // STATX_GID; the layout of struct statx is the same on every architecture: stx_uid at 20, stx_gid at 24, stx_mode
  // at 28.
  final asked = descriptor == null
      ? libc.statx(-100, arena.string(path), 0x100, 0x1 | 0x2 | 0x8 | 0x10, buffer)
      : libc.statx(descriptor, arena.string(''), 0x1000 | 0x100, 0x1 | 0x2 | 0x8 | 0x10, buffer);
  if (asked != 0) return null;
  final data = ByteData.sublistView(buffer.cast<Uint8>().asTypedList(256));
  final mode = data.getUint16(28, Endian.host);
  final type = switch (mode & 0xf000) {
    0x4000 => FileSystemEntityType.directory,
    0x8000 => FileSystemEntityType.file,
    0xa000 => FileSystemEntityType.link,
    _ => FileSystemEntityType.unixDomainSock,
  };
  return PathFacts(
    owner: data.getUint32(20, Endian.host),
    group: data.getUint32(24, Endian.host),
    permissions: mode & 0x1ff,
    type: type,
  );
});

/// For a test: asked before each allocation of a native call here, which fails where it answers true, as one whose
/// `malloc` answered null.
@visibleForTesting
bool Function()? allocationFails;

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
    if (allocationFails?.call() ?? false) throw const FileSystemException('Out of memory');
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
      getuid = library.lookupFunction<Uint32 Function(), int Function()>('getuid'),
      socket = library.lookupFunction<Int32 Function(Int32, Int32, Int32), int Function(int, int, int)>('socket'),
      send = library
          .lookupFunction<
            IntPtr Function(Int32, Pointer<Uint8>, IntPtr, Int32),
            int Function(int, Pointer<Uint8>, int, int)
          >('send'),
      recv = library
          .lookupFunction<
            IntPtr Function(Int32, Pointer<Uint8>, IntPtr, Int32),
            int Function(int, Pointer<Uint8>, int, int)
          >('recv'),
      linkat = library
          .lookupFunction<
            Int32 Function(Int32, Pointer<Uint8>, Int32, Pointer<Uint8>, Int32),
            int Function(int, Pointer<Uint8>, int, Pointer<Uint8>, int)
          >('linkat'),
      statx = library
          .lookupFunction<
            Int32 Function(Int32, Pointer<Uint8>, Int32, Uint32, Pointer<Void>),
            int Function(int, Pointer<Uint8>, int, int, Pointer<Void>)
          >('statx'),
      connect = library
          .lookupFunction<Int32 Function(Int32, Pointer<Uint8>, Uint32), int Function(int, Pointer<Uint8>, int)>(
            'connect',
          ),
      bind = library
          .lookupFunction<Int32 Function(Int32, Pointer<Uint8>, Uint32), int Function(int, Pointer<Uint8>, int)>(
            'bind',
          ),
      listen = library.lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>('listen'),
      accept4 = library
          .lookupFunction<
            Int32 Function(Int32, Pointer<Void>, Pointer<Void>, Int32),
            int Function(int, Pointer<Void>, Pointer<Void>, int)
          >('accept4'),
      shutdown = library.lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>('shutdown'),
      poll = library
          .lookupFunction<Int32 Function(Pointer<Uint8>, Uint64, Int32), int Function(Pointer<Uint8>, int, int)>(
            'poll',
          ),
      getsockopt = library
          .lookupFunction<
            Int32 Function(Int32, Int32, Int32, Pointer<Void>, Pointer<Uint32>),
            int Function(int, int, int, Pointer<Void>, Pointer<Uint32>)
          >('getsockopt');

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
  final int Function() getuid;
  final int Function(int, int, int) socket;
  final int Function(int, Pointer<Uint8>, int, int) send;
  final int Function(int, Pointer<Uint8>, int, int) recv;
  final int Function(int, Pointer<Uint8>, int, Pointer<Uint8>, int) linkat;
  final int Function(int, Pointer<Uint8>, int, int, Pointer<Void>) statx;
  final int Function(int, Pointer<Uint8>, int) connect;
  final int Function(int, Pointer<Uint8>, int) bind;
  final int Function(int, int) listen;
  final int Function(int, Pointer<Void>, Pointer<Void>, int) accept4;
  final int Function(int, int) shutdown;
  final int Function(Pointer<Uint8>, int, int) poll;
  final int Function(int, int, int, Pointer<Void>, Pointer<Uint32>) getsockopt;
}

/// A socket file's identity: the device it lies on and its inode.
@immutable
class SocketIdentity {
  /// Constructor taking the device's numbers and the inode.
  const SocketIdentity(this.deviceMajor, this.deviceMinor, this.inode);

  /// The device's major number.
  final int deviceMajor;

  /// The device's minor number.
  final int deviceMinor;

  /// The inode.
  final int inode;

  @override
  bool operator ==(Object other) =>
      other is SocketIdentity &&
      other.deviceMajor == deviceMajor &&
      other.deviceMinor == deviceMinor &&
      other.inode == inode;

  @override
  int get hashCode => Object.hash(deviceMajor, deviceMinor, inode);

  @override
  String toString() => '$deviceMajor:$deviceMinor/$inode';
}

/// A socket file held open by a descriptor of its own (`O_PATH`), so its inode cannot be freed and given to another
/// file while it is held: its identity keeps naming that very file until [release].
class HeldSocket {
  HeldSocket._(this._descriptor, this.identity);

  /// Holds the socket file at [path], a link not followed, reached through its directory opened one component at a
  /// time from `/`; null where it is no socket or cannot be held.
  static HeldSocket? at(String path) {
    final flags = _Flags.here;
    final named = _split(path);
    if (flags == null || named == null) return null;
    final parent = ForwardRecords._openChain(named.parent, flags);
    if (parent == null) return null;
    final libc = _Libc.instance;
    var held = -1;
    try {
      held = _native(
        (libc, arena) => libc.openat(parent, arena.string(named.name), _oPath | flags.noFollow | _oCloexec, 0),
      );
      if (held < 0) return null;
      final identity = _identityAt(held, '', emptyPath: true);
      // The held file and the name as it stands now: the same socket, or nothing is held.
      if (identity == null || _identityAt(parent, named.name) != identity) return null;
      final made = HeldSocket._(held, identity);
      held = -1;
      return made;
    } finally {
      if (held >= 0) libc.close(held);
      libc.close(parent);
    }
  }

  /// The pid that listens on the socket bound to this very file, or null where none does or it cannot be told. Asked
  /// by connecting through the held descriptor rather than by name, so the kernel reaches the socket bound to this
  /// file itself, never one whose number only looks alike: its credentials name the process that called `listen`. The
  /// listener sees one connection opened and closed.
  int? listenerPid() => _descriptor < 0 ? null : _connected('/proc/self/fd/$_descriptor', (client) => _peerPid(client));

  int _descriptor;

  /// The path that reaches the socket bound to this very file while it is held, whatever is put at its name meanwhile;
  /// null once let go. It names a descriptor of this process: only this process may connect through it.
  String? get through => _descriptor < 0 ? null : '/proc/self/fd/$_descriptor';

  /// The held file's identity.
  final SocketIdentity identity;

  /// Lets go of the file.
  void release() {
    if (_descriptor < 0) return;
    _Libc.instance.close(_descriptor);
    _descriptor = -1;
  }
}

({String parent, String name})? _split(String path) {
  final cut = path.lastIndexOf('/');
  if (!path.startsWith('/') || cut < 0) return null;
  final name = path.substring(cut + 1);
  if (name.isEmpty || name == '.' || name == '..') return null;
  return (parent: cut == 0 ? '/' : path.substring(0, cut), name: name);
}

/// The identity of the socket at [path], a link not followed; null where nothing, or anything but a socket, is there.
SocketIdentity? socketIdentityOf(String path) => _Flags.here == null ? null : _identityAt(-100, path); // AT_FDCWD

SocketIdentity? _identityAt(int at, String name, {bool emptyPath = false}) => _native((libc, arena) {
  final buffer = arena.allocate(256);
  // AT_SYMLINK_NOFOLLOW (| AT_EMPTY_PATH); STATX_TYPE | STATX_INO. struct statx: stx_mask at 0, stx_mode at 28, stx_ino
  // at 32, stx_dev_major at 136, stx_dev_minor at 140, the same on every architecture.
  if (libc.statx(at, arena.string(name), 0x100 | (emptyPath ? 0x1000 : 0), 0x1 | 0x100, buffer) != 0) return null;
  final data = ByteData.sublistView(buffer.cast<Uint8>().asTypedList(256));
  if (data.getUint32(0, Endian.host) & 0x101 != 0x101) return null;
  if (data.getUint16(28, Endian.host) & 0xf000 != 0xc000) return null; // S_IFSOCK
  return SocketIdentity(
    data.getUint32(136, Endian.host),
    data.getUint32(140, Endian.host),
    data.getUint64(32, Endian.host),
  );
});

/// Whether [directory] is this account's alone to change: a directory owned by it that nobody else may write, reached
/// one component at a time from `/` following no link. Only there is a socket removed or a name linked.
bool isOwnDirectory(String directory) {
  final flags = _Flags.here;
  if (flags == null) return false;
  final opened = ForwardRecords._openChain(directory, flags);
  if (opened == null) return false;
  try {
    return _isOwn(directory, opened);
  } finally {
    _Libc.instance.close(opened);
  }
}

/// The uid this process runs as: the person the window runs for.
int accountUid() => _Libc.instance.getuid();

bool _isOwn(String path, int descriptor) {
  final facts = pathFactsOf(path, descriptor);
  return facts != null &&
      facts.type == FileSystemEntityType.directory &&
      facts.owner == _Libc.instance.getuid() &&
      facts.permissions & 0x12 == 0; // no group or other write
}

/// Removes the socket at [path] only while it is still [held]'s file, and answers whether it did. The name is removed
/// through its directory, opened one component at a time from `/` following no link, and only where that directory is
/// this account's alone; there the identity is read once more right before the unlink. Linux has no unlink of a name
/// only while it is a given inode, so between that read and the unlink only a process of this account could put
/// another object there; the held file keeps its inode from being given to another meanwhile.
bool removeSocketIfStill(String path, HeldSocket held) {
  final flags = _Flags.here;
  final named = _split(path);
  if (flags == null || named == null || held._descriptor < 0) return false;
  final parent = ForwardRecords._openChain(named.parent, flags);
  if (parent == null) return false;
  try {
    if (!_isOwn(named.parent, parent)) return false;
    if (_identityAt(parent, named.name) != held.identity) return false;
    return _native((libc, arena) => libc.unlinkat(parent, arena.string(named.name), 0)) == 0;
  } finally {
    _Libc.instance.close(parent);
  }
}

/// Gives the socket file at [from] the second name [to] in the same directory, failing where [to] exists: `link(2)`
/// takes a name only while it is free, so whoever links first holds it. Answers 0, or the errno.
int linkSocketName(String from, String to) {
  final flags = _Flags.here;
  final a = _split(from), b = _split(to);
  if (flags == null || a == null || b == null || a.parent != b.parent) return 22; // EINVAL
  final parent = ForwardRecords._openChain(a.parent, flags);
  if (parent == null) return 2;
  try {
    if (!_isOwn(a.parent, parent)) return 13; // EACCES
    return _native((libc, arena) {
      final done = libc.linkat(parent, arena.string(a.name), parent, arena.string(b.name), 0);
      return done == 0 ? 0 : _errno();
    });
  } finally {
    _Libc.instance.close(parent);
  }
}

int _errno() => _errnoLocation().value;

final Pointer<Int32> Function() _errnoLocation = DynamicLibrary.process()
    .lookupFunction<Pointer<Int32> Function(), Pointer<Int32> Function()>('__errno_location');

/// One unix socket of this network namespace bound to a file, as the kernel reports it (`sock_diag`): the socket's own
/// inode, whether it listens, and the file it is bound to, whatever name it was bound by.
typedef BoundSocket = ({int socket, bool listening, SocketIdentity file});

/// Whether [socket] may be bound to [file]. The kernel names a bound file's inode in 32 bits, so only those of
/// [file]'s inode are compared, and two socket files on one device that share them are taken for one: enough to keep a
/// path as somebody's, never enough to prove one's own ([HeldSocket.listenerPid] does that).
bool boundTo(BoundSocket socket, SocketIdentity file) =>
    socket.file.deviceMajor == file.deviceMajor &&
    socket.file.deviceMinor == file.deviceMinor &&
    socket.file.inode == file.inode & 0xffffffff;

/// Every unix socket of this network namespace bound to a file, or null where the kernel could not be asked. A socket
/// bound in another network namespace, such as a container's with the directory mounted, is not among them.
List<BoundSocket>? boundSockets() {
  if (_Flags.here == null) return null;
  final libc = _Libc.instance;
  // AF_NETLINK, SOCK_DGRAM | SOCK_CLOEXEC, NETLINK_SOCK_DIAG.
  final link = libc.socket(16, 2 | 0x80000, 4);
  if (link < 0) return null;
  try {
    return _native((libc, arena) {
      final request = arena.allocate(40).cast<Uint8>();
      final out = ByteData.sublistView(request.asTypedList(40))
        ..setUint32(0, 40, Endian.host) // nlmsg_len
        ..setUint16(4, 20, Endian.host) // SOCK_DIAG_BY_FAMILY
        ..setUint16(6, 0x1 | 0x300, Endian.host) // NLM_F_REQUEST | NLM_F_DUMP
        ..setUint32(8, 1, Endian.host)
        ..setUint8(16, 1) // AF_UNIX
        ..setUint32(20, 0xffffffff, Endian.host) // every state
        ..setUint32(28, 0x2, Endian.host); // UDIAG_SHOW_VFS
      if (out.lengthInBytes != 40 || libc.send(link, request, 40, 0) != 40) return null;
      const size = 1 << 16;
      final buffer = arena.allocate(size).cast<Uint8>();
      final found = <BoundSocket>[];
      while (true) {
        final read = libc.recv(link, buffer, size, 0);
        if (read <= 0) return null;
        final data = ByteData.sublistView(buffer.asTypedList(read));
        var at = 0;
        while (at + 16 <= read) {
          final length = data.getUint32(at, Endian.host), type = data.getUint16(at + 4, Endian.host);
          if (length < 16 || at + length > read) return null;
          if (type == 3) return found; // NLMSG_DONE
          if (type == 2) return null; // NLMSG_ERROR
          // struct unix_diag_msg after the header: family, type, state, pad, ino, cookie[2]; then attributes.
          final message = at + 16;
          final state = data.getUint8(message + 2);
          final socket = data.getUint32(message + 4, Endian.host);
          var attribute = message + 16;
          while (attribute + 4 <= at + length) {
            final attributeLength = data.getUint16(attribute, Endian.host);
            if (attributeLength < 4) break;
            // UNIX_DIAG_VFS: the inode and the device of the file it is bound to, the device in the kernel's own encoding.
            if (data.getUint16(attribute + 2, Endian.host) == 1 && attributeLength >= 12) {
              final inode = data.getUint32(attribute + 4, Endian.host);
              final device = data.getUint32(attribute + 8, Endian.host);
              found.add((
                socket: socket,
                listening: state == 10, // TCP_LISTEN
                file: SocketIdentity(device >> 20, device & 0xfffff, inode),
              ));
            }
            attribute += (attributeLength + 3) & ~3;
          }
          at += (length + 3) & ~3;
        }
      }
    });
  } finally {
    libc.close(link);
  }
}

const _oPath = 0x200000;

/// `struct sockaddr_un` naming [path], or null where the path is longer than the 107 bytes it holds.
Pointer<Uint8>? _unixAddress(_Arena arena, String path) {
  final bytes = utf8.encode(path);
  if (bytes.length > 107) return null;
  final address = arena.allocate(_addressSize).cast<Uint8>();
  ByteData.sublistView(address.asTypedList(_addressSize)).setUint16(0, 1, Endian.host); // AF_UNIX
  address.asTypedList(_addressSize).setAll(2, bytes);
  return address;
}

const _addressSize = 110;

/// Connects a socket of its own to the unix socket at [path] and runs [work] with it while it is connected; null where
/// the connect is refused or cannot be made at once: a listener whose queue is full refuses, it never blocks.
T? _connected<T>(String path, T? Function(int client) work) {
  final libc = _Libc.instance;
  // AF_UNIX, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC.
  final client = libc.socket(1, 1 | 0x800 | _oCloexec, 0);
  if (client < 0) return null;
  try {
    final address = _native((libc, arena) {
      final named = _unixAddress(arena, path);
      return named != null && libc.connect(client, named, _addressSize) == 0;
    });
    return address ? work(client) : null;
  } finally {
    libc.close(client);
  }
}

/// The pid of the process that called `listen` on the socket [client] is connected to (`SO_PEERCRED`).
int? _peerPid(int client) => _native((libc, arena) {
  final credentials = arena.allocate(12);
  final length = arena.allocate(4).cast<Uint32>()..value = 12;
  if (libc.getsockopt(client, 1, 17, credentials, length) != 0 || length.value != 12) return null; // SOL_SOCKET
  final pid = credentials.cast<Int32>().value;
  return pid > 0 ? pid : null;
});

/// A unix socket this process listens on, made here rather than through `dart:io`, whose listener removes the name it
/// was bound at when it closes, whatever is there by then. Closing this removes no name at all; the names are removed
/// by whoever holds the file, and only while they still name it.
class UnixListener {
  UnixListener._(this._socket);

  final int _socket;
  bool _closed = false;
  ReceivePort? _told;
  ReceivePort? _ended;

  /// Makes a socket bound at [name] in [directory], reached one component at a time from `/` following no link and
  /// this account's alone, and listening; answers it, or why not. Bound through the directory's descriptor, so the
  /// length of [directory] counts for nothing.
  static ({UnixListener? listener, String? failure}) bindIn(String directory, String name) {
    final flags = _Flags.here;
    if (flags == null || name.contains('/') || name.isEmpty) return (listener: null, failure: 'no such socket here');
    final folder = ForwardRecords._openChain(directory, flags);
    if (folder == null) return (listener: null, failure: 'the folder could not be opened');
    final libc = _Libc.instance;
    var socket = -1;
    try {
      if (!_isOwn(directory, folder)) return (listener: null, failure: 'the folder is not yours alone');
      socket = libc.socket(1, 1 | _oCloexec, 0); // AF_UNIX, SOCK_STREAM
      if (socket < 0) return (listener: null, failure: 'errno ${_errno()}');
      final bound = _native((libc, arena) {
        final address = _unixAddress(arena, '/proc/self/fd/$folder/$name');
        if (address == null) return 36; // ENAMETOOLONG
        return libc.bind(socket, address, _addressSize) == 0 && libc.listen(socket, 16) == 0 ? 0 : _errno();
      });
      if (bound != 0) return (listener: null, failure: 'errno $bound');
      final made = UnixListener._(socket);
      socket = -1;
      return (listener: made, failure: null);
    } finally {
      if (socket >= 0) libc.close(socket);
      libc.close(folder);
    }
  }

  /// Holds the socket file at [path], or null where the file there is not this listener's own: a connection through
  /// the held file must reach a socket that this process listens on, and this very socket must receive it.
  HeldSocket? holdOwnFile(String path) {
    final held = HeldSocket.at(path);
    if (held == null) return null;
    var own = false;
    try {
      own =
          _connected('/proc/self/fd/${held._descriptor}', (client) => _peerPid(client) == pid && _acceptWaiting()) ??
          false;
      return own ? held : null;
    } finally {
      if (!own) held.release();
    }
  }

  // Takes a connection that waits to be accepted, if one does, without waiting for one.
  bool _acceptWaiting() => _native((libc, arena) {
    final waiting = arena.allocate(8).cast<Uint8>();
    final asked = ByteData.sublistView(waiting.asTypedList(8))
      ..setInt32(0, _socket, Endian.host)
      ..setInt16(4, 1, Endian.host); // POLLIN
    if (libc.poll(waiting, 1, 0) != 1 || asked.getInt16(6, Endian.host) & 1 == 0) return false;
    final connection = libc.accept4(_socket, nullptr, nullptr, _oCloexec);
    if (connection < 0) return false;
    libc.close(connection);
    return true;
  });

  /// Calls [onConnection] for each connection made to it, until [close]; each is accepted and closed at once.
  Future<void> serve(void Function() onConnection) async {
    if (_closed || _told != null) return;
    final told = _told = ReceivePort()..listen((_) => onConnection());
    final ended = _ended = ReceivePort();
    await Isolate.spawn(_acceptEach, (_socket, told.sendPort), onExit: ended.sendPort, debugName: 'one window');
  }

  /// Stops listening and lets go of the socket, removing no name.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final libc = _Libc.instance;
    // Wakes an accept that waits, which then ends; the descriptor is closed only after, so no other takes its number
    // while it is still used.
    libc.shutdown(_socket, 2); // SHUT_RDWR
    if (_ended case final ended?) {
      await ended.first;
    }
    _told?.close();
    libc.close(_socket);
  }
}

/// Accepts each connection to [listening]'s socket, closes it and says so, until the socket is shut down.
void _acceptEach((int, SendPort) listening) {
  final (socket, told) = listening;
  final libc = _Libc.instance;
  while (true) {
    final connection = libc.accept4(socket, nullptr, nullptr, _oCloexec);
    if (connection >= 0) {
      libc.close(connection);
      told.send(null);
      continue;
    }
    switch (_errno()) {
      case 4 || 103: // EINTR, ECONNABORTED
        continue;
      case 12 || 23 || 24 || 105: // ENOMEM, ENFILE, EMFILE, ENOBUFS: a moment later there may be room
        sleep(const Duration(milliseconds: 100));
      default:
        return; // EINVAL once shut down
    }
  }
}

/// The records of this run, set once it took charge of the window: until then, and in a run that is turned away,
/// nothing is recorded or ended.
ForwardRecords? forwardRecords;
