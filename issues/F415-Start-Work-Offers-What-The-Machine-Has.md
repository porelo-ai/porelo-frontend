# F415 — Start Work Offers What The Machine Has

**Status:** Accepted (operator, 2026-11-06).
**Size:** S - *Start work* on an organization's machine offers only the repositories the machine has taken, with one
line saying why the others are not offered.

**What must be true.** Starting work on a machine that carries a project for the organization offers only the
repositories of it the machine has taken; under the choice one line says how many are not offered and why ("15
repositories name no central address, so this machine has not taken them"). On a machine that is no organization's
host, every work repository as today.

## Why

The operator's walk on the rehearsal VM (2026-11-06): on rehearsal *Start work* offered all 17 of porelo's
repositories, though only porelo-core and porelo-message-sluice were on it; the other 15 have no central address
there. A task started in one of them has nothing to work in.

## Plan

- The machine's Porelo lists the project's repositories from its file (`ProjectInfo.workRepositories`), not whether
  the host took them; porelo-host says that per repository in its progress (`repositories[].state`, `taken`,
  `waiting`, `no-central`), which [F410](README.md#f410) reads.
- `lib/src/ui/start_work_view.dart` (`_WhichRepository`) takes, for a machine with an organization's card, the set of
  taken repositories from that progress; it offers those, and says the rest by reason in one line. Where the progress
  is not read (not connected to the host), every repository as today, with a line saying the machine was not asked.
- **The test that goes red first:** a start on a host whose progress says two of seventeen are taken offers those two
  and says the fifteen. It guards a task started in a repository the machine does not have.

## Blocked by

- [F410](README.md#f410), which reads the host's per-repository answer.
