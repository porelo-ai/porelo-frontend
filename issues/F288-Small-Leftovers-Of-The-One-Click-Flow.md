# F288 — Small Leftovers Of The One-Click Flow

```json
{
  "$schema": "issue-1.json",
  "id": "F288",
  "title": "Small Leftovers Of The One-Click Flow",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 14,
  "blockedBy": [],
  "covers": "Two leftovers of the one-click flow: the terminal close test bounded per wait under load, and a repository's menu offering only the review policy it does not have."
}
```

**Why this size.** S: a test's bounds in `test/app/pty_test.dart` and one condition in
`lib/src/ui/organization_project_pages.dart`, each with its test.

**What must be true.** The terminal close test names the wait that timed out, and a repository's menu offers only the
review policy it does not have, as the project's menu does.

## Decided by the operator (2026-11-12)

- This issue shrinks to its two gathered points. The lists of what the finished one-click issues left open and of what
  was declined from the reading of the walk's fixes are dropped here; git history keeps them.

## How it stands

`test/app/pty_test.dart` uses `os._exit(0)` in the detached child's release path.

Built on 2026-11-12:
- **The close test's bound closes with the measurement.** Build 41235532851's log names two waits that ran out after
  five seconds: the close (by its stack, to the test's line 228) and the EOF wait (by its message alone); the test's
  own 30 seconds were never reached. The test then paused its reader on every read, so a line arriving in two reads
  left it paused for good; "Hold a test's reader once, as a line may come in two reads" (2026-11-05) fixed that after
  the build. Under a load of twice the cores (eight busy loops on four cores), today's test ran 300 rounds without a
  failure (slowest 37 ms), while the old one failed once in 100 with the build's message. No `onTimeout` is added.
- **A repository's menu offers only the policy it does not have**, with its test seen red for required and
  optional first.

## Plan

- **The terminal close test's bound** (`test/app/pty_test.dart`, *termination and close wait for the output consumer
  to reach EOF*). Each of its waits has its own five seconds, but `await stopping` has none, and two rounds run inside
  the test's 30 seconds. A run that times out there names no step. Red first: the test run 50 times under a load of
  twice the cores (`stress-ng --cpu`), until it fails or does not. Then each wait gets an `onTimeout` that fails with
  its own sentence, `stopping` a bound too, and the bounds are set from what the load measured. If it never fails,
  the measurement is the answer and the point closes with it.
- **A repository's menu offers the policy it has.** In `OrganizationProjectPage`
  (`lib/src/ui/organization_project_pages.dart`) the project's menu offers a review policy only `if (view.review !=
  policy)`; a repository's `CommandMenu` builds `_reviewCommand` for both. It takes the same condition on
  `repository.review`, so a repository not read still offers both. Red first: in
  `test/ui/project_init_dialog_test.dart`, beside *review changes follow the Project Admin role*, a repository with
  `review: 'required'` offers `repositoryReview/demo/optional` and not `repositoryReview/demo/required`.

## Gathered

1. **Linux CI timeout of the terminal close test:** `pty_test` "termination and close wait for the output consumer
   to reach EOF" timed out once on a Linux runner (Build 41235532851). It did not fail here in 5 single runs or in 24
   runs with 8 in parallel, and the close code had not changed. If it recurs, the test's bound is to be looked at
   against a loaded runner.
2. **A repository's menu offers the policy it has:** on a project's page a repository's menu offers both review
   policies, the one it already has too, where the project's menu offers only the other.

## Acceptance

- Each point gets a test that goes red with its harm first. Seen to fail: the close test timing out without
  naming its wait, and a repository with review required offering *Require review…*.

