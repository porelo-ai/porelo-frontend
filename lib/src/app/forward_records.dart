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

/// Reads [PathFacts] without following a link, or null where it cannot.
typedef ReadPathFacts = PathFacts? Function(String path);

/// One process held by a handle of its own (a pidfd): its pid can no longer be taken by another while it is held.
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
/// and a pid this run holds is never ended.
class ForwardRecords {
  /// Constructor taking the directory, and for a test the process table and how a path is read.
  ///
  /// The directory's parent must be this account's alone (`0700`), as `XDG_RUNTIME_DIR` is; else nothing is recorded,
  /// read or ended.
  ForwardRecords(this.directory, {ProcessTable? table, ReadPathFacts? facts})
    : table = table ?? ProcessTable.of(Platform.operatingSystem),
      _facts = facts ?? (Platform.isLinux ? pathFactsOf : (_) => null);

  /// The records of this desktop session, in `porelo-forwards` under [runtime], the session's `XDG_RUNTIME_DIR`; null
  /// where there is none, or it is no absolute path.
  static ForwardRecords? inRuntime(String? runtime) =>
      runtime == null || !runtime.startsWith('/') ? null : ForwardRecords('$runtime/porelo-forwards');

  /// Where the records lie.
  final String directory;

  /// Where the processes are read.
  final ProcessTable table;

  final ReadPathFacts _facts;

  /// The pids this run started and has not let go of yet.
  final Set<int> _holding = <int>{};

  String _recordOf(int pid) => '$directory/$pid.forward';

  /// Records [pid], just started from [command]. A forward without a record is only not found again; nothing is
  /// written where the directory is not this account's alone.
  void record(int pid, List<String> command) {
    _holding.add(pid);
    final me = table.myUid;
    final boot = table.bootId;
    if (me == null || boot == null || !_directoryIsMine(me, create: true)) return;
    final start = table.startTimeOf(pid);
    if (start == null) return;
    final body = utf8.encode(
      jsonEncode(<String, Object>{'pid': pid, 'boot': boot, 'start': start, 'command': command}),
    );
    final temporary = '$directory/.$pid.${DateTime.now().microsecondsSinceEpoch}';
    try {
      _writeNew(temporary, body);
      File(temporary).renameSync(_recordOf(pid));
    } on FileSystemException {
      _remove(temporary);
    }
  }

  /// Lets go of [pid], whose forward ended or is being ended, and removes its record.
  void forget(int pid) {
    _holding.remove(pid);
    final me = table.myUid;
    if (me == null || !_directoryIsMine(me)) return;
    _remove(_recordOf(pid));
  }

  static void _remove(String path) {
    try {
      File(path).deleteSync();
    } on FileSystemException {
      // Gone already.
    }
  }

  bool _directoryIsMine(int me, {bool create = false}) {
    final parent = _facts(Directory(directory).parent.path);
    if (parent == null ||
        parent.type != FileSystemEntityType.directory ||
        parent.owner != me ||
        parent.permissions != 0x1c0) {
      return false; // not 0700
    }
    if (create && FileSystemEntity.typeSync(directory, followLinks: false) == FileSystemEntityType.notFound) {
      try {
        _makeDirectory(directory);
      } on FileSystemException {
        return false;
      }
    }
    final facts = _facts(directory);
    return facts != null &&
        facts.type == FileSystemEntityType.directory &&
        facts.owner == me &&
        facts.permissions & 0x12 == 0; // no group or other write (0022)
  }

  static void _makeDirectory(String path) {
    final made = _native((libc, arena) => libc.mkdir(arena.string(path), 0x1c0)); // 0700
    if (made != 0) throw FileSystemException('Cannot make the directory', path);
  }

  static void _writeNew(String path, List<int> bytes) {
    final written = _native((libc, arena) {
      // O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600: with O_EXCL a link at the path is never followed.
      final descriptor = libc.open(arena.string(path), 0x1 | 0x40 | 0x80 | 0x80000, 0x180);
      if (descriptor < 0) return false;
      final buffer = arena.bytes(bytes);
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
    if (!written) throw FileSystemException('Cannot write the record', path);
  }

  /// Ends every forward an earlier run of this interface left that [forwardsIt] says serves the endpoint, and answers
  /// whether it sent any an end. A record of a forward that is gone is removed.
  bool endLeftovers(bool Function(List<String> command) forwardsIt) {
    final me = table.myUid;
    final boot = table.bootId;
    if (me == null || boot == null || !_directoryIsMine(me)) return false;
    var ended = false;
    for (final record in _records(me)) {
      if (record.boot != boot || _holding.contains(record.pid) || record.pid == pid) continue;
      if (!forwardsIt(record.command)) continue;
      // Held first, then checked: once pinned, the pid cannot be taken by another process before the signal.
      final pinned = table.pin(record.pid);
      if (pinned == null) continue;
      try {
        if (!_stillThat(record)) {
          _remove(_recordOf(record.pid));
          continue;
        }
        if (table.ownerOf(record.pid) != me || !pinned.terminate()) continue;
        _remove(_recordOf(record.pid));
        ended = true;
      } finally {
        pinned.release();
      }
    }
    return ended;
  }

  /// Removes the records of forwards that are gone.
  void removeStale() {
    final me = table.myUid;
    if (me == null || !_directoryIsMine(me)) return;
    for (final record in _records(me)) {
      if (!_holding.contains(record.pid) && (record.boot != table.bootId || !_stillThat(record))) {
        _remove(_recordOf(record.pid));
      }
    }
  }

  // The same process: alive, started at the recorded time, and running exactly the recorded arguments.
  bool _stillThat(_Recorded record) {
    if (table.startTimeOf(record.pid) != record.start) return false;
    final running = table.argumentsOf(record.pid);
    return running != null && listEquals(running, record.command);
  }

  /// The records this account alone wrote: regular files, owned by [me], readable and writable by nobody else.
  Iterable<_Recorded> _records(int me) sync* {
    final List<FileSystemEntity> entries;
    try {
      entries = Directory(directory).listSync(followLinks: false);
    } on FileSystemException {
      return;
    }
    for (final entry in entries) {
      final name = entry.path.substring(entry.path.lastIndexOf('/') + 1);
      if (!name.endsWith('.forward')) continue;
      final facts = _facts(entry.path);
      if (facts == null ||
          facts.type != FileSystemEntityType.file ||
          facts.owner != me ||
          facts.permissions & 0x3f != 0) {
        continue; // wider than 0600
      }
      final List<int> bytes;
      try {
        bytes = File(entry.path).readAsBytesSync();
      } on FileSystemException {
        continue;
      }
      if (bytes.length > _mostBytes) continue;
      final record = _parse(name, bytes);
      if (record != null) yield record;
    }
  }

  static const _mostBytes = 64 * 1024;
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

/// What [path] is on Linux, read with `statx` without following a link, or null where it cannot be read.
PathFacts? pathFactsOf(String path) => _native((libc, arena) {
  final buffer = arena.allocate(256);
  // AT_FDCWD, AT_SYMLINK_NOFOLLOW, STATX_TYPE | STATX_MODE | STATX_UID; the layout of struct statx is the same on
  // every architecture: stx_uid at 20, stx_mode at 28.
  if (libc.statx(-100, arena.string(path), 0x100, 0x1 | 0x2 | 0x8, buffer) != 0) return null;
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
    for (var i = 0; i < bytes; i++) {
      pointer.cast<Uint8>()[i] = 0;
    }
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
      mkdir = library.lookupFunction<Int32 Function(Pointer<Uint8>, Uint32), int Function(Pointer<Uint8>, int)>(
        'mkdir',
      ),
      open = library
          .lookupFunction<Int32 Function(Pointer<Uint8>, Int32, Uint32), int Function(Pointer<Uint8>, int, int)>(
            'open',
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
  final int Function(Pointer<Uint8>, int) mkdir;
  final int Function(Pointer<Uint8>, int, int) open;
  final int Function(int, Pointer<Uint8>, int) write;
  final int Function(int) close;
  final int Function(int, Pointer<Uint8>, int, int, Pointer<Void>) statx;
}

/// The records of this run, set once it took charge of the window: until then, and in a run that is turned away,
/// nothing is recorded or ended.
ForwardRecords? forwardRecords;
