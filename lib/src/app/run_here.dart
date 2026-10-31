import 'dart:io';

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

/// Runs a process with this computer's environment plus [environment].
Future<Ran> runHere(
  String program,
  List<String> arguments, {
  String? inDirectory,
  Map<String, String> environment = const <String, String>{},
  String? input,
}) async {
  final process = await Process.start(program, arguments, workingDirectory: inDirectory, environment: environment);
  if (input != null) process.stdin.write(input);
  await process.stdin.close();
  final out = process.stdout.transform(const SystemEncoding().decoder).join();
  final err = process.stderr.transform(const SystemEncoding().decoder).join();
  return (code: await process.exitCode, out: await out, err: await err);
}

/// Runs one program on this computer with [input]'s bytes on its standard input, as a Git bundle needs: [RunHere]'s
/// text input would encode them again.
typedef RunHereWithBytes = Future<Ran> Function(String program, List<String> arguments, {required List<int> input});

/// Runs a process with this computer's environment and [input]'s bytes on its standard input.
Future<Ran> runHereWithBytes(String program, List<String> arguments, {required List<int> input}) async {
  final process = await Process.start(program, arguments);
  final out = process.stdout.transform(const SystemEncoding().decoder).join();
  final err = process.stderr.transform(const SystemEncoding().decoder).join();
  try {
    process.stdin.add(input);
    await process.stdin.close();
  } on SocketException {
    // The program ended before taking all of it; its exit code and its words say why.
  }
  return (code: await process.exitCode, out: await out, err: await err);
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
