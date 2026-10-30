# F279 — The Steps Of One-Click Joining

**Status:** Backlog. Estimated and Backlog (operator, 2026-10-30, sprint 6m).
**Size:** S - one Markdown file of numbered steps, put together from every repository's part; no walk engine work.

**What must be true.** One Markdown file of numbered steps covers the one-click flow from the first start to a developer's first work: key and card, server prepared and filed, admit, register, add, join, a task started, lock, let back in and give-back. Each step reads "Step X/Y" with *Where* (which machine and window), *Do*, *You see* and *If not* (what to look at, or whom to tell); no value is copied by hand. The operator goes through it with the Coordinator; there is no walk JSON and no panel.

## Why

One-click joining from signed state (operator, 2026-10-30): the steps replace walks 17–23, which [F276](README.md#f276) deletes. No guided walk this time; plain step-by-step instructions (operator, 2026-10-30, sprint 6m).

## Plan

- The file is `~/.porelo/handover/porelo-frontend/sprint-6m-steps.md` on the operator's laptop, outside the repository: it is a test script for one sprint, not a user page.
- Machines: "Laptop" is the operator's own laptop with the interface; the host is a local test VM the agents set up, never the operator; a second VM or a second local account stands for the developer.
- Each other repository posts the steps its part needs (commands, expected output) to Agent Frontend and Agent Coordinator; this issue puts them in one order with the interface's steps from [F268](README.md#f268)–[F278](README.md#f278).
- Every value a step needs (address, login, file path) is written in the step; a step that waits on something already done says so and goes on.
- Before hand-over the file is read by another model against the issues' "What must be true", and each step's *You see* is checked against the built interface on a private Xvfb display where it can be.

## Acceptance

- The operator can go from Step 1 to the last step without a value from outside the file and without a step that stalls on one already done.
- Each issue of the sprint has at least one step whose *You see* shows it working.

## To be checked

- The other repositories' steps, as they are posted.
- Which VM serves as the host and which as the developer's machine, from the Coordinator.

## Estimate

`F279 size=S est=15 basis=median S 15 (11 records)`
