# F497 — The Gherkin Suites' Rules As Unit Tests

```json
{
  "$schema": "issue-1.json",
  "id": "F497",
  "title": "The Gherkin Suites' Rules As Unit Tests",
  "state": "Estimated",
  "size": "L",
  "priority": "Medium",
  "rank": 19,
  "blockedBy": ["F495"],
  "covers": "The slow Gherkin suites' rules moved into unit tests on StartWork, ShellModel, commands.dart, a wizard model, AgentSignIn, Logs and the organization projections; each feature keeps what the window adds."
}
```

**Why this size.** L: seven slow suites, each an S or M of its own, with a wizard model and the organization
projections to draw out of the views first; `World.settle` changes for every feature. Built suite by suite.

**What must be true.** A suite's rules are proven by unit tests in milliseconds; its feature keeps only the scenarios
that show what the window adds, and a scenario pumps only the frames it needs.

## Why

The window's tests follow the test pyramid, as the shared rule *Testing and machines* asks. Most of the suites' time
goes to `World.startApp`, which boots the whole window per scenario, and `World.settle`, which pumps three full-tree
frames (0 + 350 + 350 ms) per action. The measured basis stands in [F499](README.md#f499).

## Decided by the operator (2026-11-12)

- The window's move to the test pyramid is five issues of their own; this one is built after
  [F495](README.md#f495), whose clock and fakes it uses.
- A feature may hand its rule scenarios to unit tests and keep the scenarios that show what the window adds. Its rules
  are then specified by the unit tests' names.

## Measured: slow suites whose logic belongs in unit tests

- `task_creation` (142 s, 78 scenarios): name rules, defaults and retries on `StartWork` in `test/app`, about eight
  dialog tests left. **M**
- `machine_sections` (124 s, 52): which machine a leaf's command acts on, resolved in `ShellModel` and
  `commands.dart`. **M**
- `adding_a_machine` (103 s, 45) and `managed_tunnels` (54 s, 21): a plain wizard model with its transitions. **M**
- `agent_sign_in` (93 s, 32): the state matrix on `AgentSignIn` and `StartWork`, three widget tests left. **S**
- `live_logs` (93 s, 12; one scenario pumps 400 frames): coalescing, caps and truncation in `test/app/logs_test.dart`
  under `fakeAsync`. **S**
- `organization_page` (89 s, 98) and `organization_host_pages` (55 s, 86): role and standing rules, write payloads and
  central state as plain projections. **M**
- `work_handover`, `network_exposure`, `work_tiles`, `task_control`, `work_page_faults`: their orchestration on `Gate`,
  `Widening`, `Attention` and `Commands`; views mounted alone. **M**

## Plan

- Suite by suite, in the order above. Each slice writes its unit tests first, red against the rule as the feature
  states it, then removes the feature's scenarios the unit tests now prove, in the same commit.
- **Red first:** `task_creation`'s name rules as unit tests on `StartWork` in `test/app`.
- The rules go to `StartWork`, `ShellModel` and `commands.dart`, a plain wizard model for adding a machine and its
  tunnels, `AgentSignIn`, `Logs` and the organization's projections (role and standing, write payloads, central state).
- `World.settle` (`test/features/support/world.dart`) pumps only the frames a scenario needs, not three full-tree frames
  per action.
- After each suite the shares are measured again as [F499](README.md#f499) says and written there.

## Acceptance

- Each suite above runs its rules as unit tests, each seen to fail with its rule broken; the feature keeps only the
  scenarios that show what the window adds.
- The suites' summed time falls, measured as [F499](README.md#f499) says.
