import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/ansi.dart';

/// The escape an agent's output arrives carrying, spelled out so it survives an editor.
const esc = '\u001B';

void main() {
  const scheme = ColorScheme.light();

  test('a plain line is one span and takes no color of its own', () {
    final spans = ansiSpans('building the image', scheme);

    expect(spans, hasLength(1));
    expect(spans.single.text, 'building the image');
  });

  test('an escape splits the line and colors only what follows it', () {
    final spans = ansiSpans('ok $esc[31mfailed$esc[0m done', scheme);

    expect(spans.map((span) => span.text), <String>['ok ', 'failed', ' done']);
    expect(spans[1].style?.color, scheme.error);
    expect(spans[2].style?.color, isNot(scheme.error));
  });

  test('color comes from the theme, so it reads on either appearance', () {
    // A terminal's own red is unreadable against one of the two backgrounds. What is carried
    // across is what the color meant, never the value it happened to have.
    final light = ansiSpans('$esc[31mred', const ColorScheme.light());
    final dark = ansiSpans('$esc[31mred', const ColorScheme.dark());

    expect(light.last.style?.color, const ColorScheme.light().error);
    expect(dark.last.style?.color, const ColorScheme.dark().error);
    expect(light.last.style?.color, isNot(dark.last.style?.color));
  });

  test('several codes in one escape all apply', () {
    final spans = ansiSpans('$esc[1;32mgreen and bold', scheme);

    expect(spans.last.style?.fontWeight, FontWeight.w700);
    expect(spans.last.style?.color, scheme.primary);
  });

  test('a background code is ignored rather than painted', () {
    // A log that paints its own background cannot stay legible on both appearances, and the
    // person chose the appearance.
    final spans = ansiSpans('$esc[41mstill readable', scheme);

    expect(spans.last.style?.color, isNull);
  });

  test('a line cut mid-escape is shown rather than swallowed', () {
    // Tail caps each reply, so a line does arrive in halves. Half an escape is not a style, and
    // dropping the rest of the line would lose what it said.
    final spans = ansiSpans('cut here $esc[3', scheme);

    expect(spans.map((span) => span.text).join(), 'cut here $esc[3');
  });

  test('an escape that is not a color is skipped and the words after it are kept', () {
    // Erasing a line and hiding the cursor are escapes too; reading to the next "m" took the words.
    final spans = ansiSpans('$esc[2KDownloading item 3$esc[?25l, then $esc[32mdone', scheme);

    expect(spans.map((span) => span.text).join(), 'Downloading item 3, then done');
    expect(spans.last.style?.color, scheme.primary);
  });

  test('stripping takes every escape, not only the colors', () {
    expect(withoutAnsi('$esc[2KDownloading$esc[?25l item 3'), 'Downloading item 3');
  });

  test('stripping leaves the words and nothing else', () {
    expect(withoutAnsi('$esc[31mred$esc[0m'), 'red');
    expect(hasAnsi('plain'), isFalse);
    expect(hasAnsi('$esc[0mplain'), isTrue);
  });
}
