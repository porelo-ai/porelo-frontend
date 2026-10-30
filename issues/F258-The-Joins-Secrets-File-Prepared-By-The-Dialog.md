# F258 — The Join's Secrets File Prepared By The Dialog

**Status:** Accepted.
**Size:** M - the join makes or opens the developer's secrets file itself, with the master password typed once in a terminal, instead of commands the person runs.

**What must be true.** In the join, the step that needs the developer's secrets file makes it when it does not exist and adds the entries the join needs, asking the master password once, typed into a terminal on the developer's own machine (never into a form of the interface). An existing file is opened with the same one prompt and only the missing entries are added; an existing entry is never overwritten. No value is shown, logged or put on a command line.

## Why

Operator's walk 23, step 9-2 (2026-10-30): preparing the secrets file for the join took several hand-run commands and the password more than once.

## Plan

- One terminal run in `lib/src/ui/project_join_dialog.dart` that runs `keepassxc-cli` for create-or-open and the needed `add`s in one session, the password read once from the terminal and passed on standard input.
- Shared with the host admin's preparation where it fits (the morning's Idea *Follow-up 5*, a guided preparation for a project admin, can take this run later).
- **Red first:** a test that the run is one terminal with one password prompt and makes only missing entries; a test that an existing entry is kept.

## Test

Only the change: the tests above. On VM B: one join start with no secrets file, then one with the file.

## Estimate

`F258 size=M est=60 basis=median M 61 (24 records)`
