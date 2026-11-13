# F537 — A Handed Discussion Goes Once Its Waiting Ideas Are Handed

```json
{
  "$schema": "issue-1.json",
  "id": "F537",
  "title": "A Handed Discussion Goes Once Its Waiting Ideas Are Handed",
  "state": "Backlog",
  "size": "S",
  "priority": "Medium",
  "rank": 106,
  "blockedBy": [],
  "covers": "An ended discussion whose idea was saved, kept only because ideas it proposed still waited, is removed from its machine once every one of them was handed in and none is held back."
}
```

**Why this size.** S: the window keeps, with a discussion's end, that its idea was saved; a sweep removes such a
discussion once nothing of it waits; and their tests.

Found in the code reading of [F535](README.md#f535) (2026-11-13).

**How it stands.**
- The window removes an ended discussion right after its idea was saved, unless ideas it proposed still wait to be
  handed in or are held back by the listing. Then it says that the discussion stays until they are handed in.
- It marks that end handled before it decides, and is not asked again for the same end. When the waiting ideas are
  handed in later, or the held-back count falls to 0, nothing removes the discussion. It stays on the machine until the
  person removes it.
- The window does not keep whether the end's idea was saved, or refused, or never written. Only a saved one may go.

**What must be true.**
- A discussion whose idea was saved and that stayed for its waiting ideas is removed on the first sweep after every
  idea it lists was handed in and none is held back, once, also after a restart of the window.
- A discussion whose idea was refused, or that wrote none, stays as today.
