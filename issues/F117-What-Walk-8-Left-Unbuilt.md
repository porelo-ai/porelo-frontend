# F117 — What Walk 8 Left Unbuilt

**Status:** Analyzed.
**Size:** M - three small changes in three modules (the tile, the held message's outcome, the
project check after a push), each with its scenario.

**What must be true.** Three points walk 8 found, which the interface does not do yet: a tile names
its repository in its heading, a release Sokar refuses says what to do about it, and a project file
the machine follows is taken at once after the person's own push.

## Why

Split off when the rest of walk 8's findings went to be walked: these three were found unbuilt when
the walk was written.

- **The tile's repository:** a tile is headed by its work and the machine (`tile-what`,
  `tile-machine` in `lib/src/ui/attention_view.dart`); the repository is named only in `tile-where`,
  and only when the project has more than one.
- **A release Sokar refuses:** after *Release it*, a `NOT_DELIVERABLE` answer is a plain notice,
  "It cannot be sent: <Sokar's words>." (`lib/src/ui/held_message_view.dart`), not in the error's
  color and with nothing of what to do, such as joining the conversation first.
- **The project file after one's own push:** a followed project is read again only on the poll or
  on *Check it now* (`lib/src/app/project_check.dart`); nothing asks after a push the interface made
  itself, such as writing `project.yml` when a machine is bound.

## Plan

- **The tile's heading** (`TaskTile` in `lib/src/ui/attention_view.dart`): `tile-what` reads
  "<work> · <repository>", the repository's short name from `project.repositoryOf(task)`, or for
  work in `default` from its address; `_where` then drops the repository it named only for projects
  of several. The comment that a project of one repository "says nothing new" goes with it.
- **A refused release** (`HeldMessageDialog` in `lib/src/ui/held_message_view.dart`): a
  `NOT_DELIVERABLE` outcome stays in the dialog as an error, in the error's color, with Sokar's words
  and what to do where the words tell it: no account in the conversation → join it first, from the
  project's *Messages*; anything else → Sokar's words, and that nothing was sent.
- **The project file after one's own push:** after the interface pushes to a followed project's
  repository (binding a machine writes `project.yml` and the machine signers,
  `lib/src/app/machine_binding.dart`; a push forwarded at the gate to a project's repository,
  `lib/src/ui/shell.dart`), `ProjectCheck.checkNow` runs for that project, as *Check it now* does.
- **Red first, each:** in `work_tiles.feature` a tile in a project of one repository whose heading
  names it; in `moderating_messages.feature` a release answered `NOT_DELIVERABLE` shown as an error
  with what to do; in `following.feature` a binding's push followed at once by a check.

## Acceptance

- **A tile's heading names its work and repository,** the machine under it. Seen to fail: the
  `work_tiles.feature` scenario with one repository.
- **A release Sokar refuses is an error with what to do,** and the dialog stays open on it. Seen to
  fail: the `moderating_messages.feature` scenario.
- **The interface's own push to a followed project is taken at once,** its *Following, at …* the new
  commit without *Refresh*. Seen to fail: the `following.feature` scenario.

## To be checked

- **Sokar's words for `NOT_DELIVERABLE`:** which details it gives (no account in the conversation,
  others), so what to do is matched on them and not guessed; asked of Agent Core. (Agent Frontend's)
