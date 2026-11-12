# F290 — The Host Functions From A Windows Desktop

```json
{
  "$schema": "issue-1.json",
  "id": "F290",
  "title": "The Host Functions From A Windows Desktop",
  "state": "Backlog",
  "size": "M",
  "priority": "Medium",
  "rank": 13,
  "blockedBy": [],
  "covers": "Connect and Prepare from a Windows desktop: one ssh per host card with loopback TCP ends, the daemon through the relay, no master."
}
```

**Why this size.** M: the card's ssh config, the card tunnel's start and its wait, the card machine's reach and
relay, the host reads' ssh and their tests, all in this repository; Core's and Matrix's parts are their own.

**What must be true.** On Windows, a person connects to a machine, and a Machine Admin prepares it and names its
people, as on Linux: through the host's card, with the same `-F` file and the same fixed ports. Linux stays as it is.

## Decided by the operator (2026-11-12)

- On Windows every user of the host opens its own connection: the tunnel, the relay, Core's unlock and each host read.
  The key is used there once per session, with no confirmation per use: KeePassXC's agent is not asked to confirm each
  connection.

## How it stands

`Machine.whyNotReachableOn` in `lib/src/app/machines.dart` refuses card connections on Windows with
"Machine card connections require OpenSSH Unix socket and master support on this platform."
`HostCardSsh._contents` in `packages/porelo_host/lib/src/host_card_ssh.dart` always writes `ControlMaster`,
`ControlPath` and `ControlPersist`. These files do not meet the Windows promise above.
`Identity.cardFile` in `lib/src/app/identity.dart` uses `XDG_CONFIG_HOME`, else the home folder's config folder.
`PoreloOrganizationSource` in `lib/src/app/porelo_organization_source.dart` runs the organization commands;
`SshHostProgress` in `lib/src/app/host_progress.dart` reads host state over SSH as root.
`SshHostProgress._ask` already turns a `ProcessException` into a refusal, but `_ssh` starts `ssh` by name.

## The shape

The card connection of today, adapted; no new design.
- **One ssh process per host card**, started with `-F` the card's config file as today, carrying every forward.
- **Local ends are TCP on `127.0.0.1`, never a local unix socket:**
  - the services as today: `-L 127.0.0.1:<port>:<remote unix socket>` for the forge's web and Git sockets and the
    homeserver's;
  - the return channel `-R <return socket>:127.0.0.1:<port>`, to the messenger listening on that loopback port.
- **The daemon through [F108](README.md#f108)'s relay:** `ssh -F <card config> -T <host> porelo daemon connect --socket
  <daemon socket>`, spoken over its byte streams through `Backend.relay`; no `-L` for the daemon on Windows.
- **No `ControlMaster` on Windows.** The config written there leaves out `ControlMaster`, `ControlPath` and
  `ControlPersist`, and the tunnel is started without `-M`. Whoever else needs the host, such as Core's `porelo host
  unlock`, opens a connection of its own through the same `-F` file.
- **One use of the key per session.** The person's key is held by KeePassXC's agent while the database is open, with
  no confirmation per use, so the several connections ask nothing of the person. The window asks for no confirmation
  of its own.

## Plan

- `HostCardSsh` (`packages/porelo_host/lib/src/host_card_ssh.dart`): `publish`, `checkPublished` and `_contents` take
  `windows`, as `configPath` does, instead of `Platform.isWindows`. On Windows `_contents` writes no master lines and
  does not call `checkLocalSocket` on `controlSocket`: that check refuses a colon, so today every `C:\` config path
  is refused before a file is written.
- `Tunnel` (`lib/src/app/tunnel.dart`): on Windows `_cardCommand` drops `-M` and the daemon's `-L`, and the return
  forward is `-R <return socket>:127.0.0.1:<port>`. `_raiseCard` there skips what holds a master: the endpoint check
  of `controlSocket`, `_mastersHere`, `_endOrphanedMaster` and the wait on `ssh -O check`; it counts the tunnel as up
  once the first of the card's loopback ports accepts a connection. `HostCardSsh.checkMessengerSocket`, which checks a
  unix path, is not called for a port.
- `Tunnels._raiseFor` (same file) raises no tunnel for a machine with a relay. A card machine on Windows gets both:
  the relay for the daemon and its tunnel for the services, the return forward and Core's unlock.
- `Machine` (`lib/src/app/machines.dart`): `whyNotReachableOn` stops refusing a card machine on Windows ("Machine
  card connections require OpenSSH Unix socket and master support on this platform."). `relayOn` then already builds
  `ssh -F <card config> -o ControlMaster=no ... -T <host> porelo daemon connect --socket <daemon socket>` through
  `loginSshOptionsOn`; `Backend.relay` (`lib/src/client/porelo_client.dart`) carries it.
- `CardHostConnections` (`lib/src/app/organization_connections.dart`) and `CoreHostUnlocker`
  (`lib/src/app/fleet_backend.dart`): no change expected; the unlock is its own `porelo host unlock` process.
- `SshHostProgress._ssh` (`lib/src/app/host_progress.dart`) runs `ssh` by name through `runHere`, so on Windows
  another `ssh.exe` on `PATH` or in the current folder is taken. It takes `openSsh('ssh')`, Windows' own OpenSSH.
- **Red first:** in `packages/porelo_host/test/host_card_ssh_test.dart`, the Windows config of a card has no
  `ControlMaster`, `ControlPath` or `ControlPersist` and a `C:\` path is not refused. In `test/app/wsl_test.dart`,
  which already sets a Windows `Desk`, a card machine on Windows has a relay instead of the refusal. The card
  tunnel's own tests in `test/app/host_card_tunnel_test.dart` are tagged `linux` (chmod, unix control sockets), and
  `test/app/tunnel_test.dart` runs a real ssh on Linux; so a new untagged `test/app/host_card_tunnel_windows_test.dart`
  with a Windows `Desk`, the ssh stand-in and a fake `HostFileWriter` shows the arguments: no `-M`, no local unix
  path, a `-R` to `127.0.0.1`, and a tunnel raised beside the relay.

## Parts of other repositories

Each is its own piece, agreed in the room before this is built:
- **Core:** `porelo host unlock <host>` and the host commands work through the card's `-F` file without a master,
  opening their own connection. Where Core puts the person's key into KeePassXC on Windows, it sets no confirmation
  per use.
- **Matrix:** the messenger offers its return endpoint as a TCP port on `127.0.0.1` on Windows, which this interface
  forwards with `-R`.

## Acceptance

- On Windows, with the ssh stand-in: one ssh process per card with the TCP forwards and the return forward; the
  daemon reached through the relay; Core's unlock started as its own process with `-F`; nothing is a local unix
  socket and nothing asks for a master.
- In the operator's Windows test, Connect and Prepare ask for no confirmation of the key per connection once
  KeePassXC's database is open.
- On Linux, the card tunnel's arguments and config are unchanged; the existing tests stay green unchanged.
- In the operator's Windows test: Connect and Prepare against a real host.

## To be checked

- **Measured on Windows first, before building:** that Windows' OpenSSH client carries `-L 127.0.0.1:<port>:<remote
  unix socket>` and `-R <remote unix socket>:127.0.0.1:<port>`, with `ExitOnForwardFailure=yes`; that a loopback
  port it forwards accepts only once the connection stands; and how it answers `ControlMaster` options it does not
  support.

## Estimate

`F290 size=M est=60 basis=median M 61 (24 records)`
