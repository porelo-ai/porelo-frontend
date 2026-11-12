# F529 — Left-Behind Forward Tests Hold Under Load

```json
{
  "$schema": "issue-1.json",
  "id": "F529",
  "title": "Left-Behind Forward Tests Hold Under Load",
  "state": "Backlog",
  "size": "S",
  "priority": "Medium",
  "rank": 101,
  "blockedBy": [],
  "covers": "The tests of forwards a killed run left behind pass on a loaded machine as on an idle one: they wait for what they observe, not for fixed short times."
}
```

**Why this size.** S: the waits of one test group, each turned into a wait for its effect with a bound, and the group run
under load to see it hold.

**What must be true.** The group "a forward a run that ended without asking left behind" in `test/app/tunnel_test.dart`
passes on a machine under heavy load (load average about 25-30 on this host) as it does on an idle one, so a slow
runner never turns it red.

## Found

On this host at load average 24-30, three runs of `test/app/tunnel_test.dart` alone gave two passes and one failure,
each time another test of that group:

- "an answering socket with no record of ours is still left alone" (in a full suite run);
- "an endpoint still answered after the end is refused after a bounded wait, and nothing is killed".

Idle, the group passes every time; on CI it has not failed for this reason so far.

## Plan

- To be read first: each fixed delay in the group (the stand-in's bind wait of 100 × 20 ms, `alive`'s 300 ms, the
  bounded wait the code under test uses) and which of them a slow start of `python3` outruns.
- Waits for the observed effect (the socket bound, the process seen ended) with a generous bound, instead of fixed
  short times; the code's own bounded wait made settable for the test where the test must outlast it.
- Proven by running the group repeatedly under an artificial load (for example `stress-ng --cpu` on every core).

## Acceptance

- Twenty runs of the group under full CPU load all pass; before the change at least one fails under the same load.
