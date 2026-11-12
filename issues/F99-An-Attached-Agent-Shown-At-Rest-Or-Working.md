# F99 — An Attached Agent Shown At Rest Or Working

```json
{
  "$schema": "issue-1.json",
  "id": "F99",
  "title": "An Attached Agent Shown At Rest Or Working",
  "state": "Estimated",
  "size": "M",
  "priority": "Medium",
  "rank": 4,
  "blockedBy": [],
  "covers": "A work tile says whether an attached agent is at rest or working; waits for a Tasks1 answer that says an attached agent is at rest."
}
```

**Why this size.** M: one new answer of the daemon read through the model, the attention order, two views, the
stand-in, two features and one doc page; no contract of this repository changes. It cannot start before the daemon
serves that answer.

**What must be true.** A person sees on a work tile whether the agent in an attached session is at
rest or working, as the machine reads it from the agent's screen, never as a guess from silence.

## Why

For an attached session the machine says neither today, so a quiet tile is shown as a guess. The machine is to
read the agent's declared rest from its screen, as it reads waiting.

## Plan

- **Blocked on the daemon's contract.** Tasks1's `Activity` has `DONE`, `DEAD`, `WAITING`, `WORKING`, `IDLE`, `ENDED`
  and `UNKNOWN`, and an attached task answers `UNKNOWN`. `Task.screen` (`WAITING`, `NOT_WAITING`, `UNDECLARED`,
  `UNSEEN`) reads the screen for waiting on a person, not for rest. Porelo reads an agent's declared screen at rest
  only inside the daemon, to wake it; Tasks1 serves no at-rest answer. `DONE` is no stand-in: it is the agent's
  declaration that its work is done, not a rest between turns. Nothing here is built until Tasks1 has that answer.
- **Red first:** a scenario in `test/features/work_tiles.feature` whose stand-in answers at rest for an attached
  task (`Mode.agent`) and expects the tile to say *At rest* and not be marked as a guess; one beside it that answers
  working and expects *Working*.
- **The value:** in `lib/src/client/models.dart`, `Activity` (a class, not an enum, so a new value breaks nothing)
  gains the daemon's value in `known` and `label`; if the answer is a field of `Task` instead, such as a value of
  `screen`, `Task.from` reads it. `Task.from` reads no `screen` today. Absent, a task reads as today.
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
  attached agent that declares its rest.

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

## To be checked

- Ask porelo's agent (Agent Core) for the Tasks1 answer that says an attached agent is at rest, and working, read
  from the screen its agent declares (`session.at_rest`): its name, whether it is an `Activity` value or a field of
  `Task`, what an agent that declares no rest answers, and what an older daemon answers.
