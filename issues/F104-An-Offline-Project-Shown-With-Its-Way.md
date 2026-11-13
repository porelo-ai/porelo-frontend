# F104 — An Offline Project Shown With Its Way

```json
{
  "$schema": "issue-1.json",
  "id": "F104",
  "title": "An Offline Project Shown With Its Way",
  "state": "Estimated",
  "size": "M",
  "priority": "Low",
  "rank": 12,
  "blockedBy": [],
  "covers": "An offline project shown, with the way to make one by hand named."
}
```

**Why this size.** the frontend's part: an offline project's mark and the way named beside it.

**What must be true.** An offline project is made by hand only, on the machine. The window shows such a project and
names the way: `porelo project follow NAME FILE`, with a bundle or a directory there.

## Why

An offline project never connects. `upstream:` and `--upstream` are refused for it, and its repository comes in only
as a bundle (`gate restore`) or from a checkout on the machine. The window follows nothing, so it does not make one.

## How it stands

Read from the code, not run. Showing works in part: such a project comes from the machine's daemon and stands as a row
in `lib/src/ui/projects_page.dart`, and `lib/src/ui/machine_tree.dart` adds its class to the line on its page, as
`offline`. Its row says nothing of the class, and nothing in `lib` names the way.

## Plan

- The project's row and its page say that it is offline, and name `porelo project follow NAME FILE`.
- **Red first:** a widget test of an offline project's row finding the mark and the way.

## Acceptance

- An offline project from a machine shows that it is offline and names the way. Seen to fail: the widget test.
- The window offers no way to make one.
