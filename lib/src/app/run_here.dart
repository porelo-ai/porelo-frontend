import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'owned_process.dart';

/// What one local command answered.
typedef Ran = ({int code, String out, String err});

/// Runs one program on this computer, with credentials only in its environment or standard input.
typedef RunHere = Future<Ran> Function(
  String program,
  List<String> arguments, {
  String? inDirectory,
  Map<String, String> environment,
  String? input,
});

/// What a call of Core's `porelo registry …` gets in its environment beside [runHere]'s own, read anew at each call; null
/// for nothing. Set at the start for an instance acting for the organization, so a token renewed meanwhile is taken.
Future<Map<String, String>> Function()? registryEnvironment;

/// How long one local command may run before it is ended and answered as `timeout(1)` answers, exit code 124.
Duration runHereLimit = const Duration(minutes: 5);

/// Runs a process with this computer's environment plus [environment].
Future<Ran> runHere(
  String program,
  List<String> arguments, {
  String? inDirectory,
  Map<String, String> environment = const <String, String>{},
  String? input,
}) async {
  if (registryEnvironment case final extra? when program == 'porelo' && arguments.firstOrNull == 'registry') {
    environment = {...environment, ...await extra()};
  }
  final process = await Process.start(program, arguments, workingDirectory: inDirectory, environment: environment);
  final out = _Gathered(process.stdout.transform(const SystemEncoding().decoder));
  final err = _Gathered(process.stderr.transform(const SystemEncoding().decoder));
  try {
    if (input != null) process.stdin.write(input);
    await process.stdin.close();
  } on SocketException {
    // The program ended before taking all of it; its exit code and its words say why.
  }
  return _answered(process, program, arguments, out: out, err: err);
}

/// [process]'s answer, or exit code 124 with a sentence once it outlived [runHereLimit] and was ended.
///
/// Its output is waited for only briefly after it ended: a child it left behind, such as ssh's master, can hold the
/// pipes open long after.
Future<Ran> _answered(
  Process process,
  String program,
  List<String> arguments, {
  required _Gathered out,
  required _Gathered err,
}) async {
  int? code;
  try {
    code = await process.exitCode.timeout(runHereLimit);
  } on TimeoutException {
    await stopOwnedProcess(process).catchError((Object _) {});
  }
  final said = (out: await out.soFar(), err: await err.soFar());
  if (code != null) return (code: code, out: said.out, err: said.err);
  return (code: 124, out: said.out, err: '${said.err}${_hung(program, arguments)}\n');
}

/// One output stream's words as they arrive, so what came before a child held the pipe open is never lost.
class _Gathered {
  _Gathered(Stream<String> words) {
    words.listen(_words.write, onDone: _done.complete, onError: (Object _) {}, cancelOnError: false);
  }

  final _words = StringBuffer();
  final _done = Completer<void>();

  /// Everything once the stream ended, or what came within two seconds more.
  Future<String> soFar() async {
    await _done.future.timeout(const Duration(seconds: 2), onTimeout: () {});
    return _words.toString();
  }
}

/// What to say of [program] ended at [runHereLimit]: which command, that it was ended, and what to do.
String _hung(String program, List<String> arguments) {
  final name = [program.split('/').last, ?arguments.firstOrNull].join(' ');
  final limit = runHereLimit.inMinutes >= 1 ? '${runHereLimit.inMinutes} minutes' : '${runHereLimit.inSeconds} seconds';
  final what = switch (program.split('/').last) {
    'git' => 'Check that this computer reaches the network and the forge, then try again.',
    'porelo' =>
      "Check that this computer reaches the host and the forge, then try again; Porelo's own log says where it waited.",
    'keepassxc-cli' => 'Check that the KeePassXC database file can be read, then try again.',
    _ => 'Try again; if it waits again, run it in a terminal to see what it waits for.',
  };
  return '`$name` gave no answer within $limit and was ended. $what';
}

/// Runs one program on this computer with [input]'s bytes on its standard input, as a Git bundle needs: [RunHere]'s
/// text input would encode them again.
typedef RunHereWithBytes = Future<Ran> Function(String program, List<String> arguments, {required List<int> input});

/// Runs a process with this computer's environment and [input]'s bytes on its standard input.
Future<Ran> runHereWithBytes(String program, List<String> arguments, {required List<int> input}) async {
  final process = await Process.start(program, arguments);
  // Read from the start, whatever bytes come: a program's words are never lost to a decoding error.
  final out = _Gathered(process.stdout.transform(const Utf8Decoder(allowMalformed: true)));
  final err = _Gathered(process.stderr.transform(const Utf8Decoder(allowMalformed: true)));
  try {
    process.stdin.add(input);
    await process.stdin.close();
  } on SocketException {
    // The program ended before taking all of it; its exit code and its words say why.
  }
  return _answered(process, program, arguments, out: out, err: err);
}

/// A local operation's safe refusal, without private command diagnostics.
class WorkspaceRefused implements Exception {
  /// Keeps a sentence that is safe to show.
  const WorkspaceRefused(this.words);

  /// The safe explanation.
  final String words;

  @override
  String toString() => words;
}
