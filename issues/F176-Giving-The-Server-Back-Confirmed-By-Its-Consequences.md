# F176 — Giving The Server Back Confirmed By Its Consequences

**Status:** Backlog.
**Size:** S - one confirmation's words and red button, and every way to take a server down routed through it.

**What must be true.** Taking a server down asks first, in a dialog that names what happens: the
server is given back to Scaleway and deleted, nothing is billed afterwards, the vault on the server
and the room's history are lost, the files in the tresor are kept; its button says *Give the server
back* and is red; nothing is typed.

## Plan

- **Today**, read in the code: the menu's *Take this server down* opens `_takeDownDialog`
  (`host_dialog.dart`) whose button repeats the menu's words without a destructive look; the
  wizard's own *Take this server down* calls `_down` with no confirmation at all.
- **The dialog:** the consequences as above, *Cancel* and *Give the server back* in the theme's
  `error` colours (`tokens.dart` primitives through `theme.dart`).
- **Routing:** the wizard's button opens the same confirmation before `_down`.
- **Tests, their harm, red first:** the wizard's button does not run `down` before the
  confirmation, and *Cancel* starts nothing (a server given back by one click). Words and colour
  get no test.

## Acceptance

- In the guided walk, every way to take a server down shows the confirmation first, and *Cancel*
  leaves the server.
