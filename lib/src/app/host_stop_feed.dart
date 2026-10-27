import 'package:porelo_host/porelo_host.dart';

/// The command the stop's terminal runs on this desktop when the host takes its secrets from the person's file.
///
/// The drive's login, where the host still names it, runs first in a terminal of its own on the host, as
/// [driveHost] (the account, as today's stop). Then the
/// file's lines go on a pipe into `sudo porelo-host-stop --stdin`: the master password is typed once, here, and no
/// secret reaches an argument, the far end's terminal or this program.
List<String> hostStopFeedCommand({
  required String secretsFile,
  required String project,
  required List<String> needs,
  required String ssh,
  required List<String> sshOptions,
  required String host,
  String? driveHost,
  String email = '',
  String cli = SecretsFile.keepassxcCli,
}) {
  final unknown = needs.where((need) => need != 'drive' && !SecretsFile.stopNeeds.contains(need));
  if (unknown.isNotEmpty) {
    throw FormatException('The host asked for ${unknown.join(', ')}, which the secrets file does not give.');
  }
  final fed = needs.where(SecretsFile.stopNeeds.contains).toList();
  if (fed.isEmpty) throw const FormatException('The host asks for nothing the secrets file gives.');
  final feed = SecretsFile(secretsFile, cli: cli).stopLines(project: project, needs: fed);
  String sshLine(List<String> arguments) => [ssh, ...sshOptions, ...arguments].map(quoteForAShell).join(' ');
  final stop = 'sudo /usr/local/bin/porelo-host-stop --stdin ${fed.join(' ')}';
  final script = [
    'set -o pipefail',
    if (needs.contains('drive'))
      '${sshLine([
        '-t',
        driveHost ?? host,
        inTheLoginShell(hostStopCommand(['drive'], email: email)),
      ])} || exit \$?',
    '{\n$feed\n} | ${sshLine(['-T', host, inTheLoginShell(stop)])}',
  ].join('\n');
  // Neither the caller's startup files nor an inherited trace may run in the shell that holds the secrets.
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
