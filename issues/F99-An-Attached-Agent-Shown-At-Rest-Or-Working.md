# F99 — An Attached Agent Shown At Rest Or Working

```json
{
  "$schema": "issue-1.json",
  "id": "F99",
  "title": "An Attached Agent Shown At Rest Or Working",
  "state": "Backlog",
  "size": "M",
  "priority": "Medium",
  "rank": 12,
  "blockedBy": [],
  "covers": "A work tile says whether an attached agent is at rest or working, from the AT_REST activity the machine serves for it."
}
```

**Why this size.** M: one new answer of the daemon read through the model, the attention order, two views, the
stand-in, two features and two doc pages; no contract of this repository changes.

**What must be true.** A person sees on a work tile whether the agent in an attached session is at
rest or working, as the machine reads it from the agent's screen, never as a guess from silence.

## Why

For an attached session the machine says neither today, so a quiet tile is shown as a guess. The machine is to
read the agent's declared rest from its screen, as it reads waiting.

## Plan

- **The daemon's contract.** Tasks1's `Activity` gains `AT_REST`, served in `Task.activity` by `List` and `Watch`
  alike: up and attached, and its agent's screen shows it at its prompt by the agent's own declaration of rest, on two
  looks at least 1.5 s apart. An attached agent that declares its rest and is not at rest answers `WORKING`; one that
  declares none, or whose screen shows a question to a person, answers `UNKNOWN`, as an older daemon does for every
  attached task. `Watch` takes its next read of the screen as the second look, so a tile may read *Working* before
  *At rest*. A recorded done declaration does not apply to `AT_REST`. The answer is an `Activity` value, not a field
  of `Task`, and `Task.screen` stays unread.
- **Red first:** a scenario in `test/features/work_tiles.feature` whose stand-in answers at rest for an attached
  task (`Mode.agent`) and expects the tile to say *At rest* and not be marked as a guess; one beside it that answers
  working and expects *Working*.
- **The value:** in `lib/src/client/models.dart`, `Activity` (a class, not an enum, so a new value breaks nothing)
  gains `AT_REST` in `known` and `label`. An older daemon never sends it, so its tasks read as today.
- **The demand:** `Attention.demandOf` in `lib/src/app/attention.dart` maps it to a new `Demand` value, never
  `Demand.quiet`, so `Tile.inferred` stays false. Waiting, ended, the gate, done and stopped keep their place before
  it; an attached task's working answer maps to `Demand.working`.
- **The words:** in `lib/src/ui/attention_view.dart`, `TileWords._headline`, `WorkRow.stateOf`, the tone of
  `WorkRow`'s `StateChip` and `_StateMark` say *At rest* for the new demand; `ActivityMark` in
  `lib/src/ui/panes.dart` gets a mark for the new value. Every switch over `Demand` is exhaustive, so the compiler
  names each place.
- **The stand-in:** `_aMachineWithWorkOnIt` and `_task` in `lib/src/mock/machine.dart` already hold an attached
  agent, `porelo-billing-audit` with `UNKNOWN`; one at rest and one working join it. Steps in `test/features/step/`
  set it, as `the_work_is_idle.dart` does.
- **Older machines:** a scenario in `test/features/task_state.feature`, beside *work nothing can see is not reported
  as idle*: an attached task that answers `UNKNOWN` with no at-rest answer is still shown as *Running*.
- **Docs:** in `doc/Contract-Gaps.md`, the sentence that a quiet task is shown as a guess no longer covers an
  attached agent that declares its rest; `doc/Backend-API.md` says how `AT_REST` is read.

## Acceptance

- A tile of attached work says *at rest* or *working* from the machine's answer, beside what it
  shows today. Seen to fail: a scenario whose stand-in machine answers at rest, and one that answers
  working, each finding the other word or neither.
- Waiting, ended and stopped still win over it, as on the machine. Seen to fail: a scenario with an
  agent waiting on a person whose tile says *at rest*.
- A machine without the at-rest answer, or an agent that declares no rest, is shown as today, never as at rest.
  Seen to fail: a scenario against such an answer that shows *at rest* or *working*.
- `doc/Contract-Gaps.md` no longer lists a quiet attached task as a guess. Seen to fail: the page
  still says it once this is built.
