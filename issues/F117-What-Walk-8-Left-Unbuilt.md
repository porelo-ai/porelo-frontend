# F117 — What Walk 8 Left Unbuilt

**Status:** Accepted.

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

## The shape

- Each with its scenario first: in `work_tiles.feature` a tile whose heading names its repository;
  in `moderating_messages.feature` a refused release shown as an error with what to do; in
  `following.feature` a push the interface made followed at once by a check.
