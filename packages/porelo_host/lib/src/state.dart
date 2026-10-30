import 'dart:io';

import 'package:path/path.dart' as path;

import 'host_record.dart' show checkHostName;

/// The host keys pinned by `porelo-host`, shared by its command and the interface.
String poreloHostKnownHosts({Map<String, String>? environment, bool? windows}) =>
    '${_stateDirectory(environment, windows)}${windows ?? Platform.isWindows ? r'\' : '/'}known_hosts';

/// The SSH configuration published from one verified host card.
String poreloHostSshConfig(String host, {Map<String, String>? environment, bool? windows}) {
  checkHostName(host);
  final env = environment ?? Platform.environment;
  final onWindows = windows ?? Platform.isWindows;
  final paths = onWindows ? path.windows : path.posix;
  final base = onWindows ? env['APPDATA'] : env['XDG_CONFIG_HOME'];
  final home = env['HOME'];
  final directory = base != null && paths.isAbsolute(base)
      ? base
      : !onWindows && home != null && paths.isAbsolute(home)
      ? paths.join(home, '.config')
      : throw const FormatException('The host SSH configuration needs an absolute configuration directory.');
  if (RegExp(r'[\x00\r\n]').hasMatch(directory)) {
    throw const FormatException('The host SSH configuration directory is invalid.');
  }
  return paths.join(directory, 'porelo', 'ssh', '$host.conf');
}

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
