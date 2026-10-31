# F275 — The Sign-In Says Its Flow

**Status:** Implementing. Estimated and Backlog (operator, 2026-10-30, sprint 6m).
**Size:** S - flow metadata crosses the agent reply model and both sign-in entry points before the terminal can explain it.

**What must be true.** When an agent's sign-in runs in the person's host account, the terminal shows above it "Paste the code shown in your browser" for `paste-code`, or "Confirm on the device page" for `device-code`. A `loopback` flow refused by Core on a host account is shown in Core's words.

## Why

One-click joining from signed state (operator, 2026-10-30) and the operator's answer to Agent Smith (2026-10-30): `login.flow` per definition, so the interface can say what to do.

## Plan

- **Red first:** extend the fake-backed sign-in scenarios in `test/features/task_creation.feature` and `test/features/start_agents.feature`. When Core refuses loopback sign-in on a host account, its reason must remain visible and work must stay blocked. This guards against treating a failed sign-in as authorization to start work. Do not add tests that pin the hint's wording.
- Add the optional flow to `Agent` and `Agent.from` in `lib/src/client/models.dart`. `PoreloClient.agents()` in `lib/src/client/porelo_client.dart` already decodes this model. Consume Core's agreed projection of the definition's `login.flow`: `paste-code`, `device-code`, or `loopback`. This upstream field is not implemented yet; give `FakeBackend` in `test/features/support/world.dart` fake replies decoded through `Agent.from`. Do not read agent definitions in the interface or infer a flow from the agent name. Regenerate `test/features/task_creation_test.dart` and `test/features/start_agents_test.dart` after changing the scenarios.
- Replace the generic either-return-or-paste explanation in `_ShellState._logIn` in `lib/src/ui/shell.dart`. Both the single-task start and Start Agents wizard already call it. Pass the matching hint to `runInATerminal` in `lib/src/ui/unlock_terminal.dart`, which already renders the explanation above the terminal. Missing or unknown values get neutral instructions and the agent's documentation link, without promising a supported host flow.
- Keep Core's `loginCommand`, terminal input, browser links, and credential readback. Core owns refusal of a host-account loopback flow; display that refusal without translating it into success or retrying another flow. No code or token enters a Flutter form. Leave local loopback forwarding in `lib/src/app/session.dart` and `lib/src/app/login_forward.dart` intact; this issue adds no workaround for the host refusal.

## Acceptance

- Read the terminal from both entry points with fake replies for each flow. Paste-code and device-code show the required instruction above it. Missing and unknown values give no guessed flow instruction. This is a visual check, not a text snapshot test.
- A refused host loopback sign-in shows Core's reason, creates no credential, and starts no task. A successful sign-in advances only after credential readback confirms it. Cancellation leaves work blocked.
- Widget fixtures decode supplied, missing, and unknown flow metadata without changing the supplied login command. Codes remain terminal input; no additional form field, stored answer, or command argument is introduced.

## To be checked

- Confirm the wire field and unknown-value behavior of Core's projection of `login.flow`; the design names the definition field, not its reply spelling.
- Confirm how Core reports a host-account loopback refusal through its terminal and readiness reply. Check that credential readback cannot replace that reason with a generic ending message.

## Test

Only the change: the widget tests. No VM run.

## Estimate

`F275 size=S est=15 basis=median S 15 (11 records)`
