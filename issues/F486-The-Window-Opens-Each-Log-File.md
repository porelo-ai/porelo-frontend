# F486 — The Window Opens Each Log File

```json
{
  "$schema": "issue-1.json",
  "id": "F486",
  "title": "The Window Opens Each Log File",
  "state": "Review",
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

- In a *Logs* section of *Options* (the title bar's menu at full width, its dialog behind ⋮ on a narrow window), where
  the log level's control stands above them, and in *Find a command*: *Open the window's log* and *Open the planner's
  log*, each naming the file's path; the result is said in a message every page shows, since not every page has a
  status line.
- The window's path is its own ([F483](README.md#f483)); the planner's is the `log` field of `planner.json`, the
  address file the window already reads, kept once that planner has gone, so a planner that stopped serving, or one
  the window did not start, is found too. Both lie in the shared `logs` directory, and only a file of its own directly
  there is opened: a path elsewhere, with `..`, or a link is refused, since the opener runs or opens whatever lies at
  the path it is given.
- A file not there yet is said so, with its path, instead of the opener failing silently. An opener still running
  after ten seconds runs what it opened itself and counts as having opened it; what it said is read as UTF-8 where it
  is not the system's encoding.
- On Windows, `rundll32 url.dll,FileProtocolHandler` ends with exit code 0 whether or not a program took the file, so
  there a failure to open is not seen and the log reads as opened.

## To be checked

- The planner's issue that writes `planner.log` there and names it in `planner.json`, which the planner's link waits
  for.
