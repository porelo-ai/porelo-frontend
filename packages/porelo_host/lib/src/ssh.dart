/// The pinned trust policy, placed before every other ssh option so config cannot add trusted keys.
List<String> pinnedHostSshOptions(String knownHosts, String identity) => <String>[
  '-o',
  'StrictHostKeyChecking=yes',
  '-o',
  'UserKnownHostsFile="$knownHosts"',
  '-o',
  'GlobalKnownHostsFile=none',
  '-o',
  'KnownHostsCommand=none',
  '-o',
  'VerifyHostKeyDNS=no',
  '-o',
  'UpdateHostKeys=no',
  '-o',
  'BatchMode=yes',
  '-o',
  'ForwardAgent=no',
  '-o',
  'ForwardX11=no',
  if (identity.isNotEmpty) ...['-o', 'IdentitiesOnly=yes'],
  '-o',
  'ControlMaster=no',
  '-o',
  'ControlPath=none',
  if (identity.isNotEmpty) ...['-i', identity],
];

/// [word] as one POSIX shell word, quoting only when shell syntax requires it.
String quoteForAShell(String word) =>
    RegExp(r'^[A-Za-z0-9_./:@=+,-]+$').hasMatch(word) ? word : "'${word.replaceAll("'", r"'\''")}'";

/// [line] run on the far end by the account's own login shell.
///
/// **A command over ssh gets no login shell**, so `~/.local/bin` is not on its `PATH`: after a
/// per-account install it would run the machine-wide `/usr/bin/porelo` against the account's own
/// daemon of another version. A login shell reads the account's profile, which puts its own copy
/// first.
String inTheLoginShell(String line) => 'exec "\${SHELL:-/bin/sh}" -lc ${quoteForAShell(line)}';
