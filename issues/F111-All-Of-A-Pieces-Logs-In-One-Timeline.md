# F111 — All Of A Piece's Logs In One Timeline

```json
{
  "$schema": "issue-1.json",
  "id": "F111",
  "title": "All Of A Piece's Logs In One Timeline",
  "state": "Backlog",
  "size": "M",
  "priority": "Low",
  "rank": 7,
  "blockedBy": [],
  "covers": "All of a piece's logs in one timeline, by time, filterable by source."
}
```

**Why this size.** a merged view over every log of a piece of work, its filter and the fold for the logs
by source; several modules, no contract change if each source's lines carry their time.

**What must be true.** A person sees everything a piece of work did in one timeline, by time,
filterable by source; the logs by source stay, folded away, for troubleshooting.

## Why

The second of three parts of what a piece of work did made one page. A piece of work's logs are
split by where they come from (firewall, DNS, vault, gate, agent), so what happened when is pieced
together by hand.

## Plan

- **A `Timeline`** in `lib/src/app/` beside `Logs` (`lib/src/app/logs.dart`): one `LogTail` per log
  `logsOf` names, their lines merged by a time read from each line, and a filter by source.
- **The time of a line:** `PoreloClient.tailLog` answers plain strings with no time of their own, so
  each source's own format is read here (`events.jsonl` and `task.log` are JSON with a time field,
  the others start with one); a line with none keeps its place after the line before it.
- **The view:** `LogView` (`lib/src/ui/log_view.dart`) shows the timeline first; the logs by source
  move under a fold, still opened as `LogOpened` in `lib/src/ui/shell.dart`.
- **Red first:** a scenario in `test/features/live_logs.feature` with two sources written out of
  order, and one where a filter leaves only one source.

## Acceptance

- All its logs in one timeline, by time, filterable by source. Seen to fail: a scenario in
  `live_logs.feature` where lines from two sources are out of time order or a filter leaves another
  source's line.
- The logs by source stay, folded away. Seen to fail: a scenario where one source's log cannot be
  opened.

## To be checked

- **Whether every source's line carries its time:** read on 2026-11-11 in Core's code (porelo main 79177cb40), not
  on a VM: no. `gate.log`, `vault.log`, `relay.log` and `clearance.log` are each a side process's standard output
  redirected into the file (`GateWiring`, `CredentialWiring`, `ClearanceWiring`), plain lines such as the gate's
  "task <name>" with no time of their own; `hooks.log` lines start with an ISO time, `events.jsonl` carries one per
  line. So a timeline merged by time cannot be read from these lines: it waits for Core's `Tail` to answer each line
  with the time it was written (a time field beside the line), to be asked of Agent Core. Until then the merge would
  have to guess the order, which this issue's acceptance refuses. (Agent Frontend's reading; the ask is Agent Core's)
