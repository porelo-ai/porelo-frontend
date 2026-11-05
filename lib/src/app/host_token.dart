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
