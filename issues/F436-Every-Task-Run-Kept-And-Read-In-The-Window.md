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
- **One log, read as views of one stream (the operator's word, 2026-11-08):** the backend makes every process it starts
  write records with the same fields (time, level, component, project, task, run, event, message, data) into one
  stream; the window reads that stream, never file names. A task's log is the stream filtered to its run, with filters
  by component (gate, vault proxy, resolver, clearance, hooks, reader, the agent's output, porelod) and by level; live
  while the task runs, from the run's archive afterwards, a removed task's the same way. A machine's own page offers the
  same view without a task, for porelod and porelo-mcp.
- **Over the machine's connection:** a host's stream is read through the tunnel the window already holds, like the
  rest of that machine; the window needs no collector of its own.
- **A mark for the chain:** the record's hash-chain check is shown, and a gap (a file deleted by hand) is named.

## Size

L, in parts: the history view and the timeline (M), the stream's view with its filters, live and archived (M). Built
only on the backend's reading; the size holds if that reading gives:
- the lifecycle entries and the stream's records by filter (project, task, run, component, level, since), in pages,
  with a cursor, so a long run is read in parts and a reconnect resumes without gaps or doubles;
- a follow that sends new records as they come, ended when the run ends;
- records already free of secrets at their source: the window shows `data` as it comes and cannot redact.

## Open

- Whether the choice to export to an organization's collector (off by default, what is sent being the person's) is set
  in the window, on the machine's page, or only by the CLI; if in the window, a part of its own.

- Where the view sits in the side bar's tree ([F429](README.md#f429)): under Work, or beside it.
- How the window says a removed task's archive was itself removed, which is its own lifecycle entry.
