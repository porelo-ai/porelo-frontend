import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

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
///   waits for ever. The program is waited for on an isolate of its own, and when it has exited the
///   pseudoconsole is closed, which ends the output.
/// * **Closing from this side ends the way in, not the work.** Closing the pseudoconsole sends the
///   programs in it the event a console window closing sends, so `wsl.exe` or `ssh.exe` ends and
///   `tmux` inside the container goes on, as `SIGHUP` does on Linux.
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
    final handles = k.alloc(4 * sizeOf<IntPtr>()).cast<IntPtr>();
    // 0 and 1: the pseudoconsole reads what is typed from the first pipe; 2 and 3: it writes what
    // the program printed to the second.
    if (k.createPipe(handles, handles + 1, nullptr, 0) == 0 ||
        k.createPipe(handles + 2, handles + 3, nullptr, 0) == 0) {
      k.free(handles.cast());
      throw const PtyRefused('Windows would not open the pipes of a terminal');
    }
    final inputRead = handles[0], inputWrite = handles[1], outputRead = handles[2], outputWrite = handles[3];
    k.free(handles.cast());

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
      final closing = _Console(hpc, job);
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
    if (_shut) return;
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
    if (!_console.closed) _Kernel32().resizePseudoConsole(_console.handle, _coord(columns, rows));
  }

  @override
  Future<void> close() async {
    if (_shut) return;
    _shut = true;
    final k = _Kernel32();
    k.closeHandle(_input);
    // Ends `wsl.exe` or `ssh.exe` as a closing console window would; the reader then sees the end.
    _console.close();
  }

  /// Reads the output on one isolate and waits for the program on another.
  static void _pump(
    _Console console,
    int process,
    int outputRead,
    StreamController<List<int>> output,
    Completer<int> ended,
  ) {
    final port = ReceivePort();
    int? code;
    var drained = false;
    late final StreamSubscription<dynamic> listening;
    Future<void> finishWhenBoth() async {
      if (code == null || !drained) return;
      if (!ended.isCompleted) ended.complete(code);
      await output.close();
      await listening.cancel();
      port.close();
    }

    listening = port.listen((dynamic message) async {
      if (message is Uint8List) {
        if (!output.isClosed) output.add(message);
      } else if (message == _drained) {
        drained = true;
        await finishWhenBoth();
      } else if (message is int) {
        code = message;
        // The output ends only now: the program has exited, and the pseudoconsole lets go.
        console.close();
        await finishWhenBoth();
      }
    });
    unawaited(
      Isolate.spawn(_readUntilItEnds, <Object>[port.sendPort, outputRead]).catchError((Object _) {
        drained = true;
        return Isolate.current;
      }),
    );
    unawaited(
      Isolate.spawn(_waitForIt, <Object>[port.sendPort, process]).catchError((Object _) {
        if (!ended.isCompleted) ended.complete(-1);
        return Isolate.current;
      }),
    );
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

  static void _waitForIt(List<Object> arguments) {
    final send = arguments[0] as SendPort;
    final process = arguments[1] as int;
    final k = _Kernel32();
    k.waitForSingleObject(process, _infinite);
    final code = k.alloc(sizeOf<Uint32>()).cast<Uint32>();
    final got = k.getExitCodeProcess(process, code);
    final value = got == 0 ? -1 : code.value;
    k.free(code.cast());
    k.closeHandle(process);
    send.send(value);
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

/// A pseudoconsole, closed once: by this side, or when its program has exited.
class _Console {
  _Console(this.handle, this.job);

  final int handle;

  /// The job object its program is in, or 0. Closing it kills what is still in it.
  final int job;
  bool closed = false;

  void close() {
    if (closed) return;
    closed = true;
    final k = _Kernel32();
    k.closePseudoConsole(handle);
    if (job != 0) k.closeHandle(job);
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
  final int Function() getLastError;
  final int _heap;
  final Pointer<Void> Function(int, int, int) _heapAlloc;
  final int Function(int, int, Pointer<Void>) _heapFree;

  /// Zeroed memory from the process heap, which every structure here is expected to start as.
  Pointer<Void> alloc(int bytes) => _heapAlloc(_heap, _heapZeroMemory, bytes);

  void free(Pointer<Void> pointer) => _heapFree(_heap, 0, pointer);
}
