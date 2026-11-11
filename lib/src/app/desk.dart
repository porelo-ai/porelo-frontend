import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:porelo_frontend/src/client/environment.dart';

/// Runs a program and answers what it printed. Injectable, so a test records what would run.
typedef RunProgram = Future<ProcessResult> Function(String executable, List<String> arguments);

/// Starts a program that outlives nothing here and is not waited for. Injectable likewise.
typedef StartDetached = Future<void> Function(String executable, List<String> arguments);

/// Starts an opener and answers its exit code and what it said on standard error, without waiting for what it opened.
/// Injectable likewise, so no test runs the desktop's opener.
typedef OpenAndWait = Future<ProcessResult> Function(String executable, List<String> arguments);

/// What differs between the desktops the interface runs on: where its own files are kept, how a
/// file is kept to its owner, and how a file or an address is opened.
///
/// **One place for it, so the rest of the interface never asks which system it is on.** On Linux
/// the folders are the XDG ones and the opener is `xdg-open`. On Windows the folders are under the
/// user's profile, read from `APPDATA` and `LOCALAPPDATA`, and a file is opened through the shell's
/// own file association, never through a command line that a shell would read.
///
/// The paths that name the far side of a connection, `/run/user/…` on a Linux machine, are not
/// here: they are the machine's, whatever this computer is.
abstract class Desk {
  /// Constructor taking the environment and, for a test, how a program is run and one started.
  Desk(this.environment, {RunProgram? run, StartDetached? startDetached, OpenAndWait? openAndWait})
    : run = run ?? Process.run,
      startDetached = startDetached ?? _detached,
      openAndWait = openAndWait ?? runOpener;

  /// The desk for [operatingSystem], as `Platform.operatingSystem` names it.
  factory Desk.of(
    String operatingSystem,
    Map<String, String> environment, {
    RunProgram? run,
    StartDetached? startDetached,
    OpenAndWait? openAndWait,
  }) => operatingSystem == 'windows'
      ? WindowsDesk(environment, run: run, startDetached: startDetached, openAndWait: openAndWait)
      : LinuxDesk(environment, run: run, startDetached: startDetached, openAndWait: openAndWait);

  /// The environment the folders are read from.
  final Map<String, String> environment;

  /// How a program is run, to set a file's rights.
  final RunProgram run;

  /// How a program is started without waiting for it, to open a file or an address.
  final StartDetached startDetached;

  /// How the opener is run where its answer is said, as for a log file.
  final OpenAndWait openAndWait;

  /// Whether this is Windows.
  bool get isWindows;

  /// The user's home, where `.ssh` is: `HOME` on Linux, the profile folder on Windows.
  String get home;

  /// Where the interface keeps what a person configured, `frontend.json` among it: the folder
  /// `porelo` under the user's configuration folder.
  String get configuration;

  /// Where the interface keeps what it recorded itself, the operations record among it.
  String get state;

  /// Where the interface keeps working folders and other data of its own.
  String get data;

  /// Joins [parts] with this system's separator.
  String join(List<String> parts) => parts.join(isWindows ? r'\' : '/');

  /// Expands this person's `~` or `~/` path; named users are not understood.
  String expandHome(String path) {
    if (path == '~') return home;
    if (path.startsWith('~/')) return join([home, ...path.substring(2).split('/')]);
    if (path.startsWith('~')) {
      throw FormatException('Cannot use ${path.split('/').first}; only ~/ is understood.');
    }
    return path;
  }

  /// Keeps [path] to its owner: nobody else on this computer reads it.
  Future<void> keepPrivate(String path, {bool directory = false}) async {
    final command = privateCommand(path, directory: directory);
    if (command != null) await run(command.first, command.sublist(1));
  }

  /// The program and arguments that keep [path] to its owner here, or null where nothing can.
  List<String>? privateCommand(String path, {bool directory = false});

  /// Opens [target], a file or a web address, with whatever this desktop opens it with. Quiet where
  /// nothing opens it: the target is on screen to be opened by hand.
  Future<void> open(String target) async {
    final command = openCommand(target);
    try {
      await startDetached(command.first, command.sublist(1));
    } on ProcessException {
      // No opener on this desktop.
    }
  }

  /// The program and arguments that open [target] here.
  List<String> openCommand(String target);

  /// Opens the file at [path] with whatever this desktop opens it with, and answers why it could not, or null once the
  /// opener took it.
  Future<String?> openFile(String path) async {
    final command = openCommand(path);
    try {
      final result = await openAndWait(command.first, command.sublist(1));
      if (result.exitCode == 0) return null;
      final said = '${result.stderr}'.trim();
      return '${command.first} ended with exit code ${result.exitCode}${said.isEmpty ? '' : ': $said'}';
    } on ProcessException catch (failure) {
      return '${command.first} could not be started: ${failure.message}';
    }
  }

  /// [name]'s value, or null when it is unset or empty, without a trailing separator.
  String? _set(String name) {
    final value = setIn(name, environment);
    if (value == null || !isWindows) return value;
    return value.length > 3 && value.endsWith(r'\') ? value.substring(0, value.length - 1) : value;
  }

  static Future<void> _detached(String executable, List<String> arguments) async {
    await Process.start(executable, arguments, mode: ProcessStartMode.detached);
  }
}

/// Linux: the XDG folders, `chmod`, and `xdg-open`.
class LinuxDesk extends Desk {
  /// Constructor taking the environment and, for a test, how programs are run.
  LinuxDesk(super.environment, {super.run, super.startDetached, super.openAndWait});

  String get _home => _set('HOME') ?? '.';

  @override
  bool get isWindows => false;

  @override
  String get home => _set('HOME') ?? '';

  @override
  String get configuration => '${_set('XDG_CONFIG_HOME') ?? '$_home/.config'}/porelo';

  @override
  String get state => '${_set('XDG_STATE_HOME') ?? '$_home/.local/state'}/porelo';

  @override
  String get data => '${_set('XDG_DATA_HOME') ?? '$_home/.local/share'}/porelo-frontend';

  @override
  List<String> privateCommand(String path, {bool directory = false}) => <String>[
    'chmod',
    directory ? '700' : '600',
    path,
  ];

  @override
  List<String> openCommand(String target) => <String>['xdg-open', target];
}

/// Windows: the folders under the user's profile, `icacls`, and the shell's file association.
class WindowsDesk extends Desk {
  /// Constructor taking the environment and, for a test, how programs are run.
  WindowsDesk(super.environment, {super.run, super.startDetached, super.openAndWait});

  String get _profile => _set('USERPROFILE') ?? '.';

  String get _roaming => _set('APPDATA') ?? '$_profile\\AppData\\Roaming';

  String get _local => _set('LOCALAPPDATA') ?? '$_profile\\AppData\\Local';

  @override
  bool get isWindows => true;

  @override
  String get home => _set('USERPROFILE') ?? '';

  @override
  String get configuration => '$_roaming\\porelo';

  @override
  String get state => '$_local\\porelo';

  @override
  String get data => '$_local\\porelo-frontend';

  /// The profile's folders are the user's already. Inheritance is cut and the user alone is
  /// granted the file, so a file copied or moved elsewhere keeps to its owner too.
  @override
  List<String>? privateCommand(String path, {bool directory = false}) {
    final user = _set('USERNAME');
    if (user == null) return null;
    return <String>['icacls', path, '/inheritance:r', '/grant:r', '$user:${directory ? '(OI)(CI)F' : 'F'}'];
  }

  /// `rundll32 url.dll,FileProtocolHandler` opens a file or an address as a double click would,
  /// with no shell reading the target: a name with `&` or `^` in it is a name, not a command.
  @override
  List<String> openCommand(String target) => <String>['rundll32', 'url.dll,FileProtocolHandler', target];
}

/// The desk of the computer the interface runs on.
///
/// Settable for tests alone: the suite runs as on Linux wherever it runs, so a test never starts a
/// Windows program by accident on a Windows runner. A test of the Windows way builds a [Desk] of its
/// own, or sets this and puts it back.
Desk desk = Desk.of(Platform.operatingSystem, Platform.environment);

/// Runs an opener and answers its exit code and what it said on standard error, waiting for its exit alone: a program
/// it starts may keep the opener's output open for as long as that program runs. An opener still running after
/// [patience] runs what it opened itself, so it has taken the file and is answered as having opened it.
Future<ProcessResult> runOpener(
  String executable,
  List<String> arguments, {
  Duration patience = const Duration(seconds: 10),
}) async {
  final process = await Process.start(executable, arguments);
  process.stdout.drain<void>().ignore();
  final said = <int>[];
  final saying = Completer<void>();
  final listening = process.stderr.listen(
    (chunk) {
      if (said.length < _mostSaid) said.addAll(chunk.take(_mostSaid - said.length));
    },
    onDone: saying.complete,
    onError: (Object _) => saying.isCompleted ? null : saying.complete(),
    cancelOnError: true,
  );
  final code = await process.exitCode.timeout(patience, onTimeout: () => 0);
  // What it said before it ended, without waiting on a program it left holding the stream.
  await saying.future.timeout(const Duration(seconds: 1), onTimeout: () {});
  await listening.cancel();
  return ProcessResult(process.pid, code, '', _decoded(said));
}

/// [bytes] as text: cut at [_mostSaid] or not the system's encoding, it is read as UTF-8 with what is broken replaced.
String _decoded(List<int> bytes) {
  try {
    return systemEncoding.decode(bytes);
  } on FormatException {
    return utf8.decode(bytes, allowMalformed: true);
  }
}

const _mostSaid = 4096;
