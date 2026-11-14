# F573 — A Carried Project Sets Up Its Room

```json
{
  "$schema": "issue-1.json",
  "id": "F573",
  "title": "A Carried Project Sets Up Its Room",
  "state": "Backlog",
  "size": "S",
  "priority": "High",
  "rank": 18,
  "blockedBy": [],
  "covers": "Story ST361: a carried project's row whose room is not set up offers Set up the room, which takes the project here and sets its conversation up, instead of a greyed room button."
}
```

**Why this size.** One button on a project's row and one call. porelo's half is Agent Core's B773.

**What must be true.** A person can open a carried project's room before its first task, knowing that doing so takes the project here.

## Plan

The window's half of Agent Core's B773 "A Carried Project Opens Its Room Before Its First Task".

- A project row whose `messages.ready` is false offers *Set up the room* instead of a greyed button, with
  `messages.detail` as its tooltip. The button's words say that it takes the project here.
- It calls `SetUpConversation {project}`. An answer with ready true opens the room as today; otherwise the answer's
  detail is shown. `ConversationRefused` shows its message.
- Built after B773 is on porelo's main.

## Acceptance

- Guards for set up and opened, and for refused, each red first. The project row tests green.
