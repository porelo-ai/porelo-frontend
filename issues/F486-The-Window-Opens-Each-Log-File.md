# F486 — The Window Opens Each Log File

```json
{
  "$schema": "issue-1.json",
  "id": "F486",
  "title": "The Window Opens Each Log File",
  "state": "Implementing",
  "size": "S",
  "priority": "High",
  "rank": 8,
  "blockedBy": ["F483"],
  "covers": "The window shows a link for its own log and one for the planner's, each opening that file on this computer with the program the desktop opens such a file with, and saying so where the file is not there yet."
}
```

**Why this size.** Two links beside the level setting, opened with the desktop's opener the window already uses
(`Desk.openCommand`, `xdg-open` on Linux and the shell's opener on Windows), the planner's path taken from the
planner; with widget tests.

**What must be true.** A person who wants to read what the window or the planner logged opens the file with one click,
on Linux and on Windows.

## Why

- Serves porelo-project's *Logging in the frontend and the planner* (story ST318, porelo-project b08c20d).
- The operator wants a link that opens each log file on the local computer.

## Plan

- Under the log level in the settings, and in the window's menu: *Open the window's log* and *Open the planner's log*,
  each naming the file's path.
- The window's path is its own ([F483](README.md#f483)); the planner's is the `log` field of `planner.json`, the
  address file the window already reads, so a planner that stopped serving, or one the window did not start, is
  found too. Both lie in the shared `logs` directory.
- A file not there yet is said so, with its path, instead of the opener failing silently.

## To be checked

- The planner's issue that writes `planner.log` there and names it in `planner.json`, which the planner's link waits
  for.
