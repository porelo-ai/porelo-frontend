# F144 — Start Again Without The Now Flag

**Status:** Backlog.
**Size:** XS - one argument dropped from one call, the client's parameter and two test calls with it.

**What must be true.** *Start again* on a stopped task sends `Start` without `now`, which the daemon
declares but ignores since `porelo` [B201](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b201),
so the interface asks for nothing the contract says has no effect.

## Plan

- `PoreloBackend.startAgain` (`lib/src/app/fleet_backend.dart`) calls `start` without `now: true`.
- `PoreloClient.start` (`lib/src/client/porelo_client.dart`) loses its `now` parameter and the
  `'now'` entry it sends.
- `test/client/mock_machine_test.dart`'s two calls (*a stopped task started again*, *a running task is
  refused a second start*) call `start` without it; the mock never read it.
- No test is written: nothing changes that a daemon acts on, since `now` has always been ignored.

## Acceptance

- `dart analyze` stays at "No issues found!", and no `Start` call in `lib/` names `now`.
