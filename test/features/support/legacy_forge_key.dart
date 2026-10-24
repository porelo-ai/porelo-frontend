/// A deploy key a forge holds for one repository.
class ForgeDeployKey {
  /// The forge's own id for it, which removing it takes.
  final int id;

  /// What it is called: `porelo <machine> <project>/<repository>` for one a machine made.
  final String title;

  /// The public key, `ssh-ed25519 AAAA…`.
  final String key;

  /// Whether it may only read.
  final bool readOnly;

  /// Constructor taking every field.
  const ForgeDeployKey({required this.id, required this.title, required this.key, required this.readOnly});

  /// Whether a Porelo machine made it, by its title.
  bool get isPorelos => title.startsWith('porelo ');
}
