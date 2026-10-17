import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Runs `wsl.exe` with arguments and answers its exit code and the bytes it printed. Injectable,
/// so the distributions of a test are whatever it says.
typedef RunWsl = Future<({int code, List<int> printed})> Function(List<String> arguments);

/// A WSL distribution of the Windows user, as `wsl.exe` lists it.
class WslDistribution {
  const WslDistribution({required this.name, required this.running, required this.version});

  /// Its name, as `wsl.exe -d` takes it.
  final String name;

  /// Whether it runs now. **A stopped one is never started by the interface**: calling into it
  /// would start it, with its memory and its processors.
  final bool running;

  /// 2 for WSL2, 1 for WSL1, 0 where `wsl.exe` did not say.
  final int version;

  @override
  bool operator ==(Object other) =>
      other is WslDistribution && other.name == name && other.running == running && other.version == version;

  @override
  int get hashCode => Object.hash(name, running, version);

  @override
  String toString() => '$name (${running ? 'running' : 'stopped'}, WSL$version)';
}

/// The WSL distributions of the Windows user, read without starting any of them.
///
/// **Only the parts of `wsl.exe`'s answers that do not depend on Windows' language are read**: the
/// names from `-l -q`, which ones run from `-l --running -q`, and the version from the last column
/// of `-l -v`. The state column of `-l -v` is translated ("Running", "Wird ausgeführt"), and a
/// German Windows must not read as one where every distribution is stopped.
class Wsl {
  Wsl({RunWsl? run}) : _run = run ?? runWslExe;

  final RunWsl _run;

  /// The distributions, or an empty list where WSL is not installed or answers nothing.
  Future<List<WslDistribution>> distributions() async {
    final all = await _names(<String>['-l', '-q']);
    if (all.isEmpty) return const <WslDistribution>[];
    final running = (await _names(<String>['-l', '--running', '-q'])).toSet();
    final versions = _versions(await _text(<String>['-l', '-v']));
    return <WslDistribution>[
      for (final name in all)
        WslDistribution(name: name, running: running.contains(name), version: versions[name] ?? 0),
    ];
  }

  /// The one named [name], or null when there is none of that name.
  Future<WslDistribution?> distribution(String name) async {
    for (final each in await distributions()) {
      if (each.name == name) return each;
    }
    return null;
  }

  /// Why the distribution [name] is not to be called into now, or null when it runs as WSL2.
  ///
  /// **Asked before every call into it**, because `wsl.exe -d` starts a distribution that is stopped,
  /// and the interface never does: the person starts it.
  Future<String?> whyNotNow(String name) async {
    final found = await distribution(name);
    if (found == null) {
      return 'There is no WSL distribution called $name for this Windows user, or WSL does not answer.';
    }
    if (!found.running) {
      return '$name is stopped. The interface does not start it: start it yourself, for example by '
          'opening it from the Start menu, and it is reached again.';
    }
    if (found.version == 1) {
      return '$name runs under WSL1, which runs neither podman nor systemd. '
          '`wsl --set-version $name 2` converts it; the interface does not run that.';
    }
    return null;
  }

  /// What reaches the daemon of the distribution [name]: `porelo daemon connect` in it, its standard
  /// input and output joined to the daemon's socket. **Started as a process of its own, never
  /// through a shell**: Windows PowerShell re-encodes text in its pipes, and Varlink's framing ends
  /// each message with a zero byte that must arrive as it was sent.
  static List<String> relayTo(String name) => runIn(name, const <String>['porelo', 'daemon', 'connect']);

  /// What runs [command] in the distribution [name]. **`--exec`, not `--`**: after `--`, `wsl.exe`
  /// hands the words to the distribution's shell, which splits them again, so a task's name with a
  /// space or a quote in it would arrive as something else. `--exec` runs the program with exactly
  /// these arguments.
  static List<String> runIn(String name, List<String> command) => <String>['wsl.exe', '-d', name, '--exec', ...command];

  Future<List<String>> _names(List<String> arguments) async => <String>[
    for (final line in const LineSplitter().convert(await _text(arguments)))
      if (line.trim().isNotEmpty) line.trim(),
  ];

  Future<String> _text(List<String> arguments) async {
    try {
      final answer = await _run(arguments);
      return answer.code == 0 ? decodeWsl(answer.printed) : '';
    } on ProcessException {
      return '';
    }
  }

  static Map<String, int> _versions(String verbose) {
    final versions = <String, int>{};
    final lines = const LineSplitter().convert(verbose).skip(1);
    for (final line in lines) {
      final words = line.replaceFirst(RegExp(r'^\s*\*?\s*'), '').split(RegExp(r'\s+'));
      if (words.length < 3) continue;
      final version = int.tryParse(words.last);
      if (version != null) versions[words.first] = version;
    }
    return versions;
  }

  /// Runs `wsl.exe` with [arguments] and answers what it printed, its standard error after its
  /// standard output. `WSL_UTF8=1` asks for UTF-8, which older `wsl.exe` ignores; [decodeWsl] reads
  /// either.
  ///
  /// **Bounded, with nothing on its input**: where WSL is not installed, `wsl.exe` can be a stub that
  /// prints a notice and waits for a key. Its input is closed at once, and after [within] it is
  /// ended and answered as having failed, so nothing here waits for ever.
  static Future<({int code, List<int> printed})> runWslExe(
    List<String> arguments, {
    Duration within = const Duration(seconds: 20),
  }) async {
    final process = await Process.start('wsl.exe', arguments, environment: const <String, String>{'WSL_UTF8': '1'});
    unawaited(process.stdin.close());
    final out = <int>[];
    final err = <int>[];
    final reading = Future.wait(<Future<void>>[process.stdout.forEach(out.addAll), process.stderr.forEach(err.addAll)]);
    final code = await process.exitCode.timeout(
      within,
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
    await reading.timeout(const Duration(seconds: 2), onTimeout: () => <void>[]);
    return (code: code, printed: <int>[...out, ...err]);
  }
}

/// What `wsl.exe` printed, as text. **It prints UTF-16 unless told otherwise**, so the bytes are
/// read as UTF-16 little-endian where every second byte of the start is zero, and as UTF-8 else.
String decodeWsl(List<int> printed) {
  var bytes = printed;
  if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe) bytes = bytes.sublist(2);
  final looksWide =
      bytes.length >= 2 &&
      bytes.length.isEven &&
      Iterable<int>.generate(bytes.length ~/ 2 < 8 ? bytes.length ~/ 2 : 8).every((i) => bytes[2 * i + 1] == 0);
  if (!looksWide) return utf8.decode(bytes, allowMalformed: true).replaceAll('\r', '');
  final units = <int>[for (var i = 0; i + 1 < bytes.length; i += 2) bytes[i] | bytes[i + 1] << 8];
  return String.fromCharCodes(units).replaceAll('\r', '').replaceAll('\u0000', '');
}
