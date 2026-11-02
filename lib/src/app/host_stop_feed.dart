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
  final executable = ssh == 'ssh' || ssh.startsWith('/') || RegExp(r'^[A-Za-z]:\\').hasMatch(ssh);
  final at = host.indexOf('@');
  if (!executable ||
      at < 0 ||
      !RegExp(r'^[a-z_][a-z0-9_-]*$').hasMatch(host.substring(0, at)) ||
      !isCardAddress(host.substring(at + 1))) {
    throw const FormatException('The provider terminal needs a checked SSH destination.');
  }
  return [ssh, ...sshOptions, '-t', '--', host, inTheLoginShell(command)];
}
