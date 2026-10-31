import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'pty.dart';

/// A Windows pseudoconsole, opened and driven with `dart:ffi` against `kernel32`: the terminal of
/// a task on Windows, behind the same seam as [Pty] on Linux.
///
/// What runs in it is `wsl.exe` or `ssh.exe`, and what they reach is the task's `tmux` on a Linux
/// machine. So the terminal's bytes are the far end's, as on Linux; Windows only carries them.
///
/// Four things about it are not obvious and all are deliberate:
///
/// * **What runs in it ends with it.** On Windows a child does not end with its parent, so the
///   program is put in a job object that kills what is in it when its last handle closes: when the
///   session ends, and when the interface itself ends, however it ends.
///
/// * **The output ends only when the pseudoconsole is closed.** A pseudoconsole keeps its output
///   pipe open after the program in it has exited, so a reader waiting for the end of the pipe
///   waits for ever. The program, and every process in its job, is waited for on an isolate of its
///   own, and when they have exited the pseudoconsole is closed, which ends the output.
/// * **Closing from this side ends the way in, not the work.** It ends every process in the job,
///   so `wsl.exe` or `ssh.exe` ends and `tmux` inside the container goes on, as `SIGHUP` does on
///   Linux; the pseudoconsole is closed only after, as closing it first waits on what still runs.
/// * **The command line is quoted as the C runtime reads it back.** `CreateProcessW` takes one
///   string, and each program splits it again; [windowsCommandLine] writes what the Microsoft C
///   runtime, which `wsl.exe` and `ssh.exe` use, splits into the same arguments.
class ConPty implements SessionChannel {
  ConPty._(this._console, this._input, this._output, this._ended);

  /// Starts [executable] with [arguments] in a pseudoconsole of the given size.
  ///
  /// [environment] is not passed on: what runs here is `wsl.exe` or `ssh.exe`, and the far end's
  /// environment is the far end's.
  factory ConPty.start(
    String executable,
    List<String> arguments, {
    int columns = 80,
    int rows = 24,
    Map<String, String> environment = const <String, String>{},
  }) {
    final k = _Kernel32();
    // The first pipe: the pseudoconsole reads what is typed from it; the second: it writes what the program printed.
    final pipes = openPipes(() {
      final ends = k.alloc(2 * sizeOf<IntPtr>()).cast<IntPtr>();
      try {
        return k.createPipe(ends, ends + 1, nullptr, 0) == 0 ? null : (read: ends[0], write: ends[1]);
      } finally {
        k.free(ends.cast());
      }
    }, (handle) => k.closeHandle(handle));
    if (pipes == null) throw const PtyRefused('Windows would not open the pipes of a terminal');
    final (input: (read: inputRead, write: inputWrite), output: (read: outputRead, write: outputWrite)) = pipes;

    final console = k.alloc(sizeOf<IntPtr>()).cast<IntPtr>();
    final made = k.createPseudoConsole(_coord(columns, rows), inputRead, outputWrite, 0, console);
    // The pseudoconsole holds its own ends now.
    k.closeHandle(inputRead);
    k.closeHandle(outputWrite);
    final hpc = console.value;
    k.free(console.cast());
    if (made != 0) {
      k.closeHandle(inputWrite);
      k.closeHandle(outputRead);
      throw PtyRefused('Windows would not open a terminal (error ${made.toRadixString(16)})');
    }

    // Asked once for its size, which is the call's documented way to fail, then made.
    final listSize = k.alloc(sizeOf<IntPtr>()).cast<IntPtr>();
    k.initializeProcThreadAttributeList(nullptr, 1, 0, listSize);
    final list = k.alloc(listSize.value);
    final startup = k.alloc(_startupInfoExBytes);
    final information = k.alloc(_processInformationBytes);
    final line = _wide(k, windowsCommandLine(<String>[executable, ...arguments]));
    var listMade = false;
    try {
      listMade = k.initializeProcThreadAttributeList(list, 1, 0, listSize) != 0;
      // The pseudoconsole's handle itself is the attribute's value, not a pointer to it.
      if (!listMade ||
          k.updateProcThreadAttribute(
                list,
                0,
                _attributePseudoConsole,
                Pointer<Void>.fromAddress(hpc),
                sizeOf<IntPtr>(),
                nullptr,
                nullptr,
              ) ==
              0) {
        k.closePseudoConsole(hpc);
        k.closeHandle(inputWrite);
        k.closeHandle(outputRead);
        throw const PtyRefused('Windows would not give the program its terminal');
      }
      final bytes = startup.cast<Uint8>();
      bytes.cast<Uint32>().value = _startupInfoExBytes;
      // STARTF_USESTDHANDLES with no handles: the program is given the pseudoconsole and nothing of
      // this process's own standard handles.
      (bytes + _startupFlagsOffset).cast<Uint32>().value = _startfUseStdHandles;
      (bytes + _attributeListOffset).cast<IntPtr>().value = list.address;

      final started = k.createProcess(
        nullptr,
        line,
        nullptr,
        nullptr,
        0,
        _extendedStartupInfoPresent,
        nullptr,
        nullptr,
        startup,
        information,
      );
      if (started == 0) {
        final error = k.getLastError();
        k.closePseudoConsole(hpc);
        k.closeHandle(inputWrite);
        k.closeHandle(outputRead);
        throw PtyRefused(switch (error) {
          _errorFileNotFound => 'there is no `$executable` on this computer',
          _errorAccessDenied => '`$executable` is there and cannot be run',
          _ => 'Windows would not start `$executable` (error $error)',
        });
      }
      final process = information.cast<IntPtr>().value;
      // The thread's handle is not needed; the process's is waited for and closed by the waiter.
      k.closeHandle(information.cast<IntPtr>()[1]);
      final job = _killedWithUs(k, process);

      final output = StreamController<List<int>>.broadcast();
      final ended = Completer<int>();
      final closing = _Console(
        hpc,
        job,
        ConsoleRelease(
          closeInput: () => _Kernel32().closeHandle(inputWrite),
          endJob: job == 0 ? null : () => _Kernel32().terminateJobObject(job, _closedFromHere) != 0,
          closeJob: () {
            if (job != 0) _Kernel32().closeHandle(job);
          },
          closeConsole: () => _Kernel32().closePseudoConsole(hpc),
          closeConsoleAway: () => _closeAway(hpc),
        ),
      );
      _pump(closing, process, outputRead, output, ended);
      return ConPty._(closing, inputWrite, output, ended.future);
    } finally {
      if (listMade) k.deleteProcThreadAttributeList(list);
      k.free(listSize.cast());
      k.free(list);
      k.free(startup);
      k.free(information);
      k.free(line.cast());
    }
  }

  final _Console _console;
  final int _input;
  final StreamController<List<int>> _output;
  final Future<int> _ended;
  bool _shut = false;

  @override
  Stream<List<int>> get output => _output.stream;

  @override
  Future<int> get ended => _ended;

  /// Sends input to the far end, all of it: `WriteFile` on a pipe may take part of it.
  @override
  void send(String input) {
    if (_shut || _console.release.inputEnded) return;
    final k = _Kernel32();
    final bytes = utf8.encode(input);
    final buffer = k.alloc(bytes.length).cast<Uint8>();
    buffer.asTypedList(bytes.length).setAll(0, bytes);
    final written = k.alloc(sizeOf<Uint32>()).cast<Uint32>();
    var sent = 0;
    var attemptsLeft = 1000;
    while (sent < bytes.length && attemptsLeft-- > 0) {
      if (k.writeFile(_input, (buffer + sent).cast(), bytes.length - sent, written, nullptr) == 0) break;
      sent += written.value;
    }
    k.free(written.cast());
    k.free(buffer.cast());
  }

  @override
  void resize({required int columns, required int rows}) {
    if (_shut) return;
    if (!_console.release.closing) _Kernel32().resizePseudoConsole(_console.handle, _coord(columns, rows));
  }

  Future<void>? _closing;

  /// Ends the program from this side and waits for it to end, as [Pty] does; past the bound it is still running.
  @override
  Future<void> close() => _closing ??= letGoAndWait(() {
    _shut = true;
    _console.release.endInput();
    // Ends `wsl.exe` or `ssh.exe` and whatever they started; the waiter then sees the end and closes the console.
    return _console.release.letGo();
  }, _ended);

  /// Lets go of a program's console with [letGo], then waits for it to have [ended] within [bound], counted from
  /// before [letGo], which may take long.
  ///
  /// Throws a [TerminalStillRunning] past it: a console closed is not a program ended, and what it does meanwhile
  /// still happens.
  @visibleForTesting
  static Future<void> letGoAndWait(Future<void> Function() letGo, Future<int> ended, {Duration bound = closeBound}) {
    final waited = endedAfterClose(ended, ended, bound: bound);
    // Not waited on: the bound alone says how long the program has, and a console that did not close leaves it running.
    unawaited(Future.sync(letGo).then<void>((_) {}, onError: (Object _) {}));
    return waited;
  }

  /// Closes the pseudoconsole [handle] on an isolate of its own, as closing it waits on what still runs in it.
  static Future<void> _closeAway(int handle) => Isolate.run(() => _Kernel32().closePseudoConsole(handle));

  /// Reads the output on one isolate and waits for the program on another.
  static void _pump(
    _Console console,
    int process,
    int outputRead,
    StreamController<List<int>> output,
    Completer<int> ended,
  ) => watch(
    closeConsole: () {
      console.release.close();
      // Asked for no more: the program and all it started have ended.
      _Kernel32().closeHandle(process);
    },
    output: output,
    ended: ended,
    // A reader that dies, whatever it posted last, says so on the same port, after its output, as null.
    read: (to) => Isolate.spawn(_readUntilItEnds, <Object>[to, outputRead], onExit: to).catchError((Object error) {
      // Nothing reads the output: closed, so the console writes into nothing rather than blocking.
      _Kernel32().closeHandle(outputRead);
      throw error;
    }),
    // A waiter that fails after it started says so on the same port, as its error and stack.
    wait: (to) => Isolate.spawn(_waitForIt, <Object>[to, process, console.job], onError: to),
    endedNow: () => _endedNow(_Kernel32(), process, console.job),
  );

  /// Ends [output] and completes [ended] from what [read] and [wait] post, each from an isolate it starts.
  ///
  /// Where [wait] cannot start, or fails after it started (an error posted as a list of two strings, as an isolate's
  /// `onError` port receives it), the program is asked for here every [poll] through [endedNow], its exit code once
  /// every process of it has ended, and counts as running until then; where [read] cannot start, its end is not waited
  /// for, nor where its isolate ended (null posted, as an isolate's `onExit` port receives it) without saying the output
  /// ended. A throw while asking or closing counts as still running, never as an error nobody handles.
  @visibleForTesting
  static void watch({
    required void Function() closeConsole,
    required StreamController<List<int>> output,
    required Completer<int> ended,
    required Future<Object?> Function(SendPort to) read,
    required Future<Object?> Function(SendPort to) wait,
    required int? Function() endedNow,
    Duration poll = const Duration(milliseconds: 100),
  }) {
    final port = ReceivePort();
    int? code;
    var drained = false;
    Timer? asking;
    late final StreamSubscription<dynamic> listening;
    Future<void> finishWhenBoth() async {
      if (code == null || !drained) return;
      if (!ended.isCompleted) ended.complete(code);
      await output.close();
      await listening.cancel();
      port.close();
    }

    void askHere() {
      // Nothing waits for the program: it is asked for here, and counts as running until it is seen gone.
      if (code != null || asking != null) return;
      asking = Timer.periodic(poll, (_) {
        int? value;
        try {
          value = endedNow();
        } on Object {
          // Not known: still running, asked again at the next poll.
          value = null;
        }
        if (value != null) port.sendPort.send(value);
      });
    }

    listening = port.listen((dynamic message) async {
      try {
        if (message is Uint8List) {
          if (!output.isClosed) output.add(message);
        } else if (message == _drained || message == null) {
          drained = true;
          await finishWhenBoth();
        } else if (message is int && code == null) {
          asking?.cancel();
          code = message;
          try {
            // The output ends only now: the program has exited, and the pseudoconsole lets go.
            closeConsole();
          } on Object {
            // Its end was seen all the same; what could not be closed is not waited on.
          }
          await finishWhenBoth();
        } else if (message is List) {
          askHere();
        }
      } on Object {
        // A message that could not be taken leaves the program counted as running until its end is seen.
      }
    });
    unawaited(
      read(port.sendPort).then<void>(
        (_) {},
        onError: (Object _) async {
          drained = true;
          await finishWhenBoth();
        },
      ),
    );
    unawaited(wait(port.sendPort).then<void>((_) {}, onError: (Object _) => askHere()));
  }

  static void _readUntilItEnds(List<Object> arguments) {
    final send = arguments[0] as SendPort;
    final pipe = arguments[1] as int;
    final k = _Kernel32();
    final buffer = k.alloc(_readChunk).cast<Uint8>();
    final read = k.alloc(sizeOf<Uint32>()).cast<Uint32>();
    try {
      while (k.readFile(pipe, buffer.cast(), _readChunk, read, nullptr) != 0 && read.value > 0) {
        send.send(Uint8List.fromList(buffer.asTypedList(read.value)));
      }
    } finally {
      k.closeHandle(pipe);
      k.free(read.cast());
      k.free(buffer.cast());
      send.send(_drained);
    }
  }

  /// Waits for the program and every process it started in its job, then posts its exit code.
  static void _waitForIt(List<Object> arguments) {
    final send = arguments[0] as SendPort;
    final process = arguments[1] as int;
    final job = arguments[2] as int;
    final k = _Kernel32();
    k.waitForSingleObject(process, _infinite);
    send.send(waitUntilEnded(() => _endedNow(k, process, job), () => k.sleep(_pollMilliseconds)));
  }

  /// Asks [endedNow] until it answers an exit code, with a [pause] between.
  @visibleForTesting
  static int waitUntilEnded(int? Function() endedNow, void Function() pause) {
    while (true) {
      if (endedNow() case final code?) return code;
      pause();
    }
  }

  /// The program's exit code once it and every process in its [job] have ended, or null while one runs; -1 for an
  /// exit code Windows would not give.
  static int? _endedNow(_Kernel32 k, int process, int job) => endedFrom(
    processEnded: () => k.waitForSingleObject(process, 0) == _waitObject0,
    activeInJob: job == 0
        ? null
        : () {
            final accounting = k.alloc(_basicAccountingBytes);
            try {
              if (k.queryInformationJobObject(
                    job,
                    _basicAccountingInformation,
                    accounting,
                    _basicAccountingBytes,
                    nullptr,
                  ) ==
                  0) {
                return null;
              }
              return (accounting.cast<Uint8>() + _activeProcessesOffset).cast<Uint32>().value;
            } finally {
              k.free(accounting);
            }
          },
    exitCode: () {
      final code = k.alloc(sizeOf<Uint32>()).cast<Uint32>();
      try {
        return k.getExitCodeProcess(process, code) == 0 ? -1 : code.value;
      } finally {
        k.free(code.cast());
      }
    },
  );

  /// The program's [exitCode] once it [processEnded] and no process is [activeInJob], or null while one runs.
  ///
  /// [activeInJob] is null where the program is in no job; it answers null where the job cannot be asked, and the
  /// program's own handle alone then says whether it ended: a job that is never answered would hold its end for good.
  @visibleForTesting
  static int? endedFrom({
    required bool Function() processEnded,
    required int? Function()? activeInJob,
    required int Function() exitCode,
  }) {
    if (!processEnded()) return null;
    if (activeInJob?.call() case final active? when active != 0) return null;
    return exitCode();
  }

  /// The two pipes of a terminal, each made by [pipe], null where it could not make one; a pipe made before one that
  /// failed is closed with [close].
  @visibleForTesting
  static ({({int read, int write}) input, ({int read, int write}) output})? openPipes(
    ({int read, int write})? Function() pipe,
    void Function(int handle) close,
  ) {
    final input = pipe();
    if (input == null) return null;
    final output = pipe();
    if (output == null) {
      close(input.read);
      close(input.write);
      return null;
    }
    return (input: input, output: output);
  }

  /// A job object that kills [process], and whatever it starts, when the job's handle closes; 0
  /// where Windows would not make one, and the program then only ends as its console closes.
  static int _killedWithUs(_Kernel32 k, int process) {
    final job = k.createJobObject(nullptr, nullptr);
    if (job == 0) return 0;
    final limits = k.alloc(_extendedLimitBytes);
    (limits.cast<Uint8>() + _limitFlagsOffset).cast<Uint32>().value = _killOnJobClose;
    final set = k.setInformationJobObject(job, _extendedLimitInformation, limits, _extendedLimitBytes);
    k.free(limits);
    if (set == 0 || k.assignProcessToJobObject(job, process) == 0) {
      k.closeHandle(job);
      return 0;
    }
    return job;
  }

  /// A `COORD` passed by value: columns in the low half, rows in the high.
  static int _coord(int columns, int rows) => (rows & 0xffff) << 16 | (columns & 0xffff);

  static Pointer<Uint16> _wide(_Kernel32 k, String value) {
    final units = value.codeUnits;
    final buffer = k.alloc((units.length + 1) * 2).cast<Uint16>();
    buffer.asTypedList(units.length + 1)
      ..setAll(0, units)
      ..[units.length] = 0;
    return buffer;
  }
}

/// A pseudoconsole, closed once its program has ended.
class _Console {
  _Console(this.handle, this.job, this.release);

  final int handle;

  /// The job object its program is in, or 0. Closing it kills what is still in it.
  final int job;

  /// How it is let go and closed.
  final ConsoleRelease release;
}

/// How a pseudoconsole is let go from this side and closed once its program ended, apart from the Windows calls it is
/// made of.
@visibleForTesting
class ConsoleRelease {
  /// Takes the calls: [endJob] null where the program is in no job; [lastResort] is how long a console whose close on
  /// an isolate of its own failed is left before it is closed on this one.
  ConsoleRelease({
    required this.closeInput,
    required this.endJob,
    required this.closeJob,
    required this.closeConsole,
    required this.closeConsoleAway,
    this.lastResort = closeBound,
  });

  /// Closes the way input reaches the console.
  final void Function() closeInput;

  /// Ends every process in the job, which does not block; false where Windows would not.
  final bool Function()? endJob;

  /// Closes the job's handle, which ends whatever is still in it.
  final void Function() closeJob;

  /// Closes the console on this isolate, which waits on what still runs in it.
  final void Function() closeConsole;

  /// Closes the console on an isolate of its own.
  final Future<void> Function() closeConsoleAway;

  /// How long a console whose close away failed is left before it is closed here: past the close's bound, so whoever
  /// waits on it was told the program still runs before this isolate may wait on it.
  final Duration lastResort;

  /// Whether the console is closed.
  bool closed = false;

  bool _closingAway = false;
  bool _jobClosed = false;

  /// Whether the console is closed or being closed, so nothing more is asked of it.
  bool get closing => closed || _closingAway;

  /// Whether the way input reaches the console is closed.
  bool get inputEnded => _inputEnded;
  bool _inputEnded = false;

  /// Closes the way input reaches the console, once.
  void endInput() {
    if (_inputEnded) return;
    _inputEnded = true;
    closeInput();
  }

  /// Ends the program from this side: every process in its job, which does not block, so closing the console after
  /// it waits on nothing. Without a job, or where ending it failed, only closing the console ends it, which may block,
  /// so it is closed on an isolate of its own, and counted closed only once it was; where that failed, it is closed on
  /// this isolate after [lastResort]. The job stays open for the waiter that asks it.
  Future<void> letGo() async {
    if (closing) return;
    if (endJob?.call() ?? false) return;
    _closingAway = true;
    try {
      await closeConsoleAway();
      closed = true;
    } on Object {
      await Future<void>.delayed(lastResort);
      if (!closed) {
        closed = true;
        closeConsole();
      }
    } finally {
      _closingAway = false;
    }
  }

  /// Once the program's end was seen: closes the input and the job, ending whatever is still in it, then the console,
  /// unless it is being closed away already, which closes it either way.
  void close() {
    endInput();
    if (!_jobClosed) {
      _jobClosed = true;
      closeJob();
    }
    if (closing) return;
    closed = true;
    closeConsole();
  }
}

/// [arguments] as one Windows command line, quoted so that the Microsoft C runtime splits it back
/// into exactly these arguments.
///
/// An argument with no space, tab, newline or quote is written as it is. Any other is put in
/// quotes; a quote in it is preceded by a backslash, and backslashes are doubled where they come
/// before a quote or before the closing one, because only there does the runtime read them as an
/// escape.
String windowsCommandLine(List<String> arguments) => arguments.map(_quoted).join(' ');

String _quoted(String argument) {
  if (argument.isNotEmpty && !argument.contains(RegExp('[ \t\n\v"]'))) return argument;
  final quoted = StringBuffer('"');
  var backslashes = 0;
  for (final unit in argument.split('')) {
    if (unit == r'\') {
      backslashes++;
      continue;
    }
    if (unit == '"') {
      quoted.write(r'\' * (backslashes * 2 + 1));
    } else {
      quoted.write(r'\' * backslashes);
    }
    backslashes = 0;
    quoted.write(unit);
  }
  quoted
    ..write(r'\' * (backslashes * 2))
    ..write('"');
  return quoted.toString();
}

/// Sent by the reader when the output has ended.
const String _drained = 'drained';

const int _readChunk = 8192;
const int _infinite = 0xFFFFFFFF;
const int _waitObject0 = 0;
const int _pollMilliseconds = 50;

/// The exit code of a program ended from this side, as on Linux: 128 and the hang-up signal.
const int _closedFromHere = 129;

// JOBOBJECT_BASIC_ACCOUNTING_INFORMATION: four LARGE_INTEGER times, then four DWORDs, ActiveProcesses the third.
const int _basicAccountingInformation = 1;
const int _basicAccountingBytes = 48;
const int _activeProcessesOffset = 40;
const int _attributePseudoConsole = 0x00020016;
const int _extendedStartupInfoPresent = 0x00080000;
const int _startfUseStdHandles = 0x00000100;
const int _errorFileNotFound = 2;
const int _errorAccessDenied = 5;
const int _heapZeroMemory = 0x00000008;

// JOBOBJECT_EXTENDED_LIMIT_INFORMATION on 64-bit Windows, and its LimitFlags after two LARGE_INTEGERs.
const int _extendedLimitInformation = 9;
const int _extendedLimitBytes = 144;
const int _limitFlagsOffset = 16;
const int _killOnJobClose = 0x00002000;

// STARTUPINFOEXW on 64-bit Windows: STARTUPINFOW is 104 bytes, its dwFlags at 60, and the
// attribute list's pointer follows it.
const int _startupInfoExBytes = 112;
const int _startupFlagsOffset = 60;
const int _attributeListOffset = 104;
// PROCESS_INFORMATION: two handles and two ids.
const int _processInformationBytes = 24;

/// The handful of `kernel32` calls a pseudoconsole is made of.
class _Kernel32 {
  factory _Kernel32() => _instance ??= _Kernel32._(DynamicLibrary.open('kernel32.dll'));

  _Kernel32._(DynamicLibrary k)
    : createPipe = k
          .lookupFunction<
            Int32 Function(Pointer<IntPtr>, Pointer<IntPtr>, Pointer<Void>, Uint32),
            int Function(Pointer<IntPtr>, Pointer<IntPtr>, Pointer<Void>, int)
          >('CreatePipe'),
      createPseudoConsole = k
          .lookupFunction<
            Int32 Function(Uint32, IntPtr, IntPtr, Uint32, Pointer<IntPtr>),
            int Function(int, int, int, int, Pointer<IntPtr>)
          >('CreatePseudoConsole'),
      resizePseudoConsole = k.lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
        'ResizePseudoConsole',
      ),
      closePseudoConsole = k.lookupFunction<Void Function(IntPtr), void Function(int)>('ClosePseudoConsole'),
      initializeProcThreadAttributeList = k
          .lookupFunction<
            Int32 Function(Pointer<Void>, Uint32, Uint32, Pointer<IntPtr>),
            int Function(Pointer<Void>, int, int, Pointer<IntPtr>)
          >('InitializeProcThreadAttributeList'),
      updateProcThreadAttribute = k
          .lookupFunction<
            Int32 Function(Pointer<Void>, Uint32, IntPtr, Pointer<Void>, IntPtr, Pointer<Void>, Pointer<IntPtr>),
            int Function(Pointer<Void>, int, int, Pointer<Void>, int, Pointer<Void>, Pointer<IntPtr>)
          >('UpdateProcThreadAttribute'),
      deleteProcThreadAttributeList = k.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
        'DeleteProcThreadAttributeList',
      ),
      createProcess = k
          .lookupFunction<
            Int32 Function(
              Pointer<Uint16>,
              Pointer<Uint16>,
              Pointer<Void>,
              Pointer<Void>,
              Int32,
              Uint32,
              Pointer<Void>,
              Pointer<Uint16>,
              Pointer<Void>,
              Pointer<Void>,
            ),
            int Function(
              Pointer<Uint16>,
              Pointer<Uint16>,
              Pointer<Void>,
              Pointer<Void>,
              int,
              int,
              Pointer<Void>,
              Pointer<Uint16>,
              Pointer<Void>,
              Pointer<Void>,
            )
          >('CreateProcessW'),
      readFile = k
          .lookupFunction<
            Int32 Function(IntPtr, Pointer<Void>, Uint32, Pointer<Uint32>, Pointer<Void>),
            int Function(int, Pointer<Void>, int, Pointer<Uint32>, Pointer<Void>)
          >('ReadFile'),
      writeFile = k
          .lookupFunction<
            Int32 Function(IntPtr, Pointer<Void>, Uint32, Pointer<Uint32>, Pointer<Void>),
            int Function(int, Pointer<Void>, int, Pointer<Uint32>, Pointer<Void>)
          >('WriteFile'),
      waitForSingleObject = k.lookupFunction<Uint32 Function(IntPtr, Uint32), int Function(int, int)>(
        'WaitForSingleObject',
      ),
      getExitCodeProcess = k
          .lookupFunction<Int32 Function(IntPtr, Pointer<Uint32>), int Function(int, Pointer<Uint32>)>(
            'GetExitCodeProcess',
          ),
      closeHandle = k.lookupFunction<Int32 Function(IntPtr), int Function(int)>('CloseHandle'),
      createJobObject = k
          .lookupFunction<
            IntPtr Function(Pointer<Void>, Pointer<Uint16>),
            int Function(Pointer<Void>, Pointer<Uint16>)
          >('CreateJobObjectW'),
      setInformationJobObject = k
          .lookupFunction<
            Int32 Function(IntPtr, Int32, Pointer<Void>, Uint32),
            int Function(int, int, Pointer<Void>, int)
          >('SetInformationJobObject'),
      assignProcessToJobObject = k.lookupFunction<Int32 Function(IntPtr, IntPtr), int Function(int, int)>(
        'AssignProcessToJobObject',
      ),
      terminateJobObject = k.lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
        'TerminateJobObject',
      ),
      queryInformationJobObject = k
          .lookupFunction<
            Int32 Function(IntPtr, Int32, Pointer<Void>, Uint32, Pointer<Uint32>),
            int Function(int, int, Pointer<Void>, int, Pointer<Uint32>)
          >('QueryInformationJobObject'),
      sleep = k.lookupFunction<Void Function(Uint32), void Function(int)>('Sleep'),
      getLastError = k.lookupFunction<Uint32 Function(), int Function()>('GetLastError'),
      _heap = k.lookupFunction<IntPtr Function(), int Function()>('GetProcessHeap')(),
      _heapAlloc = k
          .lookupFunction<Pointer<Void> Function(IntPtr, Uint32, IntPtr), Pointer<Void> Function(int, int, int)>(
            'HeapAlloc',
          ),
      _heapFree = k
          .lookupFunction<Int32 Function(IntPtr, Uint32, Pointer<Void>), int Function(int, int, Pointer<Void>)>(
            'HeapFree',
          );

  static _Kernel32? _instance;

  final int Function(Pointer<IntPtr>, Pointer<IntPtr>, Pointer<Void>, int) createPipe;
  final int Function(int, int, int, int, Pointer<IntPtr>) createPseudoConsole;
  final int Function(int, int) resizePseudoConsole;
  final void Function(int) closePseudoConsole;
  final int Function(Pointer<Void>, int, int, Pointer<IntPtr>) initializeProcThreadAttributeList;
  final int Function(Pointer<Void>, int, int, Pointer<Void>, int, Pointer<Void>, Pointer<IntPtr>)
  updateProcThreadAttribute;
  final void Function(Pointer<Void>) deleteProcThreadAttributeList;
  final int Function(
    Pointer<Uint16>,
    Pointer<Uint16>,
    Pointer<Void>,
    Pointer<Void>,
    int,
    int,
    Pointer<Void>,
    Pointer<Uint16>,
    Pointer<Void>,
    Pointer<Void>,
  )
  createProcess;
  final int Function(int, Pointer<Void>, int, Pointer<Uint32>, Pointer<Void>) readFile;
  final int Function(int, Pointer<Void>, int, Pointer<Uint32>, Pointer<Void>) writeFile;
  final int Function(int, int) waitForSingleObject;
  final int Function(int, Pointer<Uint32>) getExitCodeProcess;
  final int Function(int) closeHandle;
  final int Function(Pointer<Void>, Pointer<Uint16>) createJobObject;
  final int Function(int, int, Pointer<Void>, int) setInformationJobObject;
  final int Function(int, int) assignProcessToJobObject;
  final int Function(int, int) terminateJobObject;
  final int Function(int, int, Pointer<Void>, int, Pointer<Uint32>) queryInformationJobObject;
  final void Function(int) sleep;
  final int Function() getLastError;
  final int _heap;
  final Pointer<Void> Function(int, int, int) _heapAlloc;
  final int Function(int, int, Pointer<Void>) _heapFree;

  /// Zeroed memory from the process heap, which every structure here is expected to start as.
  Pointer<Void> alloc(int bytes) => _heapAlloc(_heap, _heapZeroMemory, bytes);

  void free(Pointer<Void> pointer) => _heapFree(_heap, 0, pointer);
}
