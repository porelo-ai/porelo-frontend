# F290 — The Host Functions From A Windows Desktop

```json
{
  "$schema": "issue-1.json",
  "id": "F290",
  "title": "The Host Functions From A Windows Desktop",
  "state": "Accepted",
  "size": "M",
  "priority": "Medium",
  "rank": 24,
  "blockedBy": [],
  "covers": "Connect and Prepare from a Windows desktop: one ssh per host card with loopback TCP ends, the daemon through the relay, no master."
}
```

**Why this size.** the card's ssh config, the card tunnel's arguments, the card machine's relay and their tests in this
repository; Core's and Matrix's parts are their own.

**What must be true.** On Windows, a person connects to a machine, and a Machine Admin prepares it and names its
people, as on Linux: through the host's card, with the same `-F` file and the same fixed ports. Linux stays as it is.

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

## Plan

- `HostCardSsh` (`packages/porelo_host/lib/src/host_card_ssh.dart`): on Windows the written config has no master lines.
- `Tunnel` (`lib/src/app/tunnel.dart`): on Windows the card's arguments drop `-M` and the daemon's `-L`, and the return
  forward targets `127.0.0.1:<port>`. The tunnel counts as up once a connection through a service forward arrives, as
  there is no local socket to wait for.
- `Machine` (`lib/src/app/machines.dart`): a card machine on Windows gets the relay above, and `whyNotReachableOn`
  stops refusing it ("Machine card connections require OpenSSH Unix socket and master support on this platform.").
- `organization_connections.dart` (`CardHostConnections`): no change expected; `SshHostProgress`'s ssh calls
  already take `ControlMaster=no` and the card's `-F` file.
- `SshHostProgress` (`lib/src/app/host_progress.dart`) starts `ssh` by name, so on Windows another `ssh.exe` on
  `PATH` or in the current folder is taken. It takes `openSsh('ssh')`, Windows' own OpenSSH.
- **Red first:** in `test/app/tunnel_test.dart`, with the Windows desk and the ssh stand-in, the arguments hold no
  `-M`, no local unix path and a `-R` to `127.0.0.1`; in `test/app/wsl_test.dart`, a card machine on Windows is
  reached through the relay instead of refused.

## Parts of other repositories

Each is its own piece, agreed in the room before this is built:
- **Core:** `porelo host unlock <host>` and the host commands work through the card's `-F` file without a master,
  opening their own connection.
- **Matrix:** the messenger offers its return endpoint as a TCP port on `127.0.0.1` on Windows, which this interface
  forwards with `-R`.

## Acceptance

- On Windows, with the ssh stand-in: one ssh process per card with the TCP forwards and the return forward; the
  daemon reached through the relay; Core's unlock started as its own process with `-F`; nothing is a local unix
  socket and nothing asks for a master.
- On Linux, the card tunnel's arguments and config are unchanged; the existing tests stay green unchanged.
- In the operator's Windows test: Connect and Prepare against a real host.

## To be checked

- **Measured on Windows first, before building:** that Windows' OpenSSH client carries `-L 127.0.0.1:<port>:<remote
  unix socket>` and `-R <remote unix socket>:127.0.0.1:<port>`, with `ExitOnForwardFailure=yes`, and how it answers
  `ControlMaster` options it does not support.
- That the KeePassXC agent's confirmation per connection is acceptable now that every user of the host opens its own.

## Estimate

`F290 size=M est=60 basis=median M 61 (24 records)`
