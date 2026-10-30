import 'dart:io';

import 'host_card_ssh.dart';
import 'secrets_file.dart';
import 'ssh.dart';

/// The two transfers a person may explicitly start with the central forge.
enum ProjectTransfer {
  /// Sends approved local main to central main.
  push,

  /// Brings central main to the host as central/main for a local pull request.
  pull,
}

/// The local terminal's submission marker, consumed before showing host output.
const projectTransferSubmitted = '__PORELO_CENTRAL_TRANSFER_SUBMITTED__';

/// The local terminal's confirmation that credential checks sent nothing.
const projectTransferNotSubmitted = '__PORELO_CENTRAL_TRANSFER_NOT_SUBMITTED__';

/// Builds the terminal-only token feed through the already owned host connection.
List<String> projectTransferFeedCommand({
  required ProjectTransfer direction,
  required String project,
  required List<String> repositories,
  required HostCardSsh card,
  required String config,
  required SecretsFile secretsFile,
  Map<String, String>? environment,
  String ssh = '/usr/bin/ssh',
}) {
  HostCardSsh.checkConfigPath(card.name, config, environment: environment, windows: Platform.isWindows);
  SecretsFile.checkPath(ssh);
  final remote = projectTransferCommand(direction, project, repositories);
  final scripts = secretsFile.projectTransferScripts();
  final command = [
    ssh,
    '-F',
    config,
    '-o',
    'ControlMaster=no',
    '-o',
    'ProxyCommand=false',
    '-o',
    'ConnectTimeout=10',
    '-T',
    '--',
    card.name,
    remote,
  ].map(quoteForAShell).join(' ');
  final script = [
    'set +x',
    'set -euo pipefail',
    'umask 077',
    'unset MASTER transfer_token transfer_encoded transfer_line',
    'if transfer_line="\$(\n${scripts.check}\n${scripts.feed}\n)"; then :; else',
    "  printf '%s\\n' '$projectTransferNotSubmitted'; exit 1",
    'fi',
    r'transfer_encoded="${transfer_line#* }"',
    r'''transfer_token="$(printf '%s' "$transfer_encoded" | /usr/bin/base64 -d)"''',
    'unset transfer_line',
    'if [ ! -x ${quoteForAShell(ssh)} ]; then echo "The local SSH command is unavailable; nothing was sent." >&2; '
        "printf '%s\\n' '$projectTransferNotSubmitted'; exit 1; fi",
    r'''redact() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line//"$transfer_token"/[redacted]}"
    line="${line//"$transfer_encoded"/[redacted]}"
    printf '%s\n' "$line"
  done
}''',
    "printf '%s\\n' '$projectTransferSubmitted'",
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

/// The agreed own-account host invocation, containing public selections only.
String projectTransferCommand(ProjectTransfer direction, String project, List<String> repositories) {
  if (!RegExp(r'^[a-z0-9]([a-z0-9-]{0,38}[a-z0-9])?$').hasMatch(project)) {
    throw const FormatException('Choose a lower-case project name of at most forty characters.');
  }
  for (final name in repositories) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]*$').hasMatch(name)) {
      throw const FormatException('Choose a project and repository by name, without a path or option.');
    }
  }
  return inTheLoginShell(
    [
      'porelo-host-push',
      if (direction == ProjectTransfer.pull) '--pull',
      project,
      ...repositories,
    ].map(quoteForAShell).join(' '),
  );
}
