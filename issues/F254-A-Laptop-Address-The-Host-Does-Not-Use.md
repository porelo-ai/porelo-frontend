# F254 — A Laptop Address The Host Does Not Use

**Status:** Accepted.
**Size:** S - the proposed and the accepted laptop address skip every address the host's tunnel already uses, not only those in the access file.

**What must be true.** The *Laptop VPN address* the developer step proposes, and every address it accepts, is free on the host: not the host's own `.1`, not any of the host admin's laptop peers, not any project admin's peer, and not any developer laptop of this or another project on that host. An address the host uses is refused before publishing, naming who uses it in words ("the host admin's laptop").

## Why

Operator's walk 23 on VM A (2026-10-30): the dialog proposed `10.73.1.2`, which is the host admin's own laptop peer on the host (`wg-porelo` has `.2` for it, `.3` for walkadmin). The access file does not know the host admin's peers, so the proposal and the check accepted it, and the host then could not admit it.

## Plan

- The dialog reads the addresses the host's tunnel uses through the admin's existing ssh boundary, before proposing one, and adds them to the reserved set of `nextAddress` and `checkAddress`.
- Which read gives them (an existing `porelo-host-person` answer, or a read-only one Machines adds) is agreed with Agent Machines before building; if the host must add one, that part is Machines' issue and this one waits for it.
- **Red first:** a fake host using `.2` and `.3` makes the proposal `.4`; typing `.2` is refused with the words above.

## Test

Only the change: the tests above. On VM A: one look that the proposal skips `.2` and `.3`.

## Estimate

`F254 size=S est=15 basis=median S 15 (11 records)`, without a host-side read Machines may need.
