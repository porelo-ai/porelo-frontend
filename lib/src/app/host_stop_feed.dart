import 'package:porelo_host/porelo_host.dart';

/// Validates a remaining provider terminal step before an SSH process can start.
List<String> hostStopFeedCommand({
  required HostAct act,
  required String project,
  required List<String> needs,
  required String ssh,
  required List<String> sshOptions,
  required String host,
  String email = '',
}) {
  if (act == HostAct.root) throw const FormatException('Server preparation accepts no secret stops.');
  final command = hostStopCommand(needs, email: email);
  if (!ssh.startsWith('/') || !RegExp(r'^[a-z_][a-z0-9_-]*@[A-Za-z0-9][A-Za-z0-9.:-]*$').hasMatch(host)) {
    throw const FormatException('The provider terminal needs a checked SSH destination.');
  }
  return [ssh, ...sshOptions, '-t', '--', host, inTheLoginShell(command)];
}
