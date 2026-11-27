/// Text a machine sent, as a person is shown it: bounded, and nothing in it that forges a line or hides what it
/// says.
library;

/// The most characters of a report's text shown, as Porelo bounds a report.
const mostReportCharacters = 65536;

/// Control characters but a line break, the line and paragraph separators, lone surrogates, the marks that turn the
/// order of text around, and the characters drawn as nothing (soft hyphens, joiners, word joiners, byte order marks,
/// tags): each would forge a line or hide what the text says.
final _unsafe = RegExp(
  '[\x00-\x09\x0b-\x1f\x7f-\x9f\u00ad\u034f\u061c\u180e\u200b-\u200f\u2028\u2029\u202a-\u202e\u2060-\u2069\ufeff]'
  '|\udb40[\udc00-\udc7f]'
  '|[\ud800-\udbff](?![\udc00-\udfff])|(?<![\ud800-\udbff])[\udc00-\udfff]',
);

/// [text] as a report is shown: cut past [most] characters, and every unsafe character of what is left written out as
/// `\u{...}`.
String reportShown(String text, {int most = mostReportCharacters}) {
  final runes = text.runes;
  final cut = runes.length > most;
  final kept = cut ? String.fromCharCodes(runes.take(most)) : text;
  final escaped = kept.replaceAllMapped(
    _unsafe,
    (match) => '\\u{${match[0]!.runes.first.toRadixString(16).padLeft(4, '0')}}',
  );
  return cut ? '$escaped … cut' : escaped;
}

/// [text] as one shown line of at most [most] characters: its line breaks written out too.
String oneLineShown(String text, {required int most}) => reportShown(text, most: most).replaceAll('\n', r'\n');

/// The most characters of the machine's sentence on a push's end shown, counted as shown: after every unsafe
/// character is written out, so a sentence of escapes is bounded as one of letters.
const mostEndUnkeptCharacters = 300;

/// What a forward, a drop or a landed merge adds to its result line when the machine said the push's end could not
/// be kept: the machine's [sentence] on one line, after a space; empty where it said nothing. The action is still
/// done; this only says that the task's record of where its push ended is missing.
String endUnkeptSaid(String? sentence) => switch (sentence?.trim()) {
  null || '' => '',
  final said => " The push's end could not be kept: ${_shownWithin(said, mostEndUnkeptCharacters)}",
};

/// [text] on one line, written out as [oneLineShown] does, and then cut to at most [most] shown characters: never
/// inside a written-out character, which would leave half an escape that reads as text of the machine's.
String _shownWithin(String text, int most) {
  final runes = text.runes;
  final taken = runes.length > most ? String.fromCharCodes(runes.take(most)) : text;
  final shown = oneLineShown(taken, most: most);
  if (runes.length <= most && shown.runes.length <= most) return shown;
  final cut = String.fromCharCodes(shown.runes.take(most)).replaceFirst(_partEscape, '');
  return '$cut … cut';
}

/// The start of a written-out character left at the end of a cut: a backslash alone, or one with its `u` and part of
/// the braces.
final _partEscape = RegExp(r'\\(u(\{[0-9a-f]*)?)?$');
