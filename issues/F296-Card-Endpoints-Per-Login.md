# F296 — Card Endpoints Per Login

**Status:** Idea.
**Severity:** medium.
**Size:** M - the card's ssh paths and local ports, the card tunnel, the join and the homeserver forwards, with their
tests; no contract with another repository.

**What must be true.** Two people of one desktop account, such as two instances of this interface, each reach their
own account on the same host through their own card tunnel at once. A card master left by an earlier run of the
same person on the same host is ended when that person's tunnel is raised again, also while its configuration file
is there.

## Why

- A card's ssh configuration (`~/.config/porelo/ssh/<host>.conf`), control socket (`c-<sha of the host name>`), daemon
  endpoint (`/run/user/<uid>/porelo-tunnel-<host>.sock`) and local ports (forge web and git, Matrix) are named after
  the host only.
- Two instances on one desktop — one for the project admin and one for a developer — share those paths on the same
  host, so only one can hold a tunnel to it; the developer instance's Join is refused while the admin instance's is up.
- When a master started before a restart of the interface is left running and Register's connect writes the
  configuration again before raising, an orphan check requiring the control socket to exist while the configuration is
  gone no longer holds, and Retry is refused with "an endpoint already exists and was left alone".
- Quitting the interface (`q` in `flutter run`) can leave its card master running and holding the local ports until
  ended by hand. Ending a same-login leftover on the next raise (commit c5aea871) does not release ports held by an
  account that does not open the interface again.
- Ending or adopting a master this instance did not start is unsafe while paths are shared: it could end the other
  instance's live tunnel, or reach another person's daemon.

## The shape

- The configuration, control socket and daemon endpoint are named `<host>-<login>`; the local ports are chosen per
  card tunnel and kept with the machine, and the Matrix forward reads them from there.
- With per-login paths, a master on this card's control socket that no tunnel here started can only be one this
  person left; it is ended with `ssh -O exit` and its endpoints removed before the tunnel is raised.

## Plan

- `packages/porelo_host/lib/src/host_card_ssh.dart` (`configPath`, `controlSocket`, ports), `lib/src/app/tunnel.dart`
  (`_endOrphanedMaster`), `lib/src/app/machines.dart` (`endpointFor`), `lib/src/app/join_adapters.dart`,
  `lib/src/app/homeserver_forwards.dart`, and the reading of machines kept with the old names.
- **Red first:** two card machines of one host and two logins raise their tunnels side by side; a live master of the
  same login with its configuration present is ended on raise.

## Acceptance

- Quitting the interface, or its window closing, ends every card master it started and removes their endpoints.

- Two instances of one account, each with its own login, hold tunnels to one host at the same time.
- Retry after a restart of the interface raises the tunnel without a hand-ended process.
- A machine kept with the old host-only names is still reached, or moved to the new names once.
