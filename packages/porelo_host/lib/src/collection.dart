/// The collection carried beside porelo-host, pinned independently of the command's version.
const hostCollection = (
  version: '0.5.4',
  fileName: 'porelo-host-0.5.4.tar.gz',
  // The digest in porelo-host v0.5.4's own SHA256SUMS.
  sha256: '30c2087a3f18e7b984e65b8f8d143301b766c28a85632d2b3bcfe8d3e074ca08',
);

/// The collection mounts the synced tresor here on the host.
const hostDrivePath = '/srv/porelo-host/drive';
