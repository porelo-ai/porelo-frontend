# F289 — A Key Recovered In One Run With Named States

**Status:** Idea.
**Size:** L - the recovery controller and its dialog are rebuilt on a fixed state machine with a new test suite;
the card copy, the checkout's commit checks, Core's calls and the terminal fixes are kept.

**What must be true.** A person replaces a lost or stolen key, or makes or uses a backup key, in one run that is
always in one named state the dialog shows. Only one run exists at a time, it alone holds the registry checkout while
it writes, nothing runs on its own in the background, and every way out of a state is a button the person presses.
What [F280](README.md#f280) asks of recovery - who may replace whose key, the backup key's limits, locks shown only
once confirmed - stays as it is.

## Why

The chain [F281](README.md#f281), [F283](README.md#f283), [F285](README.md#f285) and [F286](README.md#f286) kept a
request across dialogs and restarts, resumed it on its own and let several dialogs share its running state. Each
reading found new ways for that to stick, run twice or file the wrong thing. A run with one owner, one at a time and
few states removes those ways instead of guarding each.

## The shape

- **One owner of the registry hold.** `RegistryCheckouts` alone takes and lets go of the hold on a checkout, one hold
  for each `Registry` (one `Registry` per address, as now). A recovery run, the identity page's writes and the
  registry's own reads and filings each ask it; a holder lets go in one `finally` of its own, and a dialog that goes
  away ends its run, which lets go. A refresh waits for the release, a second writer is refused with words.
- **One run at a time.** `RecoveryRun` is the only object that runs Core for a recovery, app-wide. While one exists,
  every other recovery action and *Make a backup key…* is disabled with "A key recovery is already running." Two
  dialogs never share a run; the second shows the first's state, read only.
- **No background retry.** Nothing resumes when a dialog opens or the app starts. A run that was left in *Made* or
  *Uncertain* is shown as that, and the person chooses.
- **Few fixed states, each named in the dialog:**

  | State | Shown as | Holds the checkout | Kept across a restart |
  |---|---|---|---|
  | `idle` | nothing | no | no |
  | `reviewing` | *Review the replacement* | only while it reads | no |
  | `running` | *Core is running* | yes | no |
  | `made` | *Committed, not pushed* | no | yes: change id, commit, base, file |
  | `pushed` | *Done* with each host's line | no | no |
  | `uncertain` | *Not known whether Core committed* | no | yes: change id, base, file |
  | `refused` | Core's own words | no | no |

- **Transitions, each by one event:**
  - `idle` → `reviewing`: the person picks a person and a scope. The list, the base and the card's exact text are read
    fresh under a short hold; nothing is taken from an earlier read or a commit made here.
  - `reviewing` → `running`: *Confirm* or *Use the backup key…*. The reviewed card is copied privately; the hold is
    taken and kept to the end of the run.
  - `reviewing` → `idle`: *Cancel*, or the dialog goes away.
  - `running` → `made`: Core answered a commit that passes every check (its single change id is the run's, it changes
    only the expected file, its parent is the reviewed base) and the push failed.
  - `running` → `pushed`: the same, and the push succeeded; the hosts are told once.
  - `running` → `refused`: Core refused with its codes 64, 65 or 66, or the check before Core refused; nothing is kept.
  - `running` → `uncertain`: anything else once Core started - an exit-0 answer that fails a check, a crash, a killed or
    put-away terminal, a terminal whose end was not seen.
  - `made` → `pushed`: *Push again*, after a fetch: pushed, or found already on the published branch's first-parent
    line.
  - `made` → `idle`: *Forget*, after a confirmation naming the commit and that it stays in the checkout.
  - `uncertain` → `made` or `pushed`: *Check again* finds the run's change id in the checkout or on the published
    branch.
  - `uncertain` → `idle`: *Check again* finds no commit with the change id, or *Forget* after a confirmation saying what
    may already be committed.
  - `pushed` and `refused` → `idle`: *Close*.

  Every other event in a state is refused with words; the controller has no path outside this table.
- **A project's backup key** is made and used on the project repository's own head, read fresh in `reviewing`; a
  project replacement never takes the registry hold, as it never writes the checkout.

## Where the earlier findings end up

- **[F281](README.md#f281)** - a commit made but not pushed is finished, never made twice: `made` with *Push again*, and
  `uncertain` with *Check again*, both by change id. The next action starts from the new revision: `reviewing` always
  reads fresh.
- **[F283](README.md#f283)**
  - 1, an exit-0 answer failing a check: `running` → `uncertain`.
  - 2.1, a project receipt never forgotten: `pushed` keeps nothing; pending hosts are lines, not a kept state.
  - 2.2, a made commit whose push fails for good: `made` → *Forget*.
  - 2.3, an agent-key commit whose answer was lost: `uncertain` → *Check again* by change id, with no clean read
    needed.
  - 3, Forget or a second attempt while Core runs: one run; *Forget* exists only in `made` and `uncertain`, where
    nothing runs.
  - 4, a new change without a current read: no path leads from a kept run to Confirm; only `reviewing` reaches
    `running`.
  - 5, a stale base: the base is the fresh read's own; no "newest made here" is kept.
  - 6 and 7, tests that stay green: replaced by one test per transition and per refused event, each seen red.
- **[F285](README.md#f285)**
  - 1, running for good: the run ends when its dialog goes away.
  - 2, already pushed: *Push again* and *Check again* find it on the published branch.
  - 3, filed as reviewed: the private card copy, kept as built; the one hold owner keeps refreshes out.
  - 4, the project backup key's base: the project repository's own head, read fresh.
  - 5 and 6, Windows close and other terminals: these fixes are kept, as every terminal needs them, not only
    recovery's.
  - 7, its tests: replaced as for F283.
- **[F286](README.md#f286)**
  - 1, the registry hold: one owner, released in `finally`; identity writes ask the same owner.
  - 2, the made commit as its own: the change id, file and parent checks, kept as built and used by every transition
    into `made` and `pushed`.
  - 3, the card copy: kept as built.
  - 4, project backup-key records: gone; nothing made here is kept as a base.
  - 5 and 6, Windows close and terminals: kept.
  - 7, its tests: replaced as for F283.
  - Its open points: the backup-key commit's change id line is confirmed on a real Core before building; a two-commit
    `registry file` answer is checked by *Check again* as one; the start sweep of card copies is kept.

## What becomes of F280's built code

Rebuilt, not built on. `main` holds the recovery code, not yet wired into the running app; the wiring
(`6m-f280-wiring`) stays off `main` and is dropped.
- **Kept and reused:**
  - `PrivateCards`;
  - the checkout's commit checks in `RegistryCheckout` and `publishMade`'s change-id test;
  - `CliKeyRecoveryCore`'s calls and answer reading;
  - the `HostLock` lines and `RegistryRevocationHosts`;
  - the terminal and `ConPty` close fixes.
- **Replaced by `RecoveryRun` and a new dialog:**
  - `KeyRecovery`, `RecoveryRuns`, `BackupKeyMaking`;
  - the receipts' resume logic and the made-here records;
  - `KeyRecoveryDialog`.
- The wiring is written again on the new run, in the same commit as it.

## Acceptance

- Each transition of the table has a test that drives it through the dialog and sees the next state named; each
  event not in the table is refused in each state. Each was seen red with the transition broken on purpose.
- With a fake Core that crashes, answers exit 0 with a wrong commit, or is put away, the run is `uncertain` and
  nothing files again until *Check again* or *Forget*.
- A dialog closed in every state leaves no hold, no running mark and no card copy.
- A second recovery or *Make a backup key…* while one runs is disabled with its reason.
- After a restart, only a `made` or `uncertain` run is shown, and nothing runs until the person presses a button.

## To be checked

- That Core's backup-key commit carries `Porelo-Change-Id: <the request's id>` as `registry file` does, on a real
  Core run, before *Check again* relies on it.
- Which of the tests in `test/app/key_recovery_test.dart` survive as tests of the kept parts.

## Estimate

`F289 size=L est=150 basis=guess: no L median measured; M median 61 (24 records), more than twice that`
