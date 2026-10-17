import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../app/conpty.dart';
import '../app/desk.dart';
import '../app/pty.dart';
import '../app/wsl.dart';
import 'tokens.dart';
import 'terminal_look.dart';

/// Sends [bytes] into a WSL distribution and answers what `od -c` read there.
typedef ThroughWsl = Future<String> Function(String distribution, List<int> bytes, {required bool pseudoconsole});

/// `porelo_frontend --diagnose-terminal`: the terminal widget the app uses, with every event that
/// reaches it shown and logged, and the bytes it would send carried through `wsl.exe` as the attach
/// carries them.
///
/// **For finding out what Windows delivers**, not for work: it starts no task and changes nothing.
/// Each key event (its logical and physical key and its character), each wheel event, and each
/// byte string the terminal would send is listed, and written to `porelo-terminal-diagnose.txt` in
/// the system's temporary folder (`%TEMP%` on Windows) for the person to send back.
///
/// Two switches answer the two questions: which input path the widget uses (the text-input path,
/// as on Linux, or the key events alone), and whether what was typed survives `wsl.exe`, through
/// pipes as the relay uses them or through a pseudoconsole as the attach does.
class TerminalDiagnosis extends StatefulWidget {
  const TerminalDiagnosis({this.wsl, this.throughWsl, this.log, super.key});

  /// How the distributions are listed; null for `wsl.exe` itself.
  final Wsl? wsl;

  /// How bytes are sent into a distribution; null for the real way.
  final ThroughWsl? throughWsl;

  /// Where the lines are written; null for `porelo-terminal-diagnose.txt` in the temporary folder.
  final File? log;

  @override
  State<TerminalDiagnosis> createState() => _TerminalDiagnosisState();
}

class _TerminalDiagnosisState extends State<TerminalDiagnosis> {
  final Terminal _terminal = Terminal(maxLines: 1000);
  final FocusNode _focus = FocusNode();
  final List<String> _lines = <String>[];
  final List<int> _sent = <int>[];
  late final File _log =
      widget.log ?? File('${Directory.systemTemp.path}${Platform.pathSeparator}porelo-terminal-diagnose.txt');
  List<String> _distributions = const <String>[];
  String? _distribution;
  bool _keyEventsOnly = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _terminal.onOutput = (data) {
      _sent.addAll(utf8.encode(data));
      _say('terminal would send ${_shown(data)}');
    };
    _terminal.write('Type here, turn the wheel over this pane, then send what was typed into WSL.\r\n');
    HardwareKeyboard.instance.addHandler(_keyEvent);
    _say('started on ${Platform.operatingSystem} ${Platform.operatingSystemVersion}, '
        'logging to ${_log.path}');
    unawaited(_readDistributions());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_keyEvent);
    _focus.dispose();
    super.dispose();
  }

  Future<void> _readDistributions() async {
    final found = await (widget.wsl ?? Wsl()).distributions();
    if (!mounted) return;
    setState(() => _distributions = <String>[for (final each in found) if (each.running) each.name]);
    _say('running WSL distributions: ${_distributions.isEmpty ? 'none' : _distributions.join(', ')}');
  }

  bool _keyEvent(KeyEvent event) {
    final kind = switch (event) { KeyDownEvent() => 'down', KeyUpEvent() => 'up', _ => 'repeat' };
    _say('key $kind: logical ${event.logicalKey.debugName ?? event.logicalKey.keyId} '
        '(0x${event.logicalKey.keyId.toRadixString(16)}), physical ${event.physicalKey.debugName ?? event.physicalKey.usbHidUsage}, '
        'character ${event.character == null ? 'none' : _shown(event.character!)}');
    return false;
  }

  void _wheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final up = event.scrollDelta.dy < 0;
    _say('wheel ${event.kind.name}: delta ${event.scrollDelta.dy.toStringAsFixed(1)} '
        '(${up ? 'up' : 'down'}); terminal in the alternate buffer: ${_terminal.isUsingAltBuffer}, '
        'mouse reports asked for: ${_terminal.mouseMode.name}; '
        'tmux would be sent ${_shown('\x1b[<${up ? 64 : 65};1;1M')}');
  }

  Future<void> _sendThrough({required bool pseudoconsole}) async {
    final distribution = _distribution;
    if (distribution == null || _sent.isEmpty) return;
    setState(() => _busy = true);
    final bytes = List<int>.of(_sent);
    _say('into $distribution ${pseudoconsole ? 'through a pseudoconsole, as the attach' : 'through pipes, as the relay'}: '
        '${bytes.length} bytes ${_shown(String.fromCharCodes(bytes))}');
    try {
      final read = await (widget.throughWsl ?? throughWslForReal)(distribution, bytes, pseudoconsole: pseudoconsole)
          .timeout(const Duration(seconds: 30));
      _say('od -c read in $distribution:\n$read');
    } on Object catch (failed) {
      _say('could not be sent: $failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String line) {
    final stamped = '${DateTime.now().toIso8601String()} $line';
    try {
      _log.writeAsStringSync('$stamped\n', mode: FileMode.append, flush: true);
    } on FileSystemException {
      // The screen still shows it.
    }
    if (!mounted) {
      _lines.add(stamped);
      return;
    }
    setState(() => _lines.add(stamped));
  }

  /// [text] with every control character spelled out, so an escape or a carriage return is seen.
  static String _shown(String text) => text.runes.map((rune) {
        if (rune == 0x1b) return r'\e';
        if (rune == 0x0d) return r'\r';
        if (rune == 0x0a) return r'\n';
        if (rune == 0x09) return r'\t';
        if (rune < 0x20 || rune == 0x7f) return '\\x${rune.toRadixString(16).padLeft(2, '0')}';
        return String.fromCharCode(rune);
      }).join().replaceAll(' ', '␠');

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Terminal diagnosis')),
        body: Padding(
          padding: const EdgeInsets.all(Space.small),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: Space.wide,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Switch(
                      key: const Key('diagnose-key-events-only'),
                      value: _keyEventsOnly,
                      onChanged: (on) {
                        setState(() => _keyEventsOnly = on);
                        _say('input path: ${on ? 'key events alone' : 'text input, as on Linux'}');
                      },
                    ),
                    const Text('Key events alone'),
                  ]),
                  DropdownButton<String>(
                    key: const Key('diagnose-distribution'),
                    hint: const Text('No WSL distribution'),
                    value: _distribution,
                    items: <DropdownMenuItem<String>>[
                      for (final each in _distributions) DropdownMenuItem(value: each, child: Text(each)),
                    ],
                    onChanged: (chosen) => setState(() => _distribution = chosen),
                  ),
                  OutlinedButton(
                    key: const Key('diagnose-through-pipes'),
                    onPressed: _distribution == null || _sent.isEmpty || _busy ? null : () => _sendThrough(pseudoconsole: false),
                    child: const Text('Send through wsl.exe (pipes)'),
                  ),
                  OutlinedButton(
                    key: const Key('diagnose-through-pseudoconsole'),
                    onPressed: _distribution == null || _sent.isEmpty || _busy ? null : () => _sendThrough(pseudoconsole: true),
                    child: const Text('Send through wsl.exe (pseudoconsole)'),
                  ),
                  TextButton(
                    key: const Key('diagnose-clear'),
                    onPressed: () {
                      _sent.clear();
                      _say('what was typed is cleared');
                    },
                    child: const Text('Clear what was typed'),
                  ),
                ],
              ),
              SizedBox(
                height: Sizes.diagnosisTerminal,
                child: Listener(
                  key: const Key('diagnose-wheel'),
                  onPointerSignal: _wheel,
                  child: ColoredBox(
                    color: TerminalLook.background,
                    child: TerminalView(
                      _terminal,
                      key: ValueKey<bool>(_keyEventsOnly),
                      theme: TerminalLook.theme,
                      focusNode: _focus,
                      autofocus: true,
                      hardwareKeyboardOnly: _keyEventsOnly,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.small),
              Text('Logged to ${_log.path}', style: Theme.of(context).textTheme.bodySmall),
              Expanded(
                child: ListView(
                  key: const Key('diagnose-lines'),
                  reverse: true,
                  children: <Widget>[
                    for (final line in _lines.reversed)
                      SelectableText(line, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// What `wsl.exe` carries, read back in the distribution: a raw terminal, so nothing is turned into
/// something else on the way, and exactly as many bytes as were sent, so `od` ends by itself.
Future<String> throughWslForReal(String distribution, List<int> bytes,
    {required bool pseudoconsole, @visibleForTesting String wslExe = 'wsl.exe'}) async {
  final command = Wsl.runIn(
      distribution, <String>['sh', '-c', r'stty raw -echo 2>/dev/null; head -c "$1" | od -c', 'sh', '${bytes.length}']);
  command[0] = wslExe;
  if (!pseudoconsole) {
    final process = await Process.start(command.first, command.sublist(1));
    process.stdin.add(bytes);
    await process.stdin.close();
    final out = await process.stdout.transform(const Utf8Decoder(allowMalformed: true)).join();
    final err = await process.stderr.transform(const Utf8Decoder(allowMalformed: true)).join();
    await process.exitCode;
    return '$out$err';
  }
  final SessionChannel channel = desk.isWindows
      ? ConPty.start(command.first, command.sublist(1))
      : Pty.start(command.first, command.sublist(1));
  final read = StringBuffer();
  final reading = channel.output.listen((chunk) => read.write(utf8.decode(chunk, allowMalformed: true)));
  // Given a moment to set the terminal raw before anything arrives.
  await Future<void>.delayed(const Duration(seconds: 2));
  channel.send(String.fromCharCodes(bytes));
  await channel.ended.timeout(const Duration(seconds: 20), onTimeout: () => -1);
  await reading.cancel();
  await channel.close();
  return read.toString();
}

/// The diagnosis as a window of its own.
class TerminalDiagnosisApp extends StatelessWidget {
  const TerminalDiagnosisApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(title: 'Porelo terminal diagnosis', home: TerminalDiagnosis());
}
