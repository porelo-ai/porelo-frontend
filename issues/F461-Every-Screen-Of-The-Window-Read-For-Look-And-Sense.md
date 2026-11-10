# F461 — Every Screen Of The Window Read For Look And Sense

```json
{
  "$schema": "issue-1.json",
  "id": "F461",
  "title": "Every Screen Of The Window Read For Look And Sense",
  "state": "Backlog",
  "size": "M",
  "priority": "Medium",
  "rank": 12,
  "blockedBy": [],
  "covers": "Every screen captured headless at three sizes, light and dark, full and empty, read by another model against a visual and a logical checklist; every finding listed with its screen and size, nothing fixed yet."
}
```

**Why this size.** every screen captured headless at three sizes, light and dark, with data and empty; one reading by
another model against the checklist below; every finding listed here. Nothing is fixed and no test is written.

**What must be true.** The operator can read, in this issue, every visual and logical finding on every screen of the
window, each with its screen and window size, gathered by one reading of captured screens against one checklist,
before anything is changed.

## Plan

- **Capture.** The window runs headless under `xvfb-run` inside `dbus-run-session` against the mock daemon
  (`tool/mock_daemon.dart`), its config and runtime folders its own. Every screen reachable from the side bar and the
  finder - every place, each machine's and organization's sections, every page with entries, every dialog and each
  wizard step - is captured at 390x844, 1024x768 and 1920x1080, in the light and the dark theme, once with the mock's
  full situation and once with an empty one, and once with a lost connection where the screen reads a machine.
- **Reading.** One reader sub-agent of another model (agy, by preference `claude-opus-5-5-high` for the logic) reads
  the images, with the screen's name and size beside each, against the checklist.
- **Visual checklist:** alignment; spacing; text cut or overflowing; contrast, and the dark theme; one type scale;
  empty and error states; labels and language; the primary action plain; small windows.
- **Logical checklist:** is the structure sensible (navigation, what lives where, what a person looks for first); do
  names and states agree across screens; does each screen say what the person must do next; are there dead ends or
  duplicate ways.
- **Findings.** Each finding is listed below under its screen, with the size and theme it was seen at, what was seen
  and why it matters; checked by the agent against the screen before it is listed. Nothing is fixed here: each fix
  becomes its own issue once the operator has read the list.

## Acceptance

- Every screen and dialog has its captures at the three sizes, both themes, full and empty; a screen missing from
  the captures is named as missing, never left out in silence.
- Every finding names its screen, its size and its theme, and the reading's report is kept beside the captures.

## Findings

- None yet.
