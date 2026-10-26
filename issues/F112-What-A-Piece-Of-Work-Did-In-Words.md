# F112 — What A Piece Of Work Did, In Words

**Status:** Analyzed; blocked by `porelo`
[B174](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b174), `porelo`
[B166](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b166), `porelo`
[B291](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b291), and `porelo`
[B293](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b293).
**Size:** L - six kinds of facts at the top of `TaskTile` (`lib/src/ui/attention_view.dart`), needing `porelo`
[B174](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b174) and the SARIF review summary; crosses
repositories.

**What must be true.** At the top of every piece of work (`TaskTile` in `lib/src/ui/attention_view.dart`) a person
reads what it did, in words: the agent's last answer, its commits and their diff since it started with the highest risk
class (`C0`–`C3` from `porelo-project`
[PJ73](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj73)), what of it waits at the gate with
its SARIF check round, completeness, and open finding and thread counts (`porelo-project`
[PJ72](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj72), `porelo`
[B291](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b291)), its messages, and what the firewall
stopped, the last only where something was.

## Why

The third of three parts of what a piece of work did made one page. The raw agent log (`agent.log`) is one JSON object
per line, so the agent's own last answer — the most important thing after an unattended run — and the state of its
waiting push and review checks are easily left unread.

## Plan

- **The last answer:** `Task` in `lib/src/client/models.dart` today carries `lastWrote` and `agentEnded` while
  `TileConsole` (`lib/src/ui/tile_console.dart`) tails `agent.log` with `formatted: true`; `Task` in
  `lib/src/client/models.dart` gains `lastMessage` (from `Tasks1.List` / `Watch` or `tailLog`) and renders it as safe
  text.
- **The commits, their diff, and their risk class (`C0`–`C3`):** no method answers them for a running task today
  (`WorkHeld` in `lib/src/app/work_held.dart` via `FleetBackend.workHeld` answers counts, `Review` only a push at the
  gate); `porelo` [B174](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b174) and `porelo`
  [B293](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b293) answer them: `TaskCommits(task)` for the
  commits `WorkHeld` counts (commit, time, subject; for a stopped task from the note its stop wrote, with `asOf`), and
  `TaskDiff(task, commit?)` for the patch of one or of all, cut at a file boundary with `files` whole, alongside the
  highest risk class (`C0`–`C3` from `porelo-project`
  [PJ73](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj73)) among the task's changed files.
  `PoreloClient` (`lib/src/client/porelo_client.dart`), `FleetBackend` (`lib/src/app/fleet_backend.dart`), and
  `MockMachine` (`lib/src/mock/machine.dart`) take them; a running task's diff is asked only when the person opens it.
- **What waits at the gate and SARIF check summary:** `Gate.waiting` (`lib/src/app/gate.dart`) and the SARIF review
  runs (`porelo` [B166](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b166) and `porelo`
  [B291](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b291)) supply the current check round, the
  profile's completeness as `porelo` [B291](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b291) defines
  it (anything but complete is never shown as clean), and counts of open findings and open review threads.
- **Its messages and firewall events:** `Mailboxes` (`lib/src/app/mailboxes.dart`) for messages; the task's
  `events.jsonl` for what the firewall stopped, shown only where it holds a line.
- **Safe rendering:** the agent's last answer, commit subjects, and message subjects in `TaskTile`
  (`lib/src/ui/attention_view.dart`) are rendered as plain text or restricted safe Markdown with Unicode bidi overrides
  (`U+202A`–`U+202E`, `U+2066`–`U+2069`) and control characters (`< 0x20` except `\t` and `\n`, plus `0x7F`–`0x9F`)
  escaped or badged, within the profile's limits (`porelo`
  [B291](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b291)), never raw HTML or executable links.
- **Where and red first:** a section at the top of `TaskTile` in `lib/src/ui/attention_view.dart`. Red first: a
  scenario in `test/features/work_tiles.feature` with nothing stopped, which must show no firewall part; then scenarios
  for each kind of fact, including the `C0`–`C3` risk class, the check round, completeness, open finding and thread
  counts, and bidi escaping.

## Acceptance

- *What it did* at the top of every tile (`TaskTile` in `lib/src/ui/attention_view.dart`): the agent's last answer as
  safe text; its commits, their diff since it started, and the highest risk class (`C0`–`C3`); what of that waits at
  the gate with the check round, the profile's completeness as `porelo`
  [B291](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b291) defines it (anything but complete is never
  shown as clean), and open finding and thread counts; its messages; what the firewall stopped, only where something
  was. Seen to fail: scenarios in `test/features/work_tiles.feature` where any of these is missing, where a
  non-complete check is shown as clean, or where the firewall part shows when nothing was stopped.
- Agent answers, commit subjects, and message subjects strip or disable raw HTML and executable links and badge Unicode
  bidi overrides. Seen to fail: a widget test with HTML and `U+202E` in a commit subject or last answer.

## To be checked

- Whether `Tasks1.List` / `Watch` already serves `lastMessage` for `Task` (`lib/src/client/models.dart` today has
  `lastWrote` and `agentEnded`, and `TileConsole` tails `agent.log` with `formatted: true`), or whether `porelo`
  [B174](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b174) adds it.
