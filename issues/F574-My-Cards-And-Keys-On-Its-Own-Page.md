# F574 — My Cards And Keys On Its Own Page

```json
{
  "$schema": "issue-1.json",
  "id": "F574",
  "title": "My Cards And Keys On Its Own Page",
  "state": "Backlog",
  "size": "S",
  "priority": "Highest",
  "rank": 19,
  "blockedBy": [],
  "covers": "Story ST361: My cards & keys shows the person's key, its validity, agent, organization card and central forge keys in the page's own body, as every rail page does; a dialog stays only for changing the key."
}
```

**Why this size.** One page: the dialog's body moves into the page, and its three callers open the page instead.

**What must be true.** A rail page shows what it is about; nothing is read in a dialog over an empty page.

## Plan

Found live: *My cards & keys* in the rail opens an empty page with only its head, and shows everything in the
modal dialog *My key and card* over it (`identity_view.dart` builds an AlertDialog; `shell.dart` ~963, ~4579 and
~4609 call `showIdentity`).

- The page shows the key, its validity, the agent, the organization card, the central forge keys and *Change my
  key…* in its own body.
- The finder's *My key* command and the other callers open the page.
- A dialog stays only for the change itself.

## Acceptance

- A guard that the page's body shows the key and card and that no dialog opens for reading, red first. The identity tests green.
