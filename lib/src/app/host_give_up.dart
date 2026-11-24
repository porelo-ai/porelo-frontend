import 'dart:convert';

import 'host_token.dart' show httpsAddressOf;

/// The command that gives the host [host] up for good, run by the person in a terminal of this computer: Porelo removes
/// the host's keys from the central forge with the vault's token, or one typed there, and deletes its identity.
///
/// No token and no identity is ever in it; its JSON answer names only what was removed and what was kept.
/// `--` ends its options, so a host name is never read as one.
List<String> giveUpCommand(String host) => ['porelo', 'host', 'give-up', '--json', '--', host];

/// The most a give-up's answer is read at: a row per key, for at most every project of one host.
const _most = 256 * 1024;

/// One key of a host's identity, as give-up answers it.
final class GiveUpRow {
  /// Takes what the answer names.
  const GiveUpRow({this.project, required this.repository, required this.title, this.why, this.link});

  /// The project whose repository it reads, or null for the organization's own.
  final String? project;

  /// The repository at the central forge.
  final String repository;

  /// The key's title at the forge.
  final String title;

  /// Why it is kept; null where it was removed.
  final String? why;

  /// Where its owner removes it by hand; null where no link can be given.
  final String? link;

  /// Its project and repository, in words.
  String get named => '${project == null ? 'the organization' : 'project $project'}, $repository';
}

/// What give-up answered, or null where [text] is none, or more than any answer is.
({List<GiveUpRow> removed, List<GiveUpRow> kept})? readGiveUpAnswer(String? text) {
  if (text == null || text.length > _most) return null;
  final Object? value;
  try {
    value = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (value is! Map<String, dynamic> || value['removed'] is! List || value['kept'] is! List) return null;
  // A row that is no object is never dropped unseen: an answer holding one is not read at all.
  if ([...value['removed'] as List, ...value['kept'] as List].any((row) => row is! Map<String, dynamic>)) return null;
  final answer = value;
  List<GiveUpRow> rows(String name) => [
    for (final row in (answer[name] as List).whereType<Map<String, dynamic>>())
      GiveUpRow(
        project: _text(row['project']),
        repository: _text(row['repository']) ?? '',
        title: _text(row['title']) ?? '',
        why: _text(row['why']),
        link: _text(row['link']),
      ),
  ];
  return (removed: rows('removed'), kept: rows('kept'));
}

/// [value] as text without control characters, which the screen or a terminal would read as commands.
String? _text(Object? value) => value is String ? plainWords(value) : null;

/// [words] with each control character a space.
String plainWords(String words) => words.replaceAll(RegExp(r'[\x00-\x1f\x7f-\x9f]'), ' ');

/// How a give-up ended, in words, with the rows its answer named.
final class GiveUpOutcome {
  /// Takes the words, the rows and what may follow.
  const GiveUpOutcome(
    this.words, {
    this.removed = const [],
    this.kept = const [],
    this.allGone = false,
    this.mayRunAgain = false,
  });

  /// What came of it, for a person.
  final String words;

  /// The keys removed from the central forge.
  final List<GiveUpRow> removed;

  /// The keys still at the central forge, each with why.
  final List<GiveUpRow> kept;

  /// Whether every key is removed and the identity deleted from the vault.
  final bool allGone;

  /// Whether giving it up again goes on where this one stopped.
  final bool mayRunAgain;
}

const _again = 'Give-up may be run again: it removes only what is still there.';

/// What came of giving [host] up: [code] is its exit code, null where none was seen, [answer] its JSON answer and
/// [lastLine] the last thing the terminal said, a refusal's words.
GiveUpOutcome giveUpOutcome({
  required String host,
  required bool started,
  required int? code,
  required String? answer,
  required String lastLine,
}) {
  if (!started) return GiveUpOutcome('Give-up of $host did not start: nothing was removed.');
  final read = readGiveUpAnswer(answer);
  final removed = read?.removed ?? const <GiveUpRow>[];
  final kept = read?.kept ?? const <GiveUpRow>[];
  final said = plainWords(lastLine.trim().replaceFirst(RegExp('^porelo: '), ''));
  return switch (code) {
    null => GiveUpOutcome(
      'Give-up of $host was cancelled before it ended. Some of its keys may already be removed from the central '
      'forge. $_again',
      mayRunAgain: true,
    ),
    // Without its answer nothing is known of what it did: never taken for all gone, nor for nothing done.
    0 || 65 when read == null => GiveUpOutcome(
      'Give-up of $host ended, but its answer could not be read: it ended with $code'
      '${said.isEmpty ? '' : ', and the terminal last said: $said'}.${code == 65 ? ' $_again' : ''}',
      mayRunAgain: code == 65,
    ),
    0 => GiveUpOutcome(
      '$host is given up: its keys are removed from the central forge, and its identity is deleted from your '
      'Porelo-Vault.',
      removed: removed,
      allGone: true,
    ),
    65 when read != null && kept.isNotEmpty => GiveUpOutcome(
      '$host is not given up yet: ${kept.length} of its keys remain at the central forge, and your Porelo-Vault '
      'keeps its identity. $_again',
      removed: removed,
      kept: kept,
      mayRunAgain: true,
    ),
    65 when read != null => GiveUpOutcome(
      "$host's identity changed while it was given up, so your Porelo-Vault keeps it. $_again",
      removed: removed,
      mayRunAgain: true,
    ),
    66 => GiveUpOutcome('Your Porelo-Vault keeps no identity of $host: there is nothing to give up.'),
    69 => GiveUpOutcome(
      'No token for the central forge was given: store it in your Porelo-Vault, or type it in the terminal when '
      'asked. Nothing was removed.',
    ),
    77 => GiveUpOutcome('Your Porelo-Vault is shut: open it, then give $host up again. Nothing was removed.'),
    78 => GiveUpOutcome('This computer has no organization, so nothing was removed.'),
    64 => GiveUpOutcome('Porelo did not take $host as a host name: nothing was removed.'),
    final other => GiveUpOutcome('Give-up of $host ended with $other${said.isEmpty ? '.' : ': $said'}'),
  };
}

/// [link] where it may be offered as a button: an https address with no user part, on the host of the organization's
/// central forge [central], read afresh, in any of its forms; null where it is shown as text alone.
///
/// Its port is https' own, or the one an https [central] names: an ssh address's port is ssh's, never the web's.
Uri? offeredLink(String? link, String? central) {
  if (link == null || central == null) return null;
  final at = Uri.tryParse(link);
  final https = httpsAddressOf(central);
  final forge = https == null ? null : Uri.tryParse(https);
  if (at == null || forge == null || !at.isAbsolute || at.scheme != 'https' || at.userInfo.isNotEmpty) return null;
  if (forge.host.isEmpty || at.host.toLowerCase() != forge.host.toLowerCase()) return null;
  return at.port == (forge.scheme == 'https' ? forge.port : 443) ? at : null;
}
