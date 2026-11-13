# F505 — The Issue Heads Are Checked Every Day

```json
{
  "$schema": "issue-1.json",
  "id": "F505",
  "title": "The Issue Heads Are Checked Every Day",
  "state": "Review",
  "size": "XS",
  "priority": "Low",
  "rank": 82,
  "blockedBy": [],
  "covers": "The repository's daily shared-rules run checks its issues' heads with `issues check issues` from the released porelo-release, as the build tools' own shared rules do."
}
```

**Why this size.** one step in `.github/workflows/shared-rules.yml`, the same the build tools' shared rules carry; XS.

**What must be true.** The daily run of `.github/workflows/shared-rules.yml` (cron `17 3 * * *`) checks `issues/`
with `issues check issues`, taken from the released porelo-release, and fails when a head is wrong. Today the heads
are checked only where a person or an agent runs the check by hand before a commit, so a head broken on main stays
unseen until the next one does.

The build tools' own shared rules gained this daily step; every repository with `issues/` takes the same step into its
own workflow.

## Plan

- Add the step to the scheduled job of `.github/workflows/shared-rules.yml`, fetching porelo-release's released jar as
  the build tools' step does, and running `issues check issues`.
- Run the workflow once by dispatch and read that the step ran and passed.

## Acceptance

- The daily shared-rules run checks the issue heads and fails on a wrong one.

## How it was built

- The step *The issue heads* was already in the scheduled job of `.github/workflows/shared-rules.yml`: it runs
  `issues check issues` from the porelo-release the build's parent pins, on the checked-out commit. No workflow change
  was needed.
- The step ran and passed in the latest scheduled run on main, whose commit includes it; it was read step by step from
  the run's jobs.
- It fails on a wrong head: on a copy of `issues/` with one head's size set to a value the schema does not list,
  `issues check issues` named the file and the field and exited 1.
