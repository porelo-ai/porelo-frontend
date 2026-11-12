# F117 — What Walk 8 Left Unbuilt

```json
{
  "$schema": "issue-1.json",
  "id": "F117",
  "title": "What Walk 8 Left Unbuilt",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 6,
  "blockedBy": [],
  "covers": "A release Porelo refuses said as an error that stays, with its words whole; the repository on a row is left to its own issue."
}
```

**Why this size.** two small changes in two modules (the tile and the held message's outcome), each with its
scenario.

**How it stands.** Built for the refused release, in Review; the tile's repository is split off as
[F491](README.md#f491), as the row under *Work* has been rebuilt since this plan and where it
names the repository is a choice to make there.
- `HeldMessageDialog` (`lib/src/ui/held_message_view.dart`): a release answered `NOT_DELIVERABLE` keeps the dialog
  open, its outcome in the error's colour: "Nothing was sent. Porelo says: <detail>", Porelo's words whole and
  unmatched. Every other outcome closes the dialog as before, said behind it.
- Test: `moderating_messages.feature`, "a release Porelo refuses is said as an error that stays, with its words
  whole".

**What must be true.** Two points walk 8 found, which the interface does not do yet: a tile names
its repository in its heading, and a release Porelo refuses is said as an error that stays.

## Why

- **The tile's repository:** a tile is headed by its work and the machine (`tile-what`,
  `tile-machine` in `lib/src/ui/attention_view.dart`); the repository is named only in `tile-where`,
  and only when the project has more than one.
- **A release Porelo refuses:** after *Release it*, a `NOT_DELIVERABLE` answer is a plain notice,
  "It cannot be sent: <Porelo's words>." (`lib/src/ui/held_message_view.dart`), not in the error's
  color, and gone with the dialog before it is read.

## Plan

- **The tile's heading** (`TaskTile` in `lib/src/ui/attention_view.dart`): `tile-what` reads
  "<work> · <repository>", the repository's short name from `project.repositoryOf(task)`, or for
  work in `default` from its address; `_where` then drops the repository it named only for projects
  of several. The comment that a project of one repository "says nothing new" goes with it.
- **A refused release** (`HeldMessageDialog` in `lib/src/ui/held_message_view.dart`): a
  `NOT_DELIVERABLE` outcome stays in the dialog as an error, in the error's color, saying that
  nothing was sent, with Porelo's `detail` whole. The interface does not match on its words, which
  are no contract: what to do is in them where Porelo names it (a task not in the project's
  conversation is started again, then released). A code beside `detail`, which would let it match the
  other five cases, is the daemon's to add; a remedy per code follows it, as an issue of
  its own.
- **Red first, each:** in `work_tiles.feature` a tile in a project of one repository whose heading
  names it; in `moderating_messages.feature` a release answered `NOT_DELIVERABLE` shown as an error
  with Porelo's words whole.

## Acceptance

- **A tile's heading names its work and repository,** the machine under it. Seen to fail: the
  `work_tiles.feature` scenario with one repository.
- **A release Porelo refuses is an error, with Porelo's words whole,** and the dialog stays open on it. Seen to
  fail: the `moderating_messages.feature` scenario.
