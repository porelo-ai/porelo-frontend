/// The collection carried beside porelo-host, pinned independently of the command's version.
const hostCollection = (
  version: '0.5.2',
  fileName: 'porelo-host-0.5.2.tar.gz',
  // The digest in porelo-host v0.5.2's own SHA256SUMS.
  sha256: '45d69b6efe195532b05a7c3cb9539fd13e39d99b06469b2b9d43f40ef0c9b617',
);

/// The collection mounts the synced tresor here on the host.
const hostDrivePath = '/srv/porelo-host/drive';
