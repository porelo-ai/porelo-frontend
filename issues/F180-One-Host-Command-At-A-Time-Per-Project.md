# F180 — One Host Command At A Time Per Project

**Status:** Analyzed.
**Size:** S - `packages/porelo_host/lib/src/state.dart`, `packages/porelo_host/lib/src/host_run.dart`, and `HostSession` in `lib/src/app/host_session.dart`.

**What must be true.** Only one `porelo-host up` or `porelo-host down` runs at a time for a given
project. A second invocation while the first still holds the project's lock stops before contacting
the provider or the host, emits one step `lock` / `refused` saying `"setup of <project> is still
running from before"` with fix `"wait for it, or end it"`, and exits with code `75`.

## Plan

- **Where it is today.**
  - `HostRun.up` and `HostRun.down` (`packages/porelo_host/lib/src/host_run.dart`) take no lock. If
    an earlier `porelo-host up` is still in `rent` (`provider.find(plan.tag) ?? await _create(plan)`)
    when a second `up` starts, both see `find == null` and `create` rents a second server; if the
    first is in `play`, both run `ansible-playbook` against the same host at the same time.
  - `poreloHostKnownHosts` (`packages/porelo_host/lib/src/state.dart`) already resolves the state
    directory under `$XDG_STATE_HOME/porelo-host/` (falling back to `~/.local/state/porelo-host/` on
    Linux and `%LOCALAPPDATA%\porelo-host\` on Windows).
  - In the interface, `HostSession._run` (`lib/src/app/host_session.dart`) treats every exit code
    `75` (`Exit.waiting`) as the host's person stop (`HostRunState.waiting`), which causes
    `HostDialog` to open `HostStopDialog` ([F171](README.md#f171)). The interface must therefore
    distinguish a lock refusal (exit `75` whose last step is `lock` with state `StepState.refused`)
    from a person stop (step `stop` with state `StepState.waiting`).
- **Steps.**
  1. In `packages/porelo_host/lib/src/state.dart`, add `poreloHostProjectLock(String project, ...)`
     returning `$XDG_STATE_HOME/porelo-host/<project>.lock` (with the `~/.local/state` fallback when
     `XDG_STATE_HOME` is unset or relative), validating that `project` is a single safe path segment.
  2. In `HostRun.up` and `HostRun.down` (`packages/porelo_host/lib/src/host_run.dart`), before
     `provider.find` or any `ssh` call, create the parent directory (`0700`), open `<project>.lock`
     for writing, and call `RandomAccessFile.lock(FileLock.exclusive)` (non-blocking `flock`/`fcntl`
     via `dart:io`), holding the open handle in a `try` / `finally` block for the entire run so the
     OS kernel releases it automatically even on `SIGKILL`.
  3. When `lock(FileLock.exclusive)` throws `FileSystemException`, emit
     `Step('lock', StepState.refused, words: 'setup of $project is still running from before', fix: 'wait for it, or end it')`
     through `StepOutput` and return `Exit.waiting` (`75`) without calling `provider.find`,
     `provider.create`, or `ssh`.
  4. In `HostSession._line` and `HostSession._run` (`lib/src/app/host_session.dart`), inspect whether
     the run ended on step `lock` with `StepState.refused` so an exit `75` from a lock refusal is
     not treated as `HostRunState.waiting` (the host's person stop) and never opens `HostStopDialog`.
- **Tests, their harm, red first.**
  - *Harm:* two concurrent `porelo-host up` runs for the same project rent two bare-metal servers or
    run two concurrent `ansible-playbook` processes against the same server, or a killed `up` leaves
    a stale lock that permanently blocks recovery.
  - In `packages/porelo_host/test/host_run_test.dart`:
    1. Two `porelo-host up` **processes** against a fake provider, the second started while the
       first waits inside `find`; assert that `create` is called once and the second exits `75`
       with one `lock` / `refused` step before calling `find`. Two calls inside one test process
       prove nothing: `RandomAccessFile.lock` is an `fcntl` record lock on Linux, which a process
       never conflicts with itself.
    2. Spawn a subprocess holding the lock through `porelo-host`, kill it with `ProcessSignal.sigkill`,
       and assert that the next `up` acquires `<project>.lock` and completes.
    Break the lock acquisition in `HostRun.up` first and watch both assertions fail.
  - In `test/host_dialog_test.dart`, feed `HostSession` a `lock` / `refused` step followed by exit
    `75` and assert that `session.state` is not `HostRunState.waiting` and `HostStopDialog` does not
    open.

## To be checked

- That `RandomAccessFile.lock` on Windows (`LockFileEx`) refuses a second process the same way, in the
  Windows job of the Build.

## Acceptance

- Starting a second `porelo-host up` or `porelo-host down` for the same project while the first is
  running exits with code `75` and outputs the step `lock` / `refused` (`"setup of <project> is
  still running from before"`, fix `"wait for it, or end it"`) without calling the cloud provider.
- Killing a running `porelo-host up` with `SIGKILL` releases the OS file lock so the next `up` or
  `down` for that project runs immediately.
- The interface does not mistake a `lock` / `refused` exit `75` for the host's drive- and
  vault-login stop.
