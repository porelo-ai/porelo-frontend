import 'dart:io';

import 'package:path/path.dart' as path;

/// The host keys pinned by `porelo-host`, shared by its command and the interface.
String poreloHostKnownHosts({Map<String, String>? environment, bool? windows}) =>
    '${_stateDirectory(environment, windows)}${windows ?? Platform.isWindows ? r'\' : '/'}known_hosts';

/// The persistent lock file for one project, shared by its up and down commands.
String poreloHostProjectLock(String project, {Map<String, String>? environment, bool? windows}) {
  final safe = RegExp(r'[a-zA-Z0-9_-][a-zA-Z0-9._-]*').matchAsPrefix(project);
  if (safe == null ||
      safe.end != project.length ||
      RegExp(r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)', caseSensitive: false).hasMatch(project)) {
    throw const FormatException('The project must be one safe path segment');
  }
  return '${_stateDirectory(environment, windows)}${windows ?? Platform.isWindows ? r'\' : '/'}$project.lock';
}

String _stateDirectory(Map<String, String>? environment, bool? windows) {
  final env = environment ?? Platform.environment;
  if (windows ?? Platform.isWindows) return '${env['LOCALAPPDATA']}\\porelo-host';
  final state = env['XDG_STATE_HOME'];
  final base = state != null && path.posix.isAbsolute(state) ? state : '${env['HOME']}/.local/state';
  return '$base/porelo-host';
}
