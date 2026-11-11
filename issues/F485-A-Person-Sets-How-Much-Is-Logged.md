# F485 — A Person Sets How Much Is Logged

```json
{
  "$schema": "issue-1.json",
  "id": "F485",
  "title": "A Person Sets How Much Is Logged",
  "state": "Backlog",
  "size": "S",
  "priority": "High",
  "rank": 7,
  "blockedBy": ["F483"],
  "covers": "Settings carries the log level, DEBUG, INFO, WARN or ERROR, INFO by default; a change takes effect at once in the window's log and reaches the planner's, by the way the planner takes it."
}
```

**Why this size.** One setting in the window's settings, its control on the settings page, and handing it to the
planner the way the planner names; with widget and model tests.

**What must be true.** A person who wants to see more, or less, raises or lowers the level in the window, and both the
window's and the planner's log write from then on at that level, without a restart of either.

## Why

- Serves porelo-project's *Logging in the frontend and the planner* (story ST318, porelo-project b08c20d).
- The operator wants the level set in the window, INFO by default, and the one setting to reach both logs.

## Plan

- `lib/src/app/settings.dart` keeps `logLevel`, INFO where unset; the settings page shows it as a choice of four.
- The window's log ([F483](README.md#f483)) follows a change at once.
- The planner is told the level with `PUT /log/level` (`{"level": ...}`, one of the four), which answers the level in
  force; the planner keeps it across its starts. The window sends it on a change and again when it reaches or starts
  a planner, and reads `GET /log/level` to show where the planner's level differs from its own.

## To be checked

- The planner's issue that serves `/log/level`, which this waits for.
