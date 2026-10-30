# F275 — The Sign-In Says Its Flow

**Status:** Accepted.
**Size:** XS - the agent's sign-in terminal shows a hint from the agent definition's `login.flow`.

**What must be true.** When an agent's sign-in runs in the person's host account, the terminal shows above it "Paste the code shown in your browser" for `paste-code`, or "Confirm on the device page" for `device-code`. A `loopback` flow refused by Core on a host account is shown in Core's words.

## Why

One-click joining from signed state (operator, 2026-10-30) and the operator's answer to Agent Smith (2026-10-30): `login.flow` per definition, so the interface can say what to do.

## Plan

- **Red first:** a widget test per flow value.

## Test

Only the change: the widget tests. No VM run.

## Estimate

`F275 size=XS est=10 basis=median XS 10 (8 records)`
