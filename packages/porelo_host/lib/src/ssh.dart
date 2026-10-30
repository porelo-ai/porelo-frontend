/// The trust and forwarding policy shared by host configs and direct SSH calls.
Map<String, String> pinnedHostSshPolicy(String knownHosts) => {
  'StrictHostKeyChecking': 'yes',
  'UserKnownHostsFile': '"$knownHosts"',
  'GlobalKnownHostsFile': 'none',
  'KnownHostsCommand': 'none',
  'VerifyHostKeyDNS': 'no',
  'UpdateHostKeys': 'no',
  'BatchMode': 'yes',
  'ForwardAgent': 'no',
  'ForwardX11': 'no',
  'IdentitiesOnly': 'yes',
};

/// The pinned trust policy, placed before every other ssh option so config cannot add trusted keys.
List<String> pinnedHostSshOptions(String knownHosts, String identity) => <String>[
  for (final entry in pinnedHostSshPolicy(knownHosts).entries) ...['-o', '${entry.key}=${entry.value}'],
  '-o',
  'ControlMaster=no',
  '-o',
  'ControlPath=none',
  '-i',
  identity,
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
