import 'host_record.dart';
import 'secrets_file.dart';
import 'server_contract.dart';
import 'ssh.dart';

/// Runs project removal in the admin's terminal, piping the optional token only to SSH's stdin.
/// Only the helper's public stdout and stderr are written in [replyDirectory].
List<String> projectRemovalFeedCommand({
  required String project,
  required SecretsFile secretsFile,
  required PreparedHost host,
  required String identity,
  required String knownHosts,
  required String replyDirectory,
  String ssh = '/usr/bin/ssh',
}) {
  final request = HostAdminRequest.remove('project', 'remove', project);
  if (!ssh.startsWith('/') || ssh.contains('\x00')) throw const FormatException('ssh is run by its absolute path.');
  SecretsFile.checkPath(replyDirectory);
  final command = [
    ssh,
    ...pinnedHostSshOptions(knownHosts, identity),
    '-o',
    'ConnectTimeout=10',
    '-T',
    '--',
    'root@${host.vpnAddress}',
    request.command,
  ].map(quoteForAShell).join(' ');
  final answer = quoteForAShell('$replyDirectory/answer');
  final refusal = quoteForAShell('$replyDirectory/refusal');
  final script = [
    'set +x',
    'umask 077',
    'set -o pipefail',
    "trap '/usr/bin/stty echo 2>/dev/null || true' EXIT",
    '/usr/bin/stty -echo 2>/dev/null || true',
    // Local validation must finish before the destructive helper can receive tokenless input.
    'removal_token="\$(\n${secretsFile.projectRemovalTokenLine()}\n)" || exit \$?',
    r'''{ if [ -n "$removal_token" ]; then printf '%s\n' "$removal_token"; fi; } | '''
        '$command > $answer 2> $refusal',
    r'result=$?',
    '/usr/bin/cat -- $answer',
    '/usr/bin/cat -- $refusal >&2',
    r'exit "$result"',
  ].join('\n');
  // Startup files and inherited tracing must never run in the shell holding the token.
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
