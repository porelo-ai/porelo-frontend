# F172 — The VPN As The Setup's Last Step

**Status:** Backlog.
**Size:** L - a root step on this computer taking the tunnel's configuration without a file the person saves, its check by ping and handshake, the machine's ready state after it, and a later row when the tunnel is missing.

**What must be true.** After the stop, the setup brings the VPN up itself: a terminal on this
computer asks only for the sudo password, the configuration goes straight to `/etc/wireguard`, the
interface checks a ping and the handshake, the terminal ends with a plain line that the server is
ready and reachable, and only then the machine counts as done. A *Needs you* row appears only when
the tunnel is missing later; a VPN file for another device only on request from the machine's menu.

## Plan

- **Today**, read in the code: the client configuration is built only by `HostFiles.exportTunnel`
  (`packages/porelo_host/lib/src/host_files.dart`), with no `PersistentKeepalive`, into a file the
  person saves; *Bring the VPN up* runs `sudo install … && sudo wg-quick up porelo` on that file
  (`host_vpn.dart`) and calls exit 0 success with no check; then offers to delete the file
  (`host_vpn_dialog.dart`). `HostRuns._addHost` sets the machine ready before any of it.
- **The configuration:** `[Peer]` gains `PersistentKeepalive = 25` (the host cannot keep a NATed
  peer's tunnel alive). It reaches root through a file created `0600` in this account's runtime
  directory (`$XDG_RUNTIME_DIR`, a tmpfs), removed by the interface right after the terminal ends,
  on every exit; the private key is never on a command line or in the terminal.
- **The root step:** one terminal on this computer runs `sudo sh -c '…' porelo-vpn <file>`:
  `install -m 600` to `/etc/wireguard/porelo.conf` (refused when a `porelo` interface for another
  host is already up: its endpoint compared first), `wg-quick up porelo`, `ping -c 3 -W 2
  10.73.0.1`, then `wg show porelo latest-handshakes` must name the host's public key with a time
  after the start. Only then it prints *The VPN is up and the server answers. You can close this
  window.*; on any failure the step that failed, in words.
- **Ready:** `HostPreparation` gets a phase *reachable*; *Machines* shows *Setting up the VPN* until
  the check passed, and the dialog closes itself on success. Afterwards a *Needs you* row *The VPN
  to <project> server is down* with *Bring the VPN up again* appears only when a ping through the
  tunnel fails at start or on a refresh.
- **The menu:** *Save the VPN connection…* stays, for another device, saying so; *Bring the VPN
  up* runs the same root step.
- **Tests, their harm, red first:** exit 0 without a handshake for the expected key leaves the
  machine not ready (a false *done*); the temporary file is gone after success, failure and a
  cancelled sudo (a private key left on disk); an up tunnel of another host is not overwritten.
  Words get no test.

- *Taken until the operator answers otherwise:* **Two servers at once:** the tunnel is one interface `porelo` with fixed addresses, so a second
  host would overwrite the first. Recommended and taken for now: refuse a second while one is up,
  saying so; separate interfaces per host later, as an issue of its own.

## Acceptance

- On the VM (a local WireGuard peer standing in for the host) and on the next rented host: one
  sudo password, the success line, *Machines* ready only after the handshake; no file left in the
  runtime directory.
