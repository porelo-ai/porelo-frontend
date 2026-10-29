const _ownAccountSetupPlace = '.local/share/porelo-host/setup';

/// The act a host's setup files and stop serve.
enum HostAct {
  /// The host admin prepares a server without a project.
  root,

  /// A person brings or joins a project through their own host account.
  ownAccount,

  /// The combined project setup still feeds its secrets through the image user's sudo.
  legacyUp;

  /// Returns the setup directory for [project], relative to the login's home for [ownAccount].
  String setupPlace({String? project}) {
    if (this != ownAccount) return '/etc/porelo-host/setup';
    if (project == null || !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(project)) {
      throw const FormatException('The own-account setup directory needs a plain project name.');
    }
    return '$_ownAccountSetupPlace/$project';
  }
}
