# F178 — An Interrupted Run's Protocol Kept Across A Restart

**Status:** Review.
**Size:** S - `HostUpRecord` in `lib/src/app/settings.dart`, `HostRuns` and `HostSession` in `lib/src/app/`, and `HostDialog` in `lib/src/ui/host_dialog.dart`.

**What must be true.** When a server preparation is interrupted, its protocol is kept with the run's
answers and shown after a restart — the steps so far, then `"Interrupted at <time>"` — until the
server is given back, when the kept protocol is removed. One button is named the same everywhere:
*Go on* for an interrupted run and *Try again* for a failed one, never both. While interrupted, the
setup dialog states `"Nothing runs now. Go on continues from where it stopped."`

## Plan

- **Where it is today.**
  - `HostUpRecord` (`lib/src/app/settings.dart`) persists the wizard's answers, `preparing`, and
    `startedAt` in `settings.json`, but stores none of `HostSession`'s protocol steps or lines.
  - On startup, `HostRuns` (`lib/src/app/host_runs.dart`) restores each record with `preparing: true`
    as a `HostPreparation(..., interrupted: true)` backed by a fresh `HostSession`
    (`lib/src/app/host_session.dart`), whose `history` and `protocol` are empty. Opening *Protocol*
    after a restart shows an empty dialog with no record of what ran before the interruption.
  - `HostRuns.confirmDown` (`lib/src/app/host_runs.dart`) clears `preparing` via
    `kept.withPreparation(null)` when `hostGivenBack(session)` is true, while leaving the rest of the
    `HostUpRecord` in `Settings`.
  - In `MachinesPage` (`lib/src/ui/machines_page.dart`), `hostRecoveryCommands`
    (`lib/src/app/commands.dart`) offers `host.goOn` (*Go on*) and `host.takeDown` (*Take it down*).
    In `HostDialog._runDialog` (`lib/src/ui/host_dialog.dart`), however, any non-running,
    non-waiting unfinished run shows `retryHostPreparationCommand` (`lib/src/app/commands.dart`),
    which is labeled `'Try setup again'` (key `'host-retry'`) even when `run.interrupted` is true.
- **Steps.**
  1. Extend `HostUpRecord` (`lib/src/app/settings.dart`) with the serialized protocol entries of the
     in-flight or interrupted preparation (each step's name, state, words, fix, start time, and
     duration, plus when the interruption was recorded).
  2. In `HostRuns` (`lib/src/app/host_runs.dart`) and `HostSession`
     (`lib/src/app/host_session.dart`), save the protocol into the project's `HostUpRecord` as steps
     arrive and when a run is interrupted; on startup, restore those steps into `HostSession` and
     append the `"Interrupted at <HH:MM>"` marker so opening the protocol after a restart shows what
     ran before.
  3. In `HostRuns.confirmDown` (`lib/src/app/host_runs.dart`), clear the stored protocol from
     `HostUpRecord` once `hostGivenBack(session)` succeeds so a given-back server leaves no stale
     protocol behind.
  4. Unify the action command in `lib/src/app/commands.dart`, `lib/src/ui/machines_page.dart`, and
     `HostDialog._runDialog` (`lib/src/ui/host_dialog.dart`): when `run.interrupted` is true, offer
     only *Go on* (`host.goOn`); when the run failed or was refused (`!run.interrupted`), offer only
     *Try again* (`host.retry`); never show both at the same time.
  5. In `HostDialog._progress` (`lib/src/ui/host_dialog.dart`), when the preparation is interrupted,
     show `"Nothing runs now. Go on continues from where it stopped."` above the action bar.
- **Tests, their harm, red first.**
  - *Harm:* losing the setup protocol across a restart hides whether `rent` already created a billed
    server before the interruption, or keeping it past give-back shows steps from a destroyed server
    on the next run.
  - In `test/host_dialog_test.dart`, start a preparation that completes `check` and `rent`, simulate
    a restart by constructing a new `HostRuns` from the persisted `Settings`, and assert that the
    restored `HostSession` holds the `check` and `rent` protocol steps and the `"Interrupted at ..."`
    entry, and that `confirmDown` after a completed `down` removes the stored protocol from
    `Settings`. Break the `Settings` serialization of the protocol steps first and watch the test
    fail.
  - Words, colors, and layout get no test.

## Acceptance

- Interrupting a setup after `rent` and restarting the interface shows the steps completed before the
  interruption followed by `"Interrupted at <time>"` when *Protocol* is opened.
- While the run is interrupted, the dialog shows `"Nothing runs now. Go on continues from where it
  stopped."` and the button is named *Go on* both in the *Machines* row and in the dialog.
- When a run fails rather than being interrupted, the button is named *Try again* in both places, and
  *Go on* is not shown.
- Giving the server back removes the kept protocol so a later setup starts clean.
