# F99 — An Attached Agent Shown At Rest Or Working

**Status:** Backlog; blocked by `porelo` [B118](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b118).
**Size:** S - one derivation, its tile words, the stand-in and two feature files; waits for
`porelo` [B118](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b118)'s answer on the wire.

**What must be true.** A person sees on a work tile whether the agent in an attached session is at
rest or working, as the machine reads it from the agent's screen, never as a guess from silence.

## Why

For an attached session the machine says neither today, so a quiet tile is shown as a guess; `porelo`
[B118](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b118) has the machine read the agent's declared rest from its screen, as it reads waiting.

## Plan

- **Red first:** a scenario in `test/features/work_tiles.feature` whose stand-in answers at rest for
  an attached task (`Mode.agent`) and expects the tile to say *at rest* and not be marked as a
  guess; one beside it that answers working.
- **The value:** in `lib/src/client/models.dart`, `Activity` gains the value [B118](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b118) settles on, if it
  is one of its own, with its `label`; if it is `IDLE` read from the screen, the field [B118](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b118) adds to
  `Task` that says so is read in `Task.from`. Absent, it reads as today.
- **The demand:** `Attention.demandOf` in `lib/src/app/attention.dart` maps the machine's at rest to
  a demand that is not `Demand.quiet`, so `Tile.inferred` stays false; waiting, ended, the gate and
  stopped keep their place before it, as they do now.
- **The words:** `TaskTile._headline` and `_StateMark` in `lib/src/ui/attention_view.dart` say *At rest* and
  *Working* from that demand; `ActivityMark` in `lib/src/ui/panes.dart` gets a mark for it.
- **The stand-in:** `_aMachineWithWorkOnIt` and `_task` in `lib/src/mock/machine.dart` give an
  attached task at rest and one working; steps in `test/features/step/` set it, as
  `the_work_is_idle.dart` does.
- **Older machines:** a scenario in `test/features/task_state.feature` where an attached task answers
  `UNKNOWN` with no rest field, still shown as *Running*.
- **Docs:** the quiet-task line in `doc/Contract-Gaps.md` goes.

## Acceptance

- A tile of attached work says *at rest* or *working* from the machine's answer, beside what it
  shows today. Seen to fail: a scenario whose stand-in machine answers at rest, and one that answers
  working, each finding the other word or neither.
- Waiting, ended and stopped still win over it, as on the machine. Seen to fail: a scenario with an
  agent waiting on a person whose tile says *at rest*.
- A machine older than [B118](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b118), or an agent that declares no rest, is shown as today, never as at rest.
  Seen to fail: a scenario against such an answer that shows *at rest* or *working*.
- `doc/Contract-Gaps.md` no longer lists a quiet attached task as a guess. Seen to fail: the page
  still says it once this is built.

## To be checked

- Whether *at rest* arrives as an `activity` value of its own or as `idle` read from the screen
  (`porelo` [B118](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b118)'s own question); the tile follows the machine's answer either way (Agent Core's).
