# F491 — A Work Row Names Its Repository

```json
{
  "$schema": "issue-1.json",
  "id": "F491",
  "title": "A Work Row Names Its Repository",
  "state": "Idea",
  "size": "S",
  "priority": "Medium",
  "rank": 6,
  "blockedBy": [],
  "covers": "A row under Work names the repository its work is in, also in a project of one repository; where it says so is the person's to decide."
}
```

**Why this size.** one line of a row and the row in *Needs you*, and a scenario each; S once the place is decided.

**What must be true.** A person sees in which repository a piece of work runs from its row, without opening it, also
in a project of one repository.

## Why

The first half of [F117](README.md#f117), split off when its other half was built. Walk 8 found
that a tile named its repository only in `tile-where`, and only in a project of several.

## What changed since its plan

[F117](README.md#f117)'s plan put the repository into the heading, `tile-what` reading "<work> · <repository>". The row
under *Work* has been rebuilt since (`WorkRow` in `lib/src/ui/attention_view.dart`): `tile-what` is now the task's name
as a `SelectableText`, kept so because it is what a person types into `porelo` on the machine, and the line under it,
`tile-sub`, says "<project> · <agent> · on <machine>". Putting the repository into the selectable name would break
copying it. The row in *Needs you* (`TileWords._where`) still names the repository only for projects of several.

## To decide

Where the row names the repository:
- (a) in `tile-sub`, after the project: "<project> · <repository> · <agent> · on <machine>";
- (b) beside the name in the heading but outside the selectable text, so the name copies alone.

Either way the row in *Needs you* names it in a project of one repository too, and the comment that one repository
"says nothing new" goes.

## Acceptance

- A row under *Work* in a project of one repository names that repository. Seen to fail: a scenario in
  `work_tiles.feature`.
- Copying the row's name still copies the task's name alone.
