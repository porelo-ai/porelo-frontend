import 'package:flutter/material.dart';

import 'ansi.dart';
import 'terminal_look.dart';

/// What the window can tell about one line an agent wrote, from the line alone.
enum LineMark {
  /// Nothing it can tell.
  plain,

  /// A heading: what comes next is about this.
  heading,

  /// Something went wrong.
  error,

  /// Something came to an end, and went well.
  result,

  /// How long it worked, and nothing more to read in it.
  quiet,
}

const _escape = '\u001B';
final _control = RegExp('$_escape\\[[0-9;?]*[ -/]*[@-~]');

// "Failures: 0" and "0 errors" say that nothing failed, which is a result and not an error.
final _nothingWrong = RegExp(
  r'\b(failures|errors|failed)\s*[:=]?\s*0\b|\b0\s+(failures|errors|failed)\b',
  caseSensitive: false,
);
final _wrong = RegExp(
  r'\b(error|errors|failed|failure|failures|fatal|exception|panic|refused|denied|traceback)\b',
  caseSensitive: false,
);
final _went = RegExp(
  r'^\s*(✓|✔|✅|✻|ok\b|done\b|passed\b|finished\b|success\b)|\b(tests? passed|build success|all tests passed|tests run:)',
  caseSensitive: false,
);
final _worked = RegExp(r'^\s*✻(?!\s*finished\b)', caseSensitive: false);
final _heading = RegExp(r'^\s*(#{1,6}\s|❯\s|==+\s|--+\s\S)');

/// What [line] is, its colours left out.
LineMark markOf(String line) {
  final words = line.replaceAll(_control, '');
  if (_heading.hasMatch(words)) return LineMark.heading;
  if (_nothingWrong.hasMatch(words)) return LineMark.result;
  if (_wrong.hasMatch(words)) return LineMark.error;
  if (_worked.hasMatch(words)) return LineMark.quiet;
  if (_went.hasMatch(words)) return LineMark.result;
  return LineMark.plain;
}

/// [line] as the console draws it: marked with what the window can tell, and whatever the agent
/// coloured itself keeps its colour.
TextSpan markedLine(BuildContext context, String line, {double? size}) {
  final console = TerminalLook.consoleOf(context);
  final base = size == null ? TerminalLook.textOf(context) : TerminalLook.textOf(context, size: size);
  return TextSpan(
    style: switch (markOf(line)) {
      LineMark.plain => base,
      LineMark.heading => base.copyWith(color: console.strong, fontWeight: FontWeight.w600),
      LineMark.error => base.copyWith(color: console.error),
      LineMark.result => base.copyWith(color: console.ok),
      LineMark.quiet => base.copyWith(color: console.muted),
    },
    children: ansiSpans(line, TerminalLook.coloursOf(context)),
  );
}
