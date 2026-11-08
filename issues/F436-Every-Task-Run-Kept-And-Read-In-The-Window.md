# F436 — Every Task Run Kept And Read In The Window

**Status:** Idea.

**What must be true.** The window shows every task that runs or ran, a removed one too, with who started and stopped
it, and opens its timeline and its logs after it is gone. Nothing of a task's life vanishes from the window with the
task.

**Blocked by** the backend's lifecycle record and its reading (the backend's own issue, filed first): the window reads
what the backend keeps and keeps nothing of its own.

## Why

The operator's word (2026-11-08): each task's whole lifecycle is kept and easy to read, in the CLI and in the window,
and does not vanish with the task. That day a task stopped over MCP was removed four minutes later with no line in
Porelo saying by whom, and its logs went with it.

## What it would be

- **A history view:** every task that runs or ran, removed ones included: task, project, repository, agent, started by
  (you, an MCP client by its name, a parent task, or Porelo itself), start, end, duration, exit and state. Filters by
  project, state and who.
- **A row opens the task's timeline:** its lifecycle entries in order, each with when and who; the run's numbers
  readable (exit, duration, CPU, memory peak, network, provider requests and their cost, blocked connections,
  hand-ins).
- **Each log by a click:** a live tail while the task runs, the archive afterwards; a removed task's logs open the same
  way.
- **A mark for the chain:** the record's hash-chain check is shown, and a gap (a file deleted by hand) is named.

## Open

- Where the view sits in the side bar's tree ([F429](README.md#f429)): under Work, or beside it.
- How the window says a removed task's archive was itself removed, which is its own lifecycle entry.
