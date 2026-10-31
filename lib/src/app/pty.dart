import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

/// A byte channel to something running at the far end, and the two things a terminal needs
/// beyond bytes: a size, and an ending.
///
/// **A seam, so everything above it can be proven without a process.** A session's model, its
/// refusals and the way back are the requirement; a real pty is the transport, and a widget test
/// that had to spawn one would be testing the kernel.
abstract class SessionChannel {
  /// What the far end has printed, as it arrives.
  Stream<List<int>> get output;

  /// Sends what somebody typed.
  void send(String input);

  /// Tells the far end how big the window is now.
  void resize({required int columns, required int rows});

  /// The exit code, when it ends.
  Future<int> get ended;

  /// Ends it from this side.
  Future<void> close();
}

/// A terminal that can stop its owned child without discarding buffered output.
///
/// Both [terminate] and [close] wait for output EOF; an incomplete drain throws.
abstract class DrainingSessionChannel implements SessionChannel {
  /// Stops the owned child while preserving output until the channel ends.
  Future<void> terminate();
}

/// A pseudoterminal, opened and driven with `dart:ffi` against libc.
///
/// **Written here rather than taken from a plugin, and the reason is the package.** A native
/// plugin is another `.so` in the bundle, and every `.so` in the bundle goes through
/// `dpkg-shlibdeps` and the rpm scanner to become a package dependency, which has been the
/// most delicate part of shipping this. `dart:ffi` is in the SDK, so this costs the packaging
/// nothing.
///
/// Two things about it are not obvious and both are deliberate:
///
/// * **Nothing here forks.** The obvious shape is `forkpty` and then `exec` in the child — and
///   the child would return into the Dart runtime, in a process whose other threads no longer
///   exist. That is a hang that happens once a week and never in a test. `posix_spawn` does the
///   fork and the exec inside libc, where no Dart code runs at all.
/// * **The exit code comes back on a pipe of its own, never from `waitpid` alone.** While any
///   `dart:io` process runs — an ssh forward, always, for a machine elsewhere — the Dart runtime
///   reaps every child of this process, ours included, and throws the status away; `waitpid` here
///   then finds nothing and the session ended "with -1" after a command that succeeded (measured).
///   So the command runs under a small `sh` that writes its code to descriptor 3,
///   which only this side reads; `waitpid` is what is left when the shell itself was killed.
/// * **The controlling terminal is acquired rather than assigned.** `POSIX_SPAWN_SETSID` makes
///   the child a session leader, and a session leader that opens a terminal without `O_NOCTTY`
///   takes it as its controlling terminal. That is what makes `Ctrl-C` reach the far end instead
///   of this window, and what lets `SIGWINCH` arrive at all.
class Pty implements DrainingSessionChannel {
  Pty._(this._master, this._pid, this._output, this._ended) {
    unawaited(_ended.then((_) => _reaped = true).catchError((Object _) => _reaped = true));
  }

  /// Starts [executable] with [arguments] under a terminal of the given size.
  ///
  /// [environment] is added to this process's own, and `TERM` is set unless it is given: a far
  /// end that is told nothing about the terminal assumes the dumbest one there is, and then
  /// nothing has color and the cursor never moves.
  /// Input [echo] is configured before the child starts, including when disabled.
  factory Pty.start(
    String executable,
    List<String> arguments, {
    int columns = 80,
    int rows = 24,
    bool echo = true,
    Map<String, String> environment = const <String, String>{},
  }) {
    final libc = DynamicLibrary.process();
    final c = _Libc(libc);

    // O_RDWR | O_NOCTTY: this side must not take the terminal as its own, or the window would
    // start receiving the signals meant for what is running inside it.
    final master = c.posixOpenpt(_oRdwr | _oNoctty);
    if (master < 0) throw const PtyRefused('the machine would not open a terminal');
    if (c.grantpt(master) != 0 || c.unlockpt(master) != 0) {
      c.close(master);
      throw const PtyRefused('the terminal could not be handed over');
    }

    final nameBuffer = c.malloc(_pathMax).cast<Uint8>();
    final slave = c.ptsnameR(master, nameBuffer.cast(), _pathMax) == 0 ? _readString(nameBuffer) : '';
    c.free(nameBuffer.cast());
    if (slave.isEmpty) {
      c.close(master);
      throw const PtyRefused('the terminal has no name to open');
    }

    // Set before the child starts, so nothing ever renders at a size it then has to correct.
    _setSize(c, master, columns, rows);
    if (!echo) _disableEcho(c, master);

    final environed = <String, String>{...Platform.environment, 'TERM': 'xterm-256color', ...environment};
    // Found here, before anything runs: under the shell a missing command would be its exit 127,
    // and "there is no such command" is a refusal to open, not a session that died at once.
    final found = _find(executable, environed['PATH'] ?? '');
    if (found.path == null) {
      c.close(master);
      throw PtyRefused(
        found.executable ? 'there is no `$executable` on this machine' : '`$executable` is there and cannot be run',
      );
    }

    final pipe = c.malloc(2 * sizeOf<Int32>()).cast<Int32>();
    if (c.pipe2(pipe, _oCloexec) != 0) {
      c.free(pipe.cast());
      c.close(master);
      throw const PtyRefused('the terminal could not be given a way to report how it ended');
    }
    final statusRead = pipe[0];
    final statusWrite = pipe[1];
    c.free(pipe.cast());

    final actions = c.malloc(_actionsBytes);
    final attributes = c.malloc(_attributesBytes);
    final argv = _stringArray(c, <String>['sh', '-c', _reportsItsCode, 'sh', found.path!, ...arguments]);
    final envp = _stringArray(c, <String>[for (final entry in environed.entries) '${entry.key}=${entry.value}']);
    final slaveName = _cString(c, slave);
    final program = _cString(c, '/bin/sh');
    final pid = c.malloc(sizeOf<Int32>()).cast<Int32>();

    try {
      c.fileActionsInit(actions);
      c.attributesInit(attributes);
      c.attributesSetFlags(attributes, _spawnSetsid);
      // Opened as fd 0 without O_NOCTTY, by a session leader: that is the whole trick.
      c.addOpen(actions, 0, slaveName.cast(), _oRdwr, 0);
      c.addDup2(actions, 0, 1);
      c.addDup2(actions, 0, 2);
      // Descriptor 3 is where the shell reports the code; dup2 clears close-on-exec on it only.
      c.addDup2(actions, statusWrite, 3);
      // The far end has no business holding this side of the terminal open.
      c.addClose(actions, master);

      final failed = c.posixSpawnp(pid, program.cast(), actions, attributes, argv, envp);
      // Only the shell holds the writing end now, so reading it ends when the shell has.
      c.close(statusWrite);
      if (failed != 0) {
        c.close(master);
        c.close(statusRead);
        // **libc answers here rather than letting the child exit 127.** glibc reports an exec
        // that never happened back to the caller, so "there is no such command" arrives as a
        // refusal to open at all — which is a different sentence on screen from a session that
        // opened and was turned away, and the two must not be told the same way.
        throw PtyRefused(switch (failed) {
          _enoent => 'there is no `$executable` on this machine',
          _eacces => '`$executable` is there and cannot be run',
          _ => 'the machine would not start `$executable` (error $failed)',
        });
      }
      final child = pid.value;

      final output = StreamController<List<int>>.broadcast();
      final ended = Completer<int>();
      _pump(master, statusRead, child, output, ended);
      return Pty._(master, child, output, ended.future);
    } finally {
      c.fileActionsDestroy(actions);
      c.attributesDestroy(attributes);
      c.free(actions);
      c.free(attributes);
      c.free(slaveName.cast());
      c.free(program.cast());
      c.free(pid.cast());
      _freeArray(c, argv);
      _freeArray(c, envp);
    }
  }

  final int _master;
  final int _pid;
  final StreamController<List<int>> _output;
  final Future<int> _ended;
  bool _shut = false;
  Future<void>? _closing;

  /// Whether the far end has been waited for. **Nothing is signalled after this.**
  ///
  /// A pid is a number the kernel hands out again. It cannot be reused while the child is a
  /// zombie, and it stops being one the moment the reader isolate reaps it — which is exactly
  /// when this becomes true. So closing a session that has already ended signals nothing, rather
  /// than sending `SIGHUP` to whatever now holds that number.
  bool _reaped = false;

  /// Whether closing actually signalled the far end. For a test, which cannot force a pid to be
  /// reused and can at least hold this to the rule above.
  @visibleForTesting
  bool signalledOnClose = false;

  @override
  Stream<List<int>> get output => _output.stream;

  @override
  Future<int> get ended => _ended;

  /// Sends input to the far end, all of it.
  ///
  /// **`write` is allowed to take some of it.** A pty master whose reader has not caught up
  /// accepts what fits and returns that, and the first version here believed the call: a paste
  /// into a busy program lost its tail, silently, which reads as an agent that ignored half of
  /// what it was told. Interruption is the same shape — `-1` with the buffer untouched — so what
  /// went nowhere is tried again rather than dropped.
  @override
  void send(String input) {
    if (_shut) return;
    final c = _Libc(DynamicLibrary.process());
    final bytes = utf8.encode(input);
    final buffer = c.malloc(bytes.length).cast<Uint8>();
    buffer.asTypedList(bytes.length).setAll(0, bytes);
    var sent = 0;
    // Bounded, because a descriptor that refuses everything for ever must not become a loop that
    // never ends. Generous enough that a full terminal buffer drains long before it runs out.
    var attemptsLeft = 1000;
    while (sent < bytes.length && attemptsLeft-- > 0) {
      final wrote = c.write(_master, (buffer + sent).cast<Uint8>(), bytes.length - sent);
      if (wrote > 0) {
        sent += wrote;
        continue;
      }
      // 0 is nothing taken and -1 is an error; either way there is nothing to learn from here
      // without errno, and both are answered the same way: give the far end a moment and retry.
      if (wrote < 0 && attemptsLeft.isEven) sleep(const Duration(milliseconds: 1));
    }
    c.free(buffer.cast());
  }

  @override
  void resize({required int columns, required int rows}) {
    if (_shut) return;
    _setSize(_Libc(DynamicLibrary.process()), _master, columns, rows);
  }

  @override
  Future<void> close() => _closing ??= _stop(_sighup);

  @override
  Future<void> terminate() {
    // Forced cancellation must also stop a child ignoring an earlier close.
    if (_closing != null && !_reaped) _signal(_sigkill);
    return _closing ??= _stop(_sigkill);
  }

  void _signal(int signal) {
    if (_reaped) return;
    _Libc(DynamicLibrary.process()).kill(-_pid, signal);
    signalledOnClose = true;
  }

  Future<void> _stop(int signal) async {
    _shut = true;
    _signal(signal);
    // A normal window close gives the command a chance to handle SIGHUP.
    final escalation = signal == _sighup ? Timer(const Duration(seconds: 1), () => _signal(_sigkill)) : null;
    final drained = Future.wait<Object?>([_ended, _output.done]).then((_) {
      _Libc(DynamicLibrary.process()).close(_master);
    });
    try {
      // Keep ownership even after a bound, while the reader can still use this fd.
      await drained.timeout(const Duration(seconds: 5));
    } finally {
      escalation?.cancel();
    }
  }

  /// Reads the far end on an isolate of its own.
  ///
  /// **A blocking `read` is the right shape here and needs somewhere to block.** `dart:io` cannot
  /// wrap a descriptor it did not create, so there is no stream to subscribe to; an isolate that
  /// sits in `read(2)` and posts what it gets is the whole of it. It also reaps the child, so
  /// nothing is left as a zombie when a session ends.
  static void _pump(int master, int status, int pid, StreamController<List<int>> output, Completer<int> ended) {
    final port = ReceivePort();
    late final StreamSubscription<dynamic> listening;
    listening = port.listen((dynamic message) async {
      if (message is Uint8List) {
        if (!output.isClosed) output.add(message);
        return;
      }
      if (message is int) {
        if (!ended.isCompleted) ended.complete(message);
        await output.close();
        await listening.cancel();
        port.close();
      }
    });
    unawaited(
      Isolate.spawn(_readUntilItEnds, <Object>[port.sendPort, master, status, pid]).catchError((Object _) {
        if (!ended.isCompleted) ended.complete(-1);
        return Isolate.current;
      }),
    );
  }

  /// The isolate body: read until the far end is gone, then reap it.
  static void _readUntilItEnds(List<Object> arguments) {
    final send = arguments[0] as SendPort;
    final master = arguments[1] as int;
    final reported = arguments[2] as int;
    final pid = arguments[3] as int;
    final c = _Libc(DynamicLibrary.process());
    final buffer = c.malloc(_readChunk).cast<Uint8>();
    try {
      while (true) {
        final read = c.read(master, buffer, _readChunk);
        // A pty master reads 0 at end of file and fails with EIO once the last writer on the
        // other side is gone. Both mean the same thing here, so neither is an error to report.
        if (read <= 0) break;
        send.send(Uint8List.fromList(buffer.asTypedList(read)));
      }
      // What the shell wrote before it exited; nothing, when it was killed first.
      final said = <int>[];
      while (true) {
        final read = c.read(reported, buffer, _readChunk);
        if (read <= 0) break;
        said.addAll(buffer.asTypedList(read));
      }
      c.close(reported);
      final code = int.tryParse(String.fromCharCodes(said).trim());
      // Reaped here either way, so nothing is left a zombie when the runtime did not get to it.
      final status = c.malloc(sizeOf<Int32>()).cast<Int32>();
      final reaped = c.waitpid(pid, status, 0);
      final waited = reaped <= 0
          ? -1
          : (status.value & 0x7f) == 0
          ? (status.value >> 8) & 0xff
          : 128 + (status.value & 0x7f);
      c.free(status.cast());
      send.send(code ?? waited);
    } finally {
      c.free(buffer.cast());
    }
  }

  /// Where [executable] is on [path], or why it cannot be run: `executable` is false when a file of
  /// that name was found and none of them can be run.
  static ({String? path, bool executable}) _find(String executable, String path) {
    final candidates = executable.contains('/')
        ? <String>[executable]
        : <String>[for (final directory in path.split(':')) '${directory.isEmpty ? '.' : directory}/$executable'];
    var foundOne = false;
    for (final candidate in candidates) {
      final stat = FileStat.statSync(candidate);
      if (stat.type != FileSystemEntityType.file) continue;
      foundOne = true;
      if (stat.mode & 0x49 != 0) return (path: candidate, executable: true);
    }
    return (path: null, executable: !foundOne);
  }

  static void _setSize(_Libc c, int fd, int columns, int rows) {
    // struct winsize: four unsigned shorts, rows first. The pixel pair is what nothing has used
    // since terminals had pixels of their own; zero is what every other terminal sends.
    final size = c.malloc(8).cast<Uint16>();
    size[0] = rows;
    size[1] = columns;
    size[2] = 0;
    size[3] = 0;
    c.ioctl(fd, _tiocswinsz, size.cast());
    c.free(size.cast());
  }

  static void _disableEcho(_Libc c, int master) {
    // Linux TCGETS/TCSETS use kernel termios, whose fourth flag word holds ECHO and ECHONL.
    final attributes = c.malloc(64).cast<Uint32>();
    try {
      if (c.ioctl(master, _tcgets, attributes.cast()) != 0) {
        throw const PtyRefused('the terminal input echo could not be read');
      }
      attributes[3] &= ~(_echo | _echoNl);
      if (c.ioctl(master, _tcsets, attributes.cast()) != 0) {
        throw const PtyRefused('the terminal input echo could not be disabled');
      }
    } catch (_) {
      c.close(master);
      rethrow;
    } finally {
      c.free(attributes.cast());
    }
  }

  static Pointer<Uint8> _cString(_Libc c, String value) {
    final bytes = utf8.encode(value);
    final buffer = c.malloc(bytes.length + 1).cast<Uint8>();
    buffer.asTypedList(bytes.length + 1)
      ..setAll(0, bytes)
      ..[bytes.length] = 0;
    return buffer;
  }

  static Pointer<Pointer<Uint8>> _stringArray(_Libc c, List<String> values) {
    final array = c.malloc((values.length + 1) * sizeOf<Pointer<Uint8>>()).cast<Pointer<Uint8>>();
    for (var index = 0; index < values.length; index++) {
      array[index] = _cString(c, values[index]);
    }
    array[values.length] = nullptr;
    return array;
  }

  static void _freeArray(_Libc c, Pointer<Pointer<Uint8>> array) {
    for (var index = 0; array[index] != nullptr; index++) {
      c.free(array[index].cast());
    }
    c.free(array.cast());
  }

  static String _readString(Pointer<Uint8> buffer) {
    var length = 0;
    while (buffer[length] != 0 && length < _pathMax) {
      length++;
    }
    return utf8.decode(buffer.asTypedList(length));
  }
}

/// A terminal that could not be opened at all, before anything ran in it.
///
/// Separate from a session that opened and was refused: this one never reached the far end, so
/// there is nothing of the far end's to quote.
class PtyRefused implements Exception {
  /// Constructor taking what could not be done.
  const PtyRefused(this.words);

  /// What went wrong, in words a person can act on.
  final String words;

  @override
  String toString() => words;
}

/// Runs its arguments with descriptor 3 closed to them, and writes what they exited with to it.
const String _reportsItsCode = r'"$@" 3>&-; s=$?; printf %d "$s" >&3; exit "$s"';

const int _oCloexec = 0x80000;
const int _enoent = 2;
const int _eacces = 13;
const int _oRdwr = 2;
const int _oNoctty = 0x100;
const int _spawnSetsid = 0x80;
const int _tiocswinsz = 0x5414;
const int _sighup = 1;
const int _sigkill = 9;
const int _tcgets = 0x5401;
const int _tcsets = 0x5402;
const int _echo = 0x8;
const int _echoNl = 0x40;
const int _pathMax = 4096;
const int _readChunk = 8192;

// Opaque to us, and larger than glibc needs, because guessing small is a memory error and
// guessing large is a few unused bytes.
const int _actionsBytes = 256;
const int _attributesBytes = 512;

/// The handful of libc calls a terminal is made of.
class _Libc {
  _Libc(DynamicLibrary library)
    : posixOpenpt = library.lookupFunction<Int32 Function(Int32), int Function(int)>('posix_openpt'),
      grantpt = library.lookupFunction<Int32 Function(Int32), int Function(int)>('grantpt'),
      unlockpt = library.lookupFunction<Int32 Function(Int32), int Function(int)>('unlockpt'),
      ptsnameR = library
          .lookupFunction<Int32 Function(Int32, Pointer<Void>, IntPtr), int Function(int, Pointer<Void>, int)>(
            'ptsname_r',
          ),
      ioctl = library
          .lookupFunction<Int32 Function(Int32, UnsignedLong, Pointer<Void>), int Function(int, int, Pointer<Void>)>(
            'ioctl',
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
      pipe2 = library.lookupFunction<Int32 Function(Pointer<Int32>, Int32), int Function(Pointer<Int32>, int)>('pipe2'),
      kill = library.lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>('kill'),
      waitpid = library
          .lookupFunction<Int32 Function(Int32, Pointer<Int32>, Int32), int Function(int, Pointer<Int32>, int)>(
            'waitpid',
          ),
      malloc = library.lookupFunction<Pointer<Void> Function(IntPtr), Pointer<Void> Function(int)>('malloc'),
      free = library.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('free'),
      posixSpawnp = library
          .lookupFunction<
            Int32 Function(
              Pointer<Int32>,
              Pointer<Void>,
              Pointer<Void>,
              Pointer<Void>,
              Pointer<Pointer<Uint8>>,
              Pointer<Pointer<Uint8>>,
            ),
            int Function(
              Pointer<Int32>,
              Pointer<Void>,
              Pointer<Void>,
              Pointer<Void>,
              Pointer<Pointer<Uint8>>,
              Pointer<Pointer<Uint8>>,
            )
          >('posix_spawnp'),
      fileActionsInit = library.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
        'posix_spawn_file_actions_init',
      ),
      fileActionsDestroy = library.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
        'posix_spawn_file_actions_destroy',
      ),
      addOpen = library
          .lookupFunction<
            Int32 Function(Pointer<Void>, Int32, Pointer<Void>, Int32, UnsignedInt),
            int Function(Pointer<Void>, int, Pointer<Void>, int, int)
          >('posix_spawn_file_actions_addopen'),
      addDup2 = library
          .lookupFunction<Int32 Function(Pointer<Void>, Int32, Int32), int Function(Pointer<Void>, int, int)>(
            'posix_spawn_file_actions_adddup2',
          ),
      addClose = library.lookupFunction<Int32 Function(Pointer<Void>, Int32), int Function(Pointer<Void>, int)>(
        'posix_spawn_file_actions_addclose',
      ),
      attributesInit = library.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
        'posix_spawnattr_init',
      ),
      attributesDestroy = library.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
        'posix_spawnattr_destroy',
      ),
      attributesSetFlags = library
          .lookupFunction<Int32 Function(Pointer<Void>, Int16), int Function(Pointer<Void>, int)>(
            'posix_spawnattr_setflags',
          );

  final int Function(int) posixOpenpt;
  final int Function(int) grantpt;
  final int Function(int) unlockpt;
  final int Function(int, Pointer<Void>, int) ptsnameR;
  final int Function(int, int, Pointer<Void>) ioctl;
  final int Function(int, Pointer<Uint8>, int) read;
  final int Function(int, Pointer<Uint8>, int) write;
  final int Function(int) close;
  final int Function(Pointer<Int32>, int) pipe2;
  final int Function(int, int) kill;
  final int Function(int, Pointer<Int32>, int) waitpid;
  final Pointer<Void> Function(int) malloc;
  final void Function(Pointer<Void>) free;
  final int Function(
    Pointer<Int32>,
    Pointer<Void>,
    Pointer<Void>,
    Pointer<Void>,
    Pointer<Pointer<Uint8>>,
    Pointer<Pointer<Uint8>>,
  )
  posixSpawnp;
  final int Function(Pointer<Void>) fileActionsInit;
  final int Function(Pointer<Void>) fileActionsDestroy;
  final int Function(Pointer<Void>, int, Pointer<Void>, int, int) addOpen;
  final int Function(Pointer<Void>, int, int) addDup2;
  final int Function(Pointer<Void>, int) addClose;
  final int Function(Pointer<Void>) attributesInit;
  final int Function(Pointer<Void>) attributesDestroy;
  final int Function(Pointer<Void>, int) attributesSetFlags;
}
