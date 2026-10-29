const _ownAccountSetupPlace = '.local/share/porelo-host/setup';

/// The act a host's setup files and stop serve.
enum HostAct {
  /// The host admin prepares a server without a project.
  root,

  /// A person brings or joins a project through their own host account.
  ownAccount,

  /// The combined project setup still feeds its secrets through the image user's sudo.
  legacyUp;

  /// Where setup files live, relative to the login's home for [ownAccount].
  String get setupPlace => switch (this) {
    ownAccount => _ownAccountSetupPlace,
    root || legacyUp => '/etc/porelo-host/setup',
  };
}
