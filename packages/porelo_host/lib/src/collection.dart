/// The collection carried beside porelo-host, pinned independently of the command's version.
const hostCollection = (
  version: '0.5.3',
  fileName: 'porelo-host-0.5.3.tar.gz',
  // The digest in porelo-host v0.5.3's own SHA256SUMS.
  sha256: 'ea20eb72a9d6b34e819ca5f1ecc5b7f41b86b0f1232ce22e13da70f703939d9f',
);

/// The collection mounts the synced tresor here on the host.
const hostDrivePath = '/srv/porelo-host/drive';
