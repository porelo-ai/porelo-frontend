import 'package:flutter/material.dart';

/// The character an ANSI escape starts with, spelled out so it survives an editor.
const _escape = '\u001B';

/// Matches one complete control sequence — a color is the one ending in `m`, and the rest (erasing
/// a line, hiding the cursor) are skipped rather than read up to the next `m` in the text.
final _control = RegExp('$_escape\\[[0-9;?]*[ -/]*[@-~]');

/// Turns a line that may carry ANSI color into spans that read on either appearance.
///
/// Agents color their output. A log shown with the escapes left in is unreadable, and one shown
/// with them stripped loses what the color was carrying — so they are honored, but never
/// literally: a terminal's black is invisible on a dark background and its bright yellow is
/// invisible on a light one. Each color is mapped to something from the theme with the same
/// *meaning*, which is what "legible under whatever appearance the person has chosen" asks for.
List<TextSpan> ansiSpans(String line, ColorScheme scheme) {
  final spans = <TextSpan>[];
  var style = const _Sgr();
  var index = 0;

  while (index < line.length) {
    final start = line.indexOf(_escape, index);
    if (start < 0) {
      spans.add(TextSpan(text: line.substring(index), style: style.toStyle(scheme)));
      break;
    }
    if (start > index) {
      spans.add(TextSpan(text: line.substring(index, start), style: style.toStyle(scheme)));
    }
    final sequence = _control.matchAsPrefix(line, start)?.group(0);
    if (sequence == null) {
      // An escape with no terminator is a line cut in half, not a style. `Tail` caps each reply,
      // so that happens. Show it as it came rather than swallowing the rest of the line.
      spans.add(TextSpan(text: line.substring(start), style: style.toStyle(scheme)));
      break;
    }
    if (sequence.endsWith('m')) {
      style = style.after(sequence.substring(2, sequence.length - 1));
    }
    index = start + sequence.length;
  }

  return spans.isEmpty ? <TextSpan>[TextSpan(text: line)] : spans;
}

/// Whether a line carries any ANSI escape at all.
bool hasAnsi(String line) => line.contains(_escape);

/// Strips ANSI escapes, for somewhere that cannot render them.
String withoutAnsi(String line) => line.replaceAll(_control, '');

/// One run of styling, as the escapes so far have set it.
@immutable
class _Sgr {
  const _Sgr({this.color, this.bold = false, this.faint = false});

  final int? color;
  final bool bold;
  final bool faint;

  /// Applies the codes in one escape, which may set several things at once.
  _Sgr after(String codes) {
    var next = this;
    for (final part in codes.split(';')) {
      final code = int.tryParse(part.isEmpty ? '0' : part);
      switch (code) {
        case 0:
          next = const _Sgr();
        case 1:
          next = _Sgr(color: next.color, bold: true, faint: next.faint);
        case 2:
          next = _Sgr(color: next.color, bold: next.bold, faint: true);
        case 22:
          next = _Sgr(color: next.color);
        case 39:
          next = _Sgr(bold: next.bold, faint: next.faint);
        default:
          if (code == null) continue;
          // Foreground only, normal (30-37) and bright (90-97). Backgrounds are deliberately
          // ignored: a log that paints its own background cannot stay legible on both
          // appearances, and the person chose the appearance.
          if ((code >= 30 && code <= 37) || (code >= 90 && code <= 97)) {
            next = _Sgr(color: code % 10, bold: next.bold, faint: next.faint);
          }
      }
    }
    return next;
  }

  /// How this run should be drawn against [scheme].
  TextStyle toStyle(ColorScheme scheme) =>
      TextStyle(color: _colorOf(scheme), fontWeight: bold ? FontWeight.w700 : FontWeight.w400);

  Color? _colorOf(ColorScheme scheme) {
    if (faint) return scheme.onSurfaceVariant;
    return switch (color) {
      // Mapped by meaning rather than by name, and taken from the scheme, so each appearance gets
      // a color that is actually readable against its own background.
      1 => scheme.error, // red: something went wrong
      2 => scheme.primary, // green: something worked
      3 => scheme.tertiary, // yellow: something wants attention
      4 => scheme.secondary, // blue: something said for information
      5 => scheme.tertiary, // magenta
      6 => scheme.secondary, // cyan
      0 || 7 => scheme.onSurface, // black and white: whatever plain is here
      _ => null,
    };
  }
}
