# F179 — An Interrupted Setup In Needs You And A Running One Found Again

**Status:** Implementing.
**Size:** M - `Attention` in `lib/src/app/attention.dart`, `HostRuns` and `HostSession` in `lib/src/app/`, and `confirmQuit` in `lib/src/ui/leaving.dart`.

**What must be true.** When a server setup was interrupted, *Needs you* shows `"Setup of <server>
was interrupted — the server is rented and billed"` with *Go on* in the row. Closing the interface
with *Leave* while `porelo-host up` has no `ssh` child ends `up` cleanly so it does not outlive the
interface; once `up` has an `ssh` child, *Leave* stays allowed and the close dialog states `"Setup
runs on without the interface; it shows again when you start it"`. When the interface starts while
that `up` is still running, it finds the running `up` and shows the server as in preparation and
running, never as interrupted.

## Plan

- **Where it is today.**
  - `Attention._rows` (`lib/src/app/attention.dart`) only emits an `AttentionKind.host` row when
    `run.waiting` is true (`HostStop(run)`). An interrupted preparation (`run.interrupted`) appears
    only under *Machines* ([F169](README.md#f169)), never in *Needs you*.
  - `HostSession._run` (`lib/src/app/host_session.dart`) starts `porelo-host up` with `Process.start`
    and keeps no reference to the `Process`; `dispose()` never terminates it.
  - `Shell._letGo` (`lib/src/ui/shell.dart`) calls `confirmQuit` (`lib/src/ui/leaving.dart`), which
    warns `'<project> server is being prepared; the server stays rented and billed. Go on later from
    Machines.'`, closes the window, and leaves `porelo-host up` running unattended regardless of
    which step it is in.
  - On startup, `HostRuns` (`lib/src/app/host_runs.dart`) marks every persisted record with
    `preparing: true` as `interrupted: true` without checking whether `porelo-host up` from before
    still holds the project's lock ([F180](README.md#f180)).
- **Steps.**
  1. In `Attention._rows` (`lib/src/app/attention.dart`) and `AttentionView`
     (`lib/src/ui/attention_view.dart`), add an interrupted-host attention item for every
     `HostPreparation` where `run.interrupted` is true, showing `"Setup of <server> was interrupted —
     the server is rented and billed"` and offering *Go on* (`host.goOn`, calling
     `_hostRuns.resume(run)`) directly in the row; once resumed or given back, the row resolves as
     in [F158](README.md#f158).
  2. In `HostSession` (`lib/src/app/host_session.dart`), keep the active `Process` while `_run` is
     executing. Whether `up` may still be ended is read from its own steps, the same on Linux and
     Windows: until its `rent` step is done, `up` has no `ssh` child and changes nothing on the
     host. Expose a method that ends `up` with `ProcessSignal.sigterm` only in that phase and waits
     for its exit.
  3. In `confirmQuit` (`lib/src/ui/leaving.dart`) and `Shell._letGo` (`lib/src/ui/shell.dart`),
     distinguish the two cases when `_hostRuns.preparing` has a running `HostSession`:
     - While `up` has no `ssh` child (still renting), *Leave* sends `SIGTERM` to `up` and waits
       briefly for it to exit so no orphan `up` rents or plays in the background.
     - While `up` has an `ssh` child, *Leave* stays allowed without killing `up`, and `confirmQuit`
       states `"Setup runs on without the interface; it shows again when you start it"`.
  4. In `HostRuns` (`lib/src/app/host_runs.dart`), when restoring a `preparing` record at startup,
     ask whether the project's lock ([F180](README.md#f180)) is held, never by starting `up`, which
     would go on by itself when the lock is free: the interface imports `porelo_host`, takes the
     lock file's path from it, tries the exclusive lock without waiting and releases it at once.
     Held: the preparation shows as running from before, polled until the lock is free, and the
     interface never opens `HostStopDialog` for it. Free: it is interrupted, as today. A *Go on*
     that still meets the lock (exit `75`, step `lock` refused) is shown the same way, as running
     from before.
- **Tests, their harm, red first.**
  - *Harm 1:* an interrupted setup is forgotten while a bare-metal server stays rented and billed by
    the hour because nothing in *Needs you* points to it.
    - In `test/attention_test.dart`, restore a `HostRuns` with an interrupted `HostPreparation` and
      assert that `Attention.openRows` includes the host row with the *Go on* action, and that
      triggering *Go on* starts `resume`. Break the `run.interrupted` branch in `Attention._rows`
      first and watch the test fail.
  - *Harm 2:* closing the interface during `rent` leaves an orphan `porelo-host up` running in the
    background, or restarting while `up` is in `play` falsely tells the user that setup is
    interrupted while `ansible-playbook` is still modifying the server.
    - In `test/host_dialog_test.dart`, verify that leaving while `up` has no `ssh` child terminates
      the `up` process and that leaving after its `rent` step does not, and that starting `HostRuns`
      while another process holds the project's lock shows the run as running from before, not
      interrupted, and starts no `up`. Break each check
      first and watch the test fail.
  - Words, colors, and layout get no test.

## Acceptance

- An interrupted server preparation appears in *Needs you* as `"Setup of <server> was interrupted —
  the server is rented and billed"` with a *Go on* button that resumes the setup.
- Closing the interface with *Leave* while `porelo-host up` is still in `rent` (no `ssh` child) ends
  the `porelo-host up` process.
- Closing the interface while `porelo-host up` has an `ssh` child shows `"Setup runs on without the
  interface; it shows again when you start it"`, leaves `up` running, and restarting the interface
  while `up` still holds the project lock shows the server as running, not as interrupted.
