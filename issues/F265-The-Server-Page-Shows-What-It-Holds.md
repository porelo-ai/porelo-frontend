# F265 — The Server Page Shows What It Holds

**Status:** Idea. Held: GUI changes wait until the whole flow has been gone through again.
**Size:** M - a design, then its screen: a server shows its own state, its projects and its persons with their state; actions on them are chosen from those lists.

**What must be true.** A server's page shows the server's own state as the host admin reaches it (ssh as root), never "not answering" because no Porelo daemon answers. It lists the projects on it and the persons on it, each person with their state (active, locked). A person's actions (lock out, admit again, delete the account) and a project's (take it off) are chosen from those rows, not typed into free-text dialogs. The design is filed and agreed before it is built.

## Why

`OrganizationHostPage` in `lib/src/ui/organization_host_pages.dart` shows connection state, projects and Machine
Admins. A connected Machine Admin reads host progress through `SshHostProgress` in `lib/src/app/host_progress.dart`,
using `/usr/local/sbin/porelo-host-person org status` over SSH as root. Project rows combine the organization's list
with that answer. Locked people appear only when connected, as text naming their account deletion day, with no
actions. The Machine Admin rows show card standing and offer removal of that role.

`lib/src/ui/organization_host_pages.dart` does not provide the promised list of all persons with active or locked
state and account actions. The project page in [F266](README.md#f266) covers the related project view.

- A machine should show what it holds and offer actions from those rows.
- The person list should show each person's state, so a locked person can be admitted again or deleted for good,
  making lock and delete visible.

The live state from the host comes as a Project screen design ([F266](README.md#f266)), this server page design, then a read-only query contract with Agent Machines. This is the second of the two designs.

## Plan

- A design page with the server's state, its projects and persons with states and row actions, written before code.
- The state read from `SshHostProgress` (`lib/src/app/host_progress.dart`, SSH as root); the lists from this
  computer's record ([F239](README.md#f239)) until the query contract gives them from the host.
- **Red first:** the built screen's widget test that a ready server reached by root ssh shows its state, not *not answering*.

## Test

Only the change: the screen's widget tests. On the Laptop: one look at a ready server's page.

## Estimate

`F265 size=M est=60 basis=median M 61 (24 records)`, the query contract not included.
