# F112 — What A Piece Of Work Did, In Words

**Status:** Analyzed.
**Size:** M - a *What it did* section at the top of a piece of work, with two new daemon answers (`lastMessage` and
`TaskCommits`) in the client and its stand-ins; no diff on the wire.

**What must be true.** At the top of every piece of work a person reads what it did, in words: the agent's last
answer, its commits since it started as a list with their highest risk class (`C0`–`C3`), what of it waits at the
gate with the check round, completeness and open finding and thread counts, its messages, and what the firewall
stopped, the last only where something was. No diff is shown.

## Why

The raw agent log (`agent.log`) is one JSON object per line, so the agent's own last answer — the most important thing
after an unattended run — and the state of its waiting push and checks are easily left unread. The code is read in
IntelliJ; here a list of commits says enough.

## Plan

- **Waits for the contract:** `Task` from `Tasks1.List` / `Watch` gains `lastMessage`; the daemon answers
  `TaskCommits(task)` with each commit (commit, time, subject), `asOf` for a stopped task read from the note its stop
  wrote, and the highest risk class among the task's changed files by the gate's rules, without sending a diff. The
  check summary is the one [F107](README.md#f107) reads. `doc/Backend-API.md` and `doc/Contract-Gaps.md` take them
  first.
- **The client:** `Task` in `lib/src/client/models.dart` gains `lastMessage`; `PoreloClient`
  (`lib/src/client/porelo_client.dart`), `FleetBackend` (`lib/src/app/fleet_backend.dart`), `MockMachine`
  (`lib/src/mock/machine.dart`) and `FakeBackend` (`test/fakes/fake_backend.dart`) take `TaskCommits`.
- **Where:** a section at the top of a piece of work, today `TaskTile` in `lib/src/ui/attention_view.dart` (its own page
  under *Work* once tiles become rows). Messages from `Mailboxes` (`lib/src/app/mailboxes.dart`), what waits from
  `Gate.waiting` (`lib/src/app/gate.dart`) with a *Review* button to the push's page, and the firewall's stops from the
  task's `events.jsonl`.
- **States:** a running task without an answer reads "Still working; nothing answered yet". A stopped task's commits
  carry "as of" their time. No commits reads "No commits yet" and leaves the class out, never `C0`. Nothing waiting
  reads "Nothing waits at the gate." A check not complete is never shown as clean. The firewall part is absent where
  nothing was stopped. A part the daemon does not answer reads "not reported" on its own while the others show; a lost
  connection keeps the last answer with the time it was read.
- **Safe rendering:** the last answer, commit subjects and message subjects are plain text or restricted safe
  Markdown, with Unicode bidi overrides (`U+202A`–`U+202E`, `U+2066`–`U+2069`) and control characters (`< 0x20` except
  `\t` and `\n`, plus `0x7F`–`0x9F`) badged, never raw HTML or executable links.
- **Red first:** a scenario in `test/features/work_tiles.feature` with nothing stopped, which must show no firewall
  part; then one per kind of fact, the class, a check not complete, and bidi escaping.

## What it drops

- The diff of the task's commits, `TaskDiff(task, commit?)` and opening a running task's diff on demand: nowhere in
  the interface; the code is read in IntelliJ from the task's branch.

## Acceptance

- *What it did* at the top of every piece of work shows the last answer, the commits with their highest class, what
  waits at the gate with its round, completeness and counts, the messages, and what the firewall stopped only where
  something was. Seen to fail: scenarios in `test/features/work_tiles.feature` where any of these is missing, where a
  check not complete reads as clean, or where the firewall part shows when nothing was stopped.
- No commits, and a class not reported, never read as `C0`. Seen to fail: a scenario with an empty commit list that
  shows a class.
- Agent answers, commit subjects and message subjects strip or disable raw HTML and executable links and badge Unicode
  bidi overrides. Seen to fail: a widget test with HTML and `U+202E` in a commit subject or last answer.

## To be checked

- Whether `Tasks1.List` / `Watch` already serves `lastMessage` (`Task` has `lastWrote` and `agentEnded`, and
  `TileConsole` tails `agent.log` with `formatted: true`), or whether the daemon has to add it.
