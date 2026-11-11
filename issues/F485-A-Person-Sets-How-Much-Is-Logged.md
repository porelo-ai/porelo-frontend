# F485 — A Person Sets How Much Is Logged

```json
{
  "$schema": "issue-1.json",
  "id": "F485",
  "title": "A Person Sets How Much Is Logged",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 7,
  "blockedBy": ["F483"],
  "covers": "Settings carries the log level, DEBUG, INFO, WARN or ERROR, INFO by default; a change takes effect at once in the window's log and reaches the planner's, by the way the planner takes it."
}
```

**Why this size.** One setting in the window's settings, its control on the settings page, and handing it to the
planner the way the planner names; with widget and model tests.

**How it stands.** Built, in Review.
- `Settings.logLevel` (`lib/src/app/settings.dart`) keeps the level, INFO where none was chosen, stored as `logLevel`;
  the window's log takes it as its level from the first entry after the settings are read, and each change from the
  next entry (`lib/main.dart`).
- *Options* → *Logs* (also in *Find a command*) offers *Log level: ERROR*, *WARN*, *INFO (the usual)* and *DEBUG*,
  the one in force checked.
- The planner is told with `PUT /log/level` (`lib/src/app/planner_log_level.dart`), at the address and with the
  token its `planner.json` names, loopback only and never through a proxy: when the window finds a planner, again
  after it restarts, and on each change. `LocalPlanner` keeps what the planner answered; where it is at another level,
  or did not take it (a planner without `/log/level` is said to need a newer planner; a refusal in its own words),
  *Logs* says so in a line of its own. `GET /log/level` is not needed: the PUT answers the level in force.
- With it, as promised to the planner for its log beside the window's: a `logs` folder the window makes itself takes
  no line before it is closed to others (`WindowLog`); the lines said meanwhile follow once it is, and a folder that
  could not be closed takes them all the same.
- Tests: test/app/planner_log_level_test.dart, test/app/log_level_commands_test.dart, test/app/window_log_test.dart,
  test/ui/log_links_test.dart.

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

- The planner serves `/log/level` since porelo-planner c021299; this window was tested against a stand-in of it, not
  against that planner.
