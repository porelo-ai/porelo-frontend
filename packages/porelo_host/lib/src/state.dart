import 'dart:io';

/// The host keys pinned by `porelo-host`, shared by its command and the interface.
String poreloHostKnownHosts({Map<String, String>? environment, bool? windows}) {
  final env = environment ?? Platform.environment;
  if (windows ?? Platform.isWindows) return '${env['LOCALAPPDATA']}\\porelo-host\\known_hosts';
  final state = env['XDG_STATE_HOME'];
  final base = state != null && state.isNotEmpty ? state : '${env['HOME']}/.local/state';
  return '$base/porelo-host/known_hosts';
}
