# F265 — The Server Page Shows What It Holds

**Status:** Accepted.
**Size:** M - a design, then its screen: a server shows its own state, its projects and its persons with their state; actions on them are chosen from those lists.

**What must be true.** A server's page shows the server's own state as the host admin reaches it (ssh as root), never "not answering" because no Porelo daemon answers. It lists the projects on it and the persons on it, each person with their state (active, locked). A person's actions (lock out, admit again, delete the account) and a project's (take it off) are chosen from those rows, not typed into free-text dialogs. The design is filed and agreed before it is built.

## Why

Operator's walk 23 (2026-10-30):
- 12-3: walk9server showed *not answering* on *Machines* although it was up; the label means no daemon connection, which the host admin never has to a host.
- 12-4: a machine should show what it holds and actions be chosen from there.
- 12-12: the person list should show each person's state, so a locked person can be admitted again or deleted for good, which makes lock and delete visible.

Decided in the morning (2026-10-30): the live state from the host comes as a Project screen design ([F266](README.md#f266)), this server page design, then a read-only query contract with Agent Machines. This is the second of the two designs.

## Plan

- A design page with the server's state, its projects and persons with states and row actions, written before code.
- The state read from what the host admin has today (`porelo-host find` and `state`, ssh as root); the lists from this computer's record ([F239](README.md#f239)) until the query contract gives them from the host.
- **Red first:** the built screen's widget test that a ready server reached by root ssh shows its state, not *not answering*.

## Test

Only the change: the screen's widget tests. On the Laptop: one look at a ready server's page.

## Estimate

`F265 size=M est=60 basis=median M 61 (24 records)`, the query contract not included.
