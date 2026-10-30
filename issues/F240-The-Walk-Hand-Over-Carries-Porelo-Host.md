# F240 — The Walk Hand-Over Carries Porelo-Host

**Status:** Idea. Held as an Idea (operator, 2026-10-30, after walk 23): wizard changes wait until he has gone through the whole flow again.
**Size:** S - the VMs' walk hand-over ships `porelo-host` and the start script points the interface at it; a local command that cannot start says only that.

**What must be true.** A walk's VMs get `porelo-host`, built from the same commit as their interface bundle, in the hand-over with its digest in `SHA256SUMS`. `laptop-b-start.sh` starts the interface with `PORELO_HOST_STANDIN` naming it, so *Connect a forge* and every other call of `porelo-host` work on the VMs as on the Laptop. When a command run in a terminal on this computer cannot start, the dialog names the missing program and nothing about a container.

## Why

Operator's walk 23, step 5-5 on VM A (2026-10-30): *Forges → Add a forge → Connect it* failed with "The way in could not be opened: there is no `/usr/lib/porelo-frontend/porelo-host` on this machine. A session lives in the container, so it is reachable only from the machine the daemon runs on." The VMs get only the porelo package and the debug bundle (`porelo-frontend-bundle.tar.gz`, `tool/walk23/hand-over.sh`), which holds no `porelo-host`. `laptop-b-start.sh` sets no `PORELO_HOST_STANDIN`, so `poreloHost()` (`lib/src/app/host_session.dart`) names the installed path, which only the frontend's own package provides. The second sentence comes from `lib/src/app/session.dart`, which adds it for every machine that needs no tunnel, including a command on this computer.

## Plan

- `tool/walk23/hand-over.sh` (and the walk hand-over after it) builds `porelo-host` from the same commit as the bundle, with `-march=x86-64`. It adds the binary as its own file with its line in `SHA256SUMS`.
- `laptop-b-start.sh` checks that file against `SHA256SUMS` with the rest, unpacks it next to the bundle, executable, and starts the interface with `PORELO_HOST_STANDIN` naming it.
- `session.dart` adds the container sentence only for a daemon's session, not for a command started on this computer. Such a refusal reads "The way in could not be opened: there is no <path> on this machine."
- **Red first:** a test that a local terminal whose program is missing shows no container sentence; a test of the hand-over script that `SHA256SUMS` lists `porelo-host` and the start script exports `PORELO_HOST_STANDIN`.

## Test

Only the change: the two tests above and the scripts' own checks, with a dry hand-over into a scratch folder. No VM run; the next walk's hand-over shows it on the VMs.
