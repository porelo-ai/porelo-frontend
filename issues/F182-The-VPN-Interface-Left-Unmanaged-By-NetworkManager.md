# F182 — The VPN Interface Left Unmanaged By NetworkManager

**Status:** Review.
**Size:** XS - `_vpnRootStep` in `lib/src/app/host_vpn.dart` and its test in `test/host_vpn_test.dart`.

**What must be true.** When the interface brings the `porelo` WireGuard tunnel up on Linux, its
single `sudo` step writes `/etc/NetworkManager/conf.d/porelo.conf` marking the `porelo` interface
unmanaged the first time and reloads NetworkManager, so replacing or taking down `porelo` does not
trigger a desktop `"Connection failed"` notification from NetworkManager.

## Plan

- **Where it is today.**
  - The VPN root script is `_vpnRootStep` in `lib/src/app/host_vpn.dart` (lines 39–74), which
    `hostVpnUpCommand` (`lib/src/app/host_vpn.dart`, line 30) runs inside a single `sudo /bin/sh -c`
    invocation in `HostVpnDialog` (`lib/src/ui/host_vpn_dialog.dart`).
  - `_vpnRootStep` copies the staged tunnel file to `/etc/wireguard/porelo.conf`, runs
    `wg-quick down porelo >/dev/null 2>&1 || true`, and then runs `wg-quick up porelo`.
  - On a Linux desktop with NetworkManager, NetworkManager watches every network interface by
    default; when `wg-quick down porelo` removes the `porelo` link, NetworkManager treats it as a
    failed connection and shows a desktop notification (`"Connection failed — Activation of network
    connection failed"`).
- **Steps.**
  1. In `_vpnRootStep` (`lib/src/app/host_vpn.dart`), under the same `sudo /bin/sh -c` call and
     before `wg-quick down porelo`, check whether `/etc/NetworkManager/conf.d` exists as a directory
     and `/etc/NetworkManager/conf.d/porelo.conf` does not already contain the unmanaged rule.
  2. When `/etc/NetworkManager/conf.d` exists and `/etc/NetworkManager/conf.d/porelo.conf` is absent
     or differs, write `/etc/NetworkManager/conf.d/porelo.conf` with mode `0644` and content:
     ```ini
     [keyfile]
     unmanaged-devices=interface-name:porelo
     ```
     and reload NetworkManager's configuration (`nmcli general reload conf >/dev/null 2>&1 || true`,
     taking `nmcli` from the root tool paths in `lib/src/app/host_vpn.dart` when present) before
     running `wg-quick down porelo` and `wg-quick up porelo`.
- **Tests, their harm, red first.**
  - *Harm:* a malformed shell command in `_vpnRootStep` breaks the root script under `sudo /bin/sh
    -e` (for example on a system without NetworkManager or when `nmcli` is absent), preventing the
    VPN from coming up.
  - In `test/host_vpn_test.dart`, execute the script produced by `hostVpnUpCommand` against a
    temporary root directory both with and without an `etc/NetworkManager/conf.d` directory, and
    assert that `etc/NetworkManager/conf.d/porelo.conf` is written with `[keyfile]` and
    `unmanaged-devices=interface-name:porelo` and that a second run does not rewrite or reload it.
    Break the content check first and watch the test fail.
  - Words, colors, and layout get no test.

## Acceptance

- Bringing the VPN up the first time on a machine with `/etc/NetworkManager/conf.d` writes
  `/etc/NetworkManager/conf.d/porelo.conf` with `unmanaged-devices=interface-name:porelo` and reloads
  NetworkManager under the existing single `sudo` prompt.
- Subsequent VPN up or down runs do not cause NetworkManager to display a `"Connection failed"`
  desktop popup.
