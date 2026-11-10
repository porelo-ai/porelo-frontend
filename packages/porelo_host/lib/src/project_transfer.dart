import 'dart:io';

import 'host_card_ssh.dart';
import 'secrets_file.dart';
import 'ssh.dart';

/// The local terminal's submission marker, consumed before showing host output.
const projectTransferSubmitted = '__PORELO_CENTRAL_TRANSFER_SUBMITTED__';

/// The local terminal's confirmation that credential checks sent nothing.
const projectTransferNotSubmitted = '__PORELO_CENTRAL_TRANSFER_NOT_SUBMITTED__';

/// The prefix attached only to public, shell-redacted host output.
const projectTransferOutput = '__PORELO_CENTRAL_TRANSFER_OUTPUT__';

/// Builds the terminal-only feed of the host admin's central token to `org refresh`, as root through the same pinned
/// config: the host takes a token only while something waits for one, so this runs only then.
///
/// [marked] adds the submission markers and the output prefix a reader of the terminal consumes; a terminal shown to the
/// person as it is leaves it false and shows the host's lines alone.
List<String> organizationRefreshFeedCommand({
  bool marked = false,
  required HostCardSsh card,
  required String config,
  required CentralToken token,
  Map<String, String>? environment,
  bool? windows,
  String ssh = '/usr/bin/ssh',
}) => _tokenFeedCommand(
  remote: '/usr/sbin/porelo-host org refresh',
  target: 'root@${card.name}',
  marked: marked,
  ownConnection: true,
  card: card,
  config: config,
  token: token,
  environment: environment,
  windows: windows,
  ssh: ssh,
);

/// `org refresh` as root on [card]'s machine, to run directly with the token written to its standard
/// input: the way of a token this computer already keeps, so no terminal reads it from a file.
///
/// It holds public values only, and a caller must keep it so: a token is no argument here.
List<String> organizationRefreshArguments({
  required HostCardSsh card,
  required String config,
  Map<String, String>? environment,
  bool? windows,
  String ssh = '/usr/bin/ssh',
}) {
  HostCardSsh.checkConfigPath(card.name, config, environment: environment, windows: windows ?? Platform.isWindows);
  SecretsFile.checkPath(ssh);
  return _sshInvocation(
    ssh: ssh,
    config: config,
    ownConnection: true,
    target: 'root@${card.name}',
    remote: '/usr/sbin/porelo-host org refresh',
  );
}

List<String> _sshInvocation({
  required String ssh,
  required String config,
  required bool ownConnection,
  required String target,
  required String remote,
}) => [
  ssh,
  '-F',
  config,
  for (final entry in pinnedHostSshPolicy('$config.known_hosts').entries) ...['-o', '${entry.key}=${entry.value}'],
  '-o',
  'ControlMaster=no',
  // A push goes down the person's own master or not at all. Root has its own connection: a new host has made no
  // account for a master yet, and a master's user would not be root.
  if (ownConnection) ...['-o', 'ControlPath=none', '-o', 'ProxyCommand=none'] else ...['-o', 'ProxyCommand=false'],
  '-o',
  'ConnectTimeout=10',
  '-T',
  '--',
  target,
  remote,
];

List<String> _tokenFeedCommand({
  required String remote,
  required String target,
  required bool marked,
  bool ownConnection = false,
  required HostCardSsh card,
  required String config,
  required CentralToken token,
  required Map<String, String>? environment,
  required bool? windows,
  required String ssh,
}) {
  HostCardSsh.checkConfigPath(card.name, config, environment: environment, windows: windows ?? Platform.isWindows);
  SecretsFile.checkPath(ssh);
  final scripts = token.projectTransferScripts();
  final command = _sshInvocation(
    ssh: ssh,
    config: config,
    ownConnection: ownConnection,
    target: target,
    remote: remote,
  ).map(quoteForAShell).join(' ');
  final script = [
    'set +x',
    'set -euo pipefail',
    'umask 077',
    'unset MASTER transfer_token transfer_encoded transfer_line',
    'transfer_submitted=no',
    r'transfer_tty="$(/usr/bin/stty -g 2>/dev/null || true)"',
    "finish_transfer() { local code=\$?; trap - EXIT INT TERM HUP; "
        "${marked ? "if [ \"\$transfer_submitted\" = no ]; then printf '\\n%s\\n' '$projectTransferNotSubmitted'; fi; " : ''}"
        r'if [ -n "$transfer_tty" ]; then /usr/bin/stty "$transfer_tty" 2>/dev/null || true; fi; exit "$code"; }',
    "trap finish_transfer EXIT",
    "trap 'exit 130' INT",
    "trap 'exit 143' TERM",
    "trap 'exit 129' HUP",
    'if [ -t 0 ]; then /usr/bin/stty -echo; fi',
    // A conditional check would suppress errexit inside credential validation.
    '{\n${scripts.check}\n} >/dev/null',
    'if [ ! -x ${quoteForAShell(ssh)} ]; then echo "The local SSH command is unavailable; nothing was sent." >&2; '
        "exit 1; fi",
    r'''redact() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line//"$transfer_token"/[redacted]}"
    line="${line//"$transfer_encoded"/[redacted]}"
    printf '%s%s\n' '@PUBLIC_OUTPUT@' "$line"
  done
}'''
        .replaceAll('@PUBLIC_OUTPUT@', marked ? projectTransferOutput : ''),
    if (marked) "printf '\\n%s\\n' '$projectTransferSubmitted'",
    'transfer_submitted=yes',
    'shopt -s lastpipe',
    'set +e',
    '{ ${scripts.feed}; } | $command 2>&1 | redact',
    r'codes=("${PIPESTATUS[@]}")',
    r'if [ "${codes[2]}" != 0 ]; then exit 255; fi',
    r'exit "${codes[1]}"',
  ].join('\n');
  return [
    '/usr/bin/env',
    '-u',
    'BASH_ENV',
    '-u',
    'ENV',
    '-u',
    'SHELLOPTS',
    '-u',
    'BASHOPTS',
    '/bin/bash',
    '--noprofile',
    '--norc',
    '-c',
    script,
  ];
}
