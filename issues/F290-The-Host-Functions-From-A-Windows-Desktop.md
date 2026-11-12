# F290 — The Host Functions From A Windows Desktop

```json
{
  "$schema": "issue-1.json",
  "id": "F290",
  "title": "The Host Functions From A Windows Desktop",
  "state": "Implementing",
  "size": "L",
  "priority": "Medium",
  "rank": 13,
  "blockedBy": [],
  "covers": "Connect and Prepare from a Windows desktop: loopback ports the window holds itself, each connection carried over its own ssh, the daemon through the relay, no master."
}
```

**Why this size.** L: the card's ssh config, a loopback listener the window holds on both families and a carrier of
each connection over its own ssh, the card machine's reach and relay, the host reads' ssh, and their tests, some of
them run on Windows; Core's and Matrix's parts are their own.

**What must be true.** On Windows, a person connects to a machine, and a Machine Admin prepares it and names its
people, as on Linux: through the host's card, with the same `-F` file and the same fixed ports. Linux stays as it is.

## Decided by the operator (2026-11-12)

- On Windows every user of the host opens its own connection: the tunnel, the relay, Core's unlock and each host read.
  The key is used there once per session, with no confirmation per use: KeePassXC's agent is not asked to confirm each
  connection.
- On Windows the window holds each loopback port itself, exclusively, on both families, and carries each accepted
  connection to its remote unix socket over ssh's byte streams, one ssh per connection, with no `-L`; the `-R` return
  channel the same way once the messenger has its endpoint. An ssh `-L` port on Windows can never be proven ours: ssh
  says it listens before it binds, says so on the stderr the server's banner shares, and binds with `SO_REUSEADDR`,
  so another local program could take or share the port and receive the person's sign-ins.

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

- **Local ends the window holds:** for each of the card's ports (the forge's web and Git, the homeserver's) a
  listener of the window's own on `127.0.0.1:<port>` and `[::1]:<port>`, bound exclusively (no other socket may bind
  or share the port while it is held) for as long as the card is connected. A port that cannot be bound so on either
  family refuses the connection, naming the port; nothing falls back to ssh's `-L`.
- **Each connection over its own ssh:** a connection accepted there starts `ssh -F <card config> -T <host> <relay
  command for that socket>`, and the window copies bytes both ways between the two until either end closes, then ends
  that ssh. Nothing else is accepted: a port carries only to its own agreed remote socket.
- **The daemon through [F108](README.md#f108)'s relay:** `ssh -F <card config> -T <host> porelo daemon connect --socket
  <daemon socket>`, spoken over its byte streams through `Backend.relay`, as now.
- **Up** once the listeners are held and the relay to the daemon answers through the card: that proves the card's key
  and host key; nothing is believed from ssh's own words.
- **No `ControlMaster` on Windows.** The config written there leaves out `ControlMaster`, `ControlPath` and
  `ControlPersist`. Whoever else needs the host, such as Core's `porelo host unlock`, opens a connection of its own
  through the same `-F` file.
- **The return channel** waits on the messenger's endpoint on Windows; once there, it is carried the same way, the
  window holding nothing the messenger has not bound first.
- **One use of the key per connection, none confirmed.** The person's key is held by KeePassXC's agent while the
  database is open, with no confirmation per use, so the many connections ask nothing of the person. A handshake per
  connection is the cost.
- **Linux stays as it is.**

## Plan

Built on the branch's first commits, which stay: the card's config on Windows without master lines and with its
paths (`HostCardSsh`), the relay over its own config (`Machine.relayOn`, `whyNotReachableOn`), and the host reads
through Windows' own OpenSSH (`SshHostProgress._ssh`). The Windows tunnel with `-L`, `-R` and ssh's "listening" line
goes; what replaces it:
- `lib/src/app/loopback_carrier.dart` (new): `LoopbackCarrier.hold(ports, carry)` binds each port on both families
  through a seam, exclusively; on Windows `ServerSocket.bind(shared: false)` is expected to set
  `SO_EXCLUSIVEADDRUSE` (to be checked; else FFI to `setsockopt` before `bind`). Each accepted socket gets its own
  process from `carry(port)` and the bytes are copied both ways; either end closing closes the other and ends the
  process. `release()` closes the listeners and every connection.
- `Tunnel` (`lib/src/app/tunnel.dart`): on Windows a card machine's tunnel is the carrier, started with the card's
  ports, no ssh of its own; up once the carrier holds every port and the relay answers; down when released.
- The relay command per socket is Core's (below); the carrier names the socket by its agreed role, never by a path a
  caller passes.
- **Red first:** `test/app/loopback_carrier_test.dart`, untagged, run on Linux and in the Windows build's tests: a
  port another socket holds refuses the hold on either family; while held, a second bind of the port fails (on
  Windows too, with `SO_REUSEADDR` set by the other side); a connection is carried to the process `carry` gives and
  its bytes arrive both ways; closing either end ends the process; `release` closes everything.
  `test/app/host_card_tunnel_windows_test.dart`: the Windows card tunnel starts no ssh with `-L` or `-R`, holds both
  families of each port, and is up only once the relay answers; a squatter on a port refuses the connection.

## Parts of other repositories

Each is its own piece, agreed in the room before this is built:
- **Core:** `porelo host unlock <host>` and the host commands work through the card's `-F` file without a master,
  opening their own connection. A command on the host that joins its standard input and output to one agreed
  service socket by its role (forge web, forge Git, homeserver), refusing any other, as `porelo daemon connect` does
  for the daemon's. Where Core puts the person's key into KeePassXC on Windows, it sets no confirmation
  per use.
- **Matrix:** the messenger's return endpoint on Windows, carried as above once it exists; not part of this build.

## Acceptance

- On Windows, with the ssh stand-in: each card port held by the window on both families, exclusively; each connection
  carried over its own ssh; no ssh with `-L` or `-R`; the daemon reached through the relay; nothing is a local unix
  socket and nothing asks for a master.
- A program that holds or tries to share a card's port, on either family, never receives a connection meant for the
  card: the connection is refused while it holds the port, and it cannot bind while the window holds it.
- On Linux, the card tunnel's arguments and config are unchanged; the existing tests stay green unchanged.
- In the operator's Windows test: Connect and Prepare against a real host, asking for no confirmation of the key per
  connection once KeePassXC's database is open.

## To be checked

- On Windows: that `ServerSocket.bind(shared: false)` sets `SO_EXCLUSIVEADDRUSE`, so a later bind with
  `SO_REUSEADDR` fails; else the carrier sets it itself.
- On Windows: the time an ssh handshake per connection adds to a forge page and to a Git fetch.

## Estimate

`F290 size=L est=150 basis=no measured L median; M median 61 (24 records), about two and a half times`
