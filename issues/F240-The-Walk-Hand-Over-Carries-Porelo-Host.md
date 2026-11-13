# F240 — The Walk Hand-Over Carries Porelo-Host

```json
{
  "$schema": "issue-1.json",
  "id": "F240",
  "title": "The Walk Hand-Over Carries Porelo-Host",
  "state": "Idea",
  "size": "S",
  "priority": "Low",
  "rank": 31,
  "blockedBy": [],
  "covers": "The walk hand-over ships `porelo-host` and the start script points the interface at it; a missing local program said without the container sentence."
}
```

**Why this size.** the VMs' walk hand-over ships `porelo-host` and the start script points the interface at it; a local command that cannot start says only that.

**How it stands.** Held: wizard changes wait until the whole flow has been gone through again.

**What must be true.** A walk's VMs get `porelo-host`, built from the same commit as their interface bundle, in the hand-over with its digest in `SHA256SUMS`. `laptop-b-start.sh` starts the interface with `PORELO_HOST_STANDIN` naming it, so *Connect a forge* and every other call of `porelo-host` work on the VMs as on the Laptop. When a command run in a terminal on this computer cannot start, the dialog names the missing program and nothing about a container.

## Why

`poreloHost()` in `lib/src/app/host_session.dart` uses `PORELO_HOST_STANDIN` in a debug build when it is set;
on Linux its default is `/usr/lib/porelo-frontend/porelo-host`. `askForForgeToken` in
`lib/src/ui/forges_view.dart` runs it on this computer. `Session._start` in `lib/src/app/session.dart` appends
the container sentence when opening a terminal fails on a machine that needs no tunnel, including this computer.
That does not meet the promise that a local failure says nothing about a container.

`test/walks_test.dart` reads walks from the external folder named by `PORELO_WALKS`. This checkout has no
`tool/walk23/hand-over.sh`; the external hand-over and `laptop-b-start.sh` are not checked here.

## Plan

- The walk hand-over in the folder named by `PORELO_WALKS` builds `porelo-host` from the same commit as the bundle,
  with `-march=x86-64`. It adds the binary as its own file with its line in `SHA256SUMS`.
- `laptop-b-start.sh` checks that file against `SHA256SUMS` with the rest, unpacks it next to the bundle, executable, and starts the interface with `PORELO_HOST_STANDIN` naming it.
- `session.dart` adds the container sentence only for a daemon's session, not for a command started on this computer. Such a refusal reads "The way in could not be opened: there is no <path> on this machine."
- **Red first:** a test that a local terminal whose program is missing shows no container sentence; a test of the hand-over script that `SHA256SUMS` lists `porelo-host` and the start script exports `PORELO_HOST_STANDIN`.

## Test

Only the change: the two tests above and the scripts' own checks, with a dry hand-over into a scratch folder. No VM run; the next walk's hand-over shows it on the VMs.
