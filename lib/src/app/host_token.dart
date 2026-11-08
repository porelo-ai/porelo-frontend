import 'package:porelo_frontend/client.dart' show Connection;

import 'run_here.dart';

/// What a person is told once a machine was given a token kept here; null when it took it.
///
/// A refusal for want of the right names the right, since that is what a person must change at the
/// forge, and anything else is the machine's own words. [ran]'s words hold no token: they come
/// through `ForgeConnection.feedKeptToken`.
String? tokenGivenWords(String host, String forge, Ran ran) {
  if (ran.code == 0) return null;
  final said = ran.err.trim().isEmpty ? ran.out.trim() : ran.err.trim();
  if (RegExp(r'administration|forbidden|\b403\b|not accessible|must have admin', caseSensitive: false).hasMatch(said)) {
    return '$host could not use your $forge token: it needs Administration: write on these repositories. '
        'Give the token that right at $forge, and give it again.';
  }
  if (ran.code == 255) {
    return 'This computer did not reach $host as root, so it took no token. ${said.isEmpty ? '' : said}'.trim();
  }
  return '$host did not take the token: ${said.isEmpty ? 'it ended with code ${ran.code}' : said}';
}

/// What is said where no token is to be had for [forge], and what to do about it.
String noTokenWords(String host, String forge) =>
    'No $forge token is kept on this computer, so $host was given none. Sign in to $forge under My forges, '
    'and give it from here.';

/// What the kept token is for, and what happens to it, for the person's confirming word.
String keptTokenWords(String host, String forge, String where) =>
    '$host has no account at $where. For setup it uses your $forge token once to add read-only keys to the '
    "Porelo organization's repository and any waiting projects' central repositories, and to copy those projects to its "
    'own forge. From then on it reads with those keys. It does not keep the token. The token must be allowed to '
    'administer those repositories (Administration: write) and read their contents.\n\n'
    "This window reads the token this computer keeps for $forge, and writes it to $host's command over ssh, on its "
    'standard input: on no command line, in no log and in no file.';

/// The token this machine's vault declares for the organization's repository at [address], or null where none is
/// there now: kind `TOKEN`, for `git` or `any`, whose match is the longest prefix of the repository's address, as
/// Porelo picks it. Named to the person, never read: Porelo hands it on itself.
Connection? declaredOrganizationToken(String address, List<Connection> held) {
  final https = _https(address)?.toLowerCase();
  if (https == null) return null;
  Connection? best;
  for (final each in held) {
    final match = each.match.toLowerCase();
    if (each.kind != 'TOKEN' || !(each.purpose == 'git' || each.purpose == 'any') || !each.present) continue;
    if (match.isEmpty || !https.startsWith(match)) continue;
    if (best == null || match.length > best.match.length) best = each;
  }
  return best;
}

/// [address] as the https address a declaration matches against: `git@host:path`, `host:path` and
/// `ssh://user@host/path` are read as `https://host/path`, as Porelo normalizes them; null for anything else.
String? _https(String address) {
  final trimmed = address.trim();
  if (trimmed.startsWith('https://') || trimmed.startsWith('http://')) return trimmed;
  final ssh = Uri.tryParse(trimmed);
  if (ssh != null && ssh.scheme == 'ssh' && ssh.host.isNotEmpty) return 'https://${ssh.host}${ssh.path}';
  // The user is optional, as Porelo may answer the scp form without it; one letter before the colon is a drive.
  final scp = RegExp(r'^(?:[^@/\\\s]+@)?([^:/\\\s@]{2,}):(.+)$').firstMatch(trimmed);
  return scp == null ? null : 'https://${scp.group(1)}/${scp.group(2)}';
}

/// What the declared token is for, and that this window never reads it, for the person's confirming word.
String declaredTokenWords(String host, String forge, String where, Connection declared) =>
    '$host has no account at $where. For setup it uses your $forge token once to add read-only keys to the '
    "Porelo organization's repository and any waiting projects' central repositories, and to copy those projects to its "
    'own forge. From then on it reads with those keys. It does not keep the token. The token must be allowed to '
    'administer those repositories (Administration: write) and read their contents.\n\n'
    'It gives the token declared on this machine for ${declared.match}, ${declared.id} in its vault. Porelo hands it '
    "to $host's command over the machine's pinned ssh, on its standard input; this window never reads it.";

/// What is said once Porelo handed the declared token on, or did not.
String? handedOverWords(String host, Connection declared, {required bool handedOver}) =>
    handedOver ? null : '$host was given no token: Porelo did not hand on the one declared for ${declared.match}.';
