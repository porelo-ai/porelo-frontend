/// The collection carried beside porelo-host, pinned independently of the command's version.
///
/// A release carries the release pinned here; a snapshot build compiles in the snapshot collection it carries with
/// `-Dporelo_host.collection.version=… -Dporelo_host.collection.file=… -Dporelo_host.collection.sha256=…`.
const hostCollection = (
  version: String.fromEnvironment('porelo_host.collection.version', defaultValue: '0.5.12'),
  fileName: String.fromEnvironment('porelo_host.collection.file', defaultValue: 'porelo-host-0.5.12.tar.gz'),
  // The default is the digest in porelo-host v0.5.12's own SHA256SUMS.
  sha256: String.fromEnvironment(
    'porelo_host.collection.sha256',
    defaultValue: '66cee23af5aaaf47b9bcfc75ca814595b03aafe19dd86721be2705c849c1150d',
  ),
);
