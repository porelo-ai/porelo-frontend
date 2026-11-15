# F605 — Start Work Knows Which Agents Are Signed In There

```json
{
  "$schema": "issue-1.json",
  "id": "F605",
  "title": "Start Work Knows Which Agents Are Signed In There",
  "state": "Review",
  "size": "XS",
  "priority": "High",
  "rank": 125,
  "blockedBy": [],
  "covers": "The window tells porelo-planner's Start work, for each agent it lists, whether that agent is signed in on the machine the task goes to and, where not, why in the window's words, so the dialog can preselect an agent that is ready (PL155)."
}
```

**Why this size.** XS: the agent list the window gives the planning screen already reads each agent's sign-in state
from the machine; it fills PL155's new member of `PlanningAgent` from it, with the pin raised and tests of each
state.

**What must be true.** A person opening *Start work* finds an agent preselected that can start on that machine,
and an agent that is not signed in there named with why, before pressing *Start*.

## Found

ST369's live test of 15 November; Agent Planner's PL155 *Start Work Preselects An Agent Signed In There* (room,
15:43Z) has a window part: `PlanningAgent` gets whether the agent is ready (signed in) on the machine the task goes
to and the window's words why not; the window answers that member for each listed agent.

## Plan

- **Today**, read in the code: `MachinePlanningAgents.on` (`lib/src/ui/planning_embedding.dart`) lists the agents of
  the machine `planningMachineOf` names through `agentsOn()`, each as `PlanningAgent(agent.name, choice:
  StartAgentChoice(agent: agent))`. Each `Agent` carries `found` (`SIGNED_IN`, `NOT_SIGNED_IN`, `CANNOT_SAY`, or
  nothing from an older machine), and `StartAgentChoice` (`lib/src/ui/start_work_view.dart`) already words it
  (*signed in here*, *signed in through the Porelo-Vault*, *not signed in here*, *cannot say whether it is signed in
  here*).
- **Steps**, once PL155's screen is pinned:
  - Fill PL155's member for each agent: ready for `SIGNED_IN`; not ready with the window's words for
    `NOT_SIGNED_IN`, naming the machine and that the agent's row under *Agents* signs it in there; `CANNOT_SAY`
    and an older machine's empty answer read as not known, never as signed out, in the member's shape PL155 gives.
  - The words share `StartAgentChoice`'s, so the start form and *Start work* say the same.
  - Raise the pin of `porelo_planning` with its lock, the `xterm` override kept.
- **Red first:** a test of `MachinePlanningAgents.on` with one agent signed in and one not, red on the old pin where
  the member does not exist, and a scenario that *Start work* preselects the signed-in one.

## Acceptance

- *Start work* preselects an agent signed in on the task's machine. Seen to fail: the old pin.
- An agent not signed in there is named with the window's words why; one the machine cannot say of is not called
  signed out.

## Built

- **Window:** `MachinePlanningAgents.on` (`lib/src/ui/planning_embedding.dart`) fills each `PlanningAgent`'s
  `unready` from the machine's `found`. `SIGNED_IN` is ready. `NOT_SIGNED_IN` reads *<agent> is not signed in on
  <machine>; its row under Agents on that machine signs it in.* `CANNOT_SAY` and an older machine's empty answer
  stay ready (not known, never signed out), so the screen does not pass them over.
  The same call gives the agent's models (`Models`, through `PoreloClient.models` and `FleetBackend.modelsOn`, only
  where the agent names its provider; a refusal gives an empty list) and its efforts (`Agent.efforts`, null where
  the machine lists none) for [F606](README.md#f606).
- **Contract:** porelo-planner's PL155 member as built in PL157 (`unready`, a `String?`), handed over locally;
  the window builds against porelo-planner `6ac9894` (PL146 under it), see [F606](README.md#f606)'s *Built*.
- **Test:** `test/ui/planning_agents_test.dart`, *each agent says whether it is ready there, and the models and
  efforts the machine lists*: one agent signed in, one not, one that cannot say. Seen red before the member was
  filled (no words for the agent not signed in). Green: 4 passed.
- **After the reading** (Claude Sonnet): each agent's model list waits at most 10 s (`modelsWait`), so one slow
  machine or provider never holds the agents back; an older machine (`FeatureNotSupported`) lists none quietly, any
  other failure or the wait is written to the window's log with why. Test *a model list that fails or does not
  answer offers the agent with its model typed, and the log says why*, red first (the list held until the test's
  own 5 s timeout).
- **Not checked:** the preselection itself is the screen's (PL155, its own suite); the window adds no scenario of it.

## To be checked

- The words of an agent not signed in are close to the start form's (*not signed in here*) but name the machine;
  they are not shared code.

- PL155's pushed commit and the member's exact shape, cited here once pushed.
