# F290 — The Host Functions From A Windows Desktop

```json
{
  "$schema": "issue-1.json",
  "id": "F290",
  "title": "The Host Functions From A Windows Desktop",
  "state": "Implementing",
  "size": "XL",
  "priority": "Medium",
  "rank": 13,
  "blockedBy": [],
  "covers": "Connect and Prepare from a Windows desktop: loopback ports the window holds itself, each connection carried over its own ssh, the daemon through the relay, no master."
}
```

**Why this size.** XL: the card's ssh config; a loopback listener the window holds on both families through every
reconnect; a carrier of each connection over its own ssh, bounded in children, rate and buffers; readiness proven by
the daemon's own answer; the host reads' ssh; and their tests, several of them run on Windows against a native
contender; Core's and Matrix's parts are their own. The Windows vault unlock left this issue for
[F512](README.md#f512); the carrier, its bounds and their tests stay, so the size stays XL and the estimate as it was.

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
  family refuses the connection, naming the port; nothing falls back to ssh's `-L`. Both families are required: a
  desktop with no IPv6 loopback (`::1`) is refused at Connect, with the system's reason, rather than held on one.
- **Each connection over its own ssh:** a connection accepted there starts `ssh -F <card config> -T <host> <relay
  command for that socket>`, and the window copies bytes both ways between the two until either end closes, then ends
  that ssh. Nothing else is accepted: a port carries only to its own agreed remote socket.
- **The daemon through [F108](README.md#f108)'s relay:** `ssh -F <card config> -T <host> porelo daemon connect --socket
  <daemon socket>`, spoken over its byte streams through `Backend.relay`, as now.
- **Up** only on a valid answer of the daemon's (GetInfo) through the current relay's own ssh connection, pinned host
  key and card key, also for a card with no ports; nothing is believed from ssh's own words or stderr, and an answer
  that arrives after the card was released sets nothing. The fast path that counts a card with no services as up
  without asking goes.
- **Held through every reconnect.** The listeners are bound once, every one of them before any connection is carried
  (a partial bind releases what it bound and refuses), and kept while ssh fails, a key is awaited or the card
  reconnects; while the card is not up, a connection is accepted and closed at once, never left to another program.
  They are released only when the person disconnects the card or the window ends.
- **Bounded.** Each connection's ssh uses the person's key, so the carrier caps the children per card and in all
  (pending and active), the rate of new ones, and the bytes buffered per connection, gives each handshake a deadline,
  and reaps a child that starts after its connection was cancelled. Past a cap a connection is closed at once. The
  defaults: 16 per card, 48 in all, 8 starts a second per card, 256 KiB buffered each way, 30 s to the first byte. The
  daemon's ssh relays have places of their own: one for each of its four watches (Watch, Prompts, Talk,
  Authorizations), held while it runs, and 4 per card for every other call, of which a stream holds at most 3; a call
  past them waits for a place in turn and is never refused. The cap of all counts the daemon's relays and readiness
  probes beside the carried connections, a relay waits there in turn too, and the daemon's watches and streams never
  hold its last place, which is kept for a call; a place is free only once its child has exited.
- **The relay command is a contract**, agreed with Core: `porelo service connect <forge-web|forge-git|homeserver>`
  takes exactly one argument, the role, mapped on the host to its fixed socket (`/run/porelo-forge/web.sock`,
  `/run/porelo-forge/git.sock`, `/run/porelo-matrix/client.sock`), connects to it as the person and puts only the
  service's bytes on standard output. It refuses a socket others may write, or one below a directory that is not
  root's or that others may write. A role it does not know exits 64 (a porelo on the host older than the role); a
  host that serves none (no socket), a socket that refuses, or a socket it refuses exits 69, naming the role on
  standard error; a connection that fails while carrying exits 70. The window says each on the card, 64 and 69 as the
  host offering no such service and 70 as the service breaking off. The carrier passes only the role of the port it
  holds.
- **No `ControlMaster` on Windows.** The config written there leaves out `ControlMaster`, `ControlPath` and
  `ControlPersist`. Whoever else needs the host opens a connection of its own through the same `-F` file. The host
  vault is not unlocked from Windows here: Core's `porelo host unlock` does not run there, and the window does its
  steps itself under [F512](README.md#f512).
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
- `lib/src/app/loopback_carrier.dart` (new): `LoopbackCarrier(ports, carry: ...)` and its `hold()` bind each port on
  both families through a seam, exclusively; Dart's Windows listener sets `SO_EXCLUSIVEADDRUSE` before its bind on
  both families, which a reading of its source confirmed and the native contender tests prove on the Windows build
  alone. Each accepted socket gets its own process from `carry(role)` and the bytes are copied both ways; either end
  closing closes the other and ends the process. `release()` closes the listeners and every connection and waits,
  bounded, for each process to exit.
- `Tunnel` (`lib/src/app/tunnel.dart`): on Windows a card machine's tunnel is the carrier, started with the card's
  ports, no ssh of its own; up once the carrier holds every port and the relay answers; down when released.
- The relay command per socket is Core's `porelo service connect` (above); the carrier names the socket by its agreed
  role, never by a path a caller passes.
- **Red first:** `test/app/loopback_carrier_test.dart`, untagged, run on Linux and in the Windows build's tests: a
  port another socket holds refuses the hold on either family; while held, a second bind of the port fails (on
  Windows too, with `SO_REUSEADDR` set by the other side); a connection is carried to the process `carry` gives and
  its bytes arrive both ways; closing either end ends the process; `release` closes everything.
  The Windows exclusivity tests use a native contender (FFI) that sets `SO_REUSEADDR` before its bind, on both
  families, and check where a connection is delivered; a second Dart bind alone proves nothing. They skip off Windows,
  so they are proven only by the Windows build's test step. A flood of connections
  against stalled ssh children stays within the caps and keeps the listeners; a partial bind and a cancel during
  start leave nothing bound or running; each port reaches its own role, with a fake that records the role (an echo
  cannot tell a misroute). `test/app/host_card_tunnel_windows_test.dart`: the Windows card tunnel starts no ssh with
  `-L` or `-R`, holds both families of each port through a reconnect, and is up only on the daemon's answer: stderr
  with a banner alone, malformed output, failed authentication and an answer after release leave it down. A carried
  connection whose relay exits 64, 69 or 70 is said on the card as above; one the client ended says nothing.
- `CoreHostUnlocker` stays as it is: on Windows the vault unlock is [F512](README.md#f512)'s.

## Parts of other repositories

Each is its own piece, agreed in the room before this is built:
- **Core:** agreed: `porelo service connect <role>` on the host joins its standard input and output to one
  service socket by its role (forge web, forge Git, homeserver), as `porelo daemon connect` does for the daemon's,
  with the exits above: 64, 69 and 70 (porelo#B677). Where Core puts the person's key into KeePassXC on Windows, it
  sets no confirmation per use.
- **Matrix:** the messenger's return endpoint on Windows, carried as above once it exists; not part of this build.

## Acceptance

- On Windows, with the ssh stand-in: each card port held by the window on both families, exclusively; each connection
  carried over its own ssh; no ssh with `-L` or `-R`; the daemon reached through the relay; nothing is a local unix
  socket and nothing asks for a master.
- While the window holds a card's ports (from the first Connect to the card's disconnect or the window's end), no
  other program receives a connection meant for the card on either family: it cannot bind or share them. Before
  that, a program that already holds a port makes Connect refuse, and the window opens no forge or Element address of
  that card until the card is up. Outside that time a saved address in a browser is the person's own; protecting it
  would need an authenticated endpoint, which is not part of this issue.
- A flood of local connections leaves the card's ports held and the person's key used within the caps.
- On Linux, the card tunnel's arguments and config are unchanged; the existing tests stay green unchanged.
- In the operator's Windows test: Connect and Prepare against a real host, asking for no confirmation of the key per
  connection once KeePassXC's database is open.

## To be checked

- On the Windows build: that the native contender tests pass, so a later bind with `SO_REUSEADDR` fails on both
  families; else the carrier sets `SO_EXCLUSIVEADDRUSE` itself.
- On Windows: the time an ssh handshake per connection adds to a forge page and to a Git fetch.

## Estimate

`F290 size=XL est=240 basis=no measured XL median; M median 61 (24 records), about four times`
