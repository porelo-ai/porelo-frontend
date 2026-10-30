import 'ssh.dart';

/// The two transfers a person may explicitly start with the central forge.
enum ProjectTransfer {
  /// Sends approved local main to central main.
  push,

  /// Brings central main to the host as central/main for a local pull request.
  pull,
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
