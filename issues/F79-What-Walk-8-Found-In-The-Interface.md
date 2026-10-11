# F79 — What Walk 8 Found In The Interface

**Status:** Review; to be walked. Split off as not built: a tile's repository in its heading, a
release Sokar refuses said as an error that stays, and the project file taken after one's own
push, [F117](README.md#f117).

**What must be true.** A person reads tiles, *Needs you*, *Join* and talking at a glance, and sees the
effect of their own action at once; each point below is fixed, or decided against in
`doc/decisions.md`.

## Why

Every point is built; what remains is to walk each one. Offering the project's other tasks as peers
needs Sokar's `Peers` to list them, which is built but not published yet.

## Acceptance

Each is judged in a walk on the VM against Sokar's handover.

- Tiles: a tile is headed by its work, with the machine under it. Seen to fail: a scenario in
  `work_tiles.feature` where the machine is the heading.
- Tiles: running, waiting, needing a person and stopped are told apart by a mark of color and shape
  before the name, and a stopped tile is greyed. Seen to fail: a `work_tiles.feature` scenario where
  two states share a mark.
- Tiles: each tile's menu has a key of its own (`tile-menu <name>`). Seen to fail: a walk step
  pointing at one tile's menu finds none or two.
- *Needs you*: a held message shows the start of its text, never one the filter refused or would
  have refused. Seen to fail: a scenario in `moderating_messages.feature` where only "Held until…"
  shows, or a refused text does.
- *Needs you*: its heading says who wrote it and to whom, and one the person wrote is said as theirs.
  Seen to fail: a `moderating_messages.feature` scenario where the writer is missing.
- *Needs you*: the dialog closes after a decision and says what came of it. Seen to fail: a scenario
  where it stays open.
- Talking: *Whom this work may talk to* offers the project's other tasks once Sokar's `Peers` lists
  them. Seen to fail: a scenario in `project_messages.feature` with two tasks where the other is not
  offered.
- Talking: it says who a peer is: a person or machine reading the room in a Matrix client, or another
  piece of work in the project. Seen to fail: a scenario where a peer is shown by name only.
- Talking: a message the person wrote is not held for the same person's release, or it is said why.
  Seen to fail: a scenario where it is held without a reason.
- Talking: a message that could not be sent yet is said so, in the error's color, among what happened
  to its messages. Seen to fail: a scenario where it shows as sent.
- *Join*: the login's fields carry the names clients use (*Matrix ID*, *Homeserver URL*), each with a
  copy button, and one for all. Seen to fail: a scenario in `access_from_elsewhere.feature` where a
  name or a button is missing.
- Fresh state after one's own action: after forwarding or dropping a push, the project's badge of
  waiting pushes, and after a follow, its *Following, at …*, are read again at once, not at
  *Refresh*. Seen to fail: a scenario where the old count or time stays until *Refresh*.
- The start form asks again where the machine refused an agent it lists, and names the agent. Seen to
  fail: a scenario in `task_creation.feature` where the refusal is not named.
- A project's work repository that is itself a project (a `project.yml` of its own, which is not
  read) is said when binding a machine. Seen to fail: a scenario in `project_configuration.feature`
  where it is not said.
- Forwarding offers the repository's branches to choose from. Seen to fail: a scenario in
  `work_handover.feature` where the branch must be typed.
- The guided walk gives a list a moment to load before it says it lost its way
  (`flutter-guided-walk`). Seen to fail: a walk step on a list that loads late reports it lost its
  way.
